import { Worker, Job } from 'bullmq';
import { redisConnection, PRO_QUEUE, FREE_QUEUE } from './headshot.queue.js';
import { HeadshotJobData, HeadshotJobResult, ErrorCode, stepToPercent } from './job.types.js';
import { updateJobStatus } from '../db/jobs.repo.js';
import {
  extractFaceEmbedding,
  generateHeadshots,
  upscaleImage,
  generateFreePreview,
} from '../services/fal.service.js';
import { uploadFromUrl, keyFromPublicUrl } from '../services/r2.service.js';
import { sendGenerationComplete } from '../services/apns.service.js';

const WORKER_OPTIONS = {
  connection: redisConnection,
  limiter: { max: 5, duration: 1000 },
};

async function processJob(job: Job<HeadshotJobData>): Promise<HeadshotJobResult> {
  const { jobId, userId, tier, industry, style, photoUrls } = job.data;

  const setStatus = async (
    status: string,
    extra?: Record<string, unknown>
  ) => {
    await updateJobStatus(jobId, status as any, extra as any);
    await job.updateProgress(stepToPercent(status as any));
  };

  // Step 1: Face quality check via InsightFace
  await setStatus('FACE_CHECK');
  const primaryPhotoUrl = photoUrls[0];
  if (!primaryPhotoUrl) {
    await updateJobStatus(jobId, 'FAILED', { error_code: ErrorCode.NO_FACE_DETECTED });
    throw new Error(ErrorCode.NO_FACE_DETECTED);
  }

  let embedding: number[];
  try {
    const result = await extractFaceEmbedding(primaryPhotoUrl);
    embedding = result.embedding;
  } catch (err) {
    await updateJobStatus(jobId, 'FAILED', { error_code: ErrorCode.NO_FACE_DETECTED });
    throw err;
  }

  // Step 2: Generate images
  await setStatus('EMBEDDING');

  let rawImageUrls: string[];
  if (tier === 'pro') {
    // Step 3: Full generation — 20 images with FLUX + InstantID
    await setStatus('GENERATING');
    const genResult = await generateHeadshots({
      faceImageUrl: primaryPhotoUrl,
      industry,
      style,
      count: 20,
    });
    rawImageUrls = genResult.imageUrls;

    // Step 4: Upscale to 4K (pro only)
    await setStatus('UPSCALING');
    const upscaled = await Promise.allSettled(
      rawImageUrls.map(url => upscaleImage(url))
    );
    rawImageUrls = upscaled.map((r, i) =>
      r.status === 'fulfilled' ? r.value : rawImageUrls[i]
    );
  } else {
    // Free tier: 1 watermarked preview at lower quality
    await setStatus('GENERATING');
    const previewUrl = await generateFreePreview({ faceImageUrl: primaryPhotoUrl, industry, style });
    rawImageUrls = [previewUrl];
  }

  // Step 5: Upload to Cloudflare R2
  await setStatus('UPLOADING');
  const uploadResults = await Promise.allSettled(
    rawImageUrls.map((url, index) => {
      const key = `jobs/${jobId}/${index.toString().padStart(2, '0')}.jpg`;
      return uploadFromUrl(url, key);
    })
  );

  const resultUrls = uploadResults
    .filter((r): r is PromiseFulfilledResult<string> => r.status === 'fulfilled')
    .map(r => r.value);

  if (resultUrls.length === 0) {
    await updateJobStatus(jobId, 'FAILED', { error_code: ErrorCode.UPLOAD_FAILED });
    throw new Error(ErrorCode.UPLOAD_FAILED);
  }

  // Step 6: Mark done, send push
  const deletionTime = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
  await updateJobStatus(jobId, 'DONE', {
    result_urls:       resultUrls,
    completed_at:      new Date().toISOString(),
    photos_deleted_at: deletionTime,
  });

  await sendGenerationComplete(userId, jobId);

  return { resultUrls };
}

// Pro queue worker — higher concurrency, priority processing
const proWorker = new Worker<HeadshotJobData, HeadshotJobResult>(
  PRO_QUEUE,
  processJob,
  { ...WORKER_OPTIONS, concurrency: 5 }
);

// Free queue worker — lower concurrency
const freeWorker = new Worker<HeadshotJobData, HeadshotJobResult>(
  FREE_QUEUE,
  processJob,
  { ...WORKER_OPTIONS, concurrency: 2 }
);

function attachListeners(worker: Worker, queueName: string) {
  worker.on('completed', (job) => {
    console.log(`[${queueName}] Job ${job.id} completed`);
  });

  worker.on('failed', (job, err) => {
    console.error(`[${queueName}] Job ${job?.id} failed:`, err.message);
  });

  worker.on('error', (err) => {
    console.error(`[${queueName}] Worker error:`, err);
  });
}

attachListeners(proWorker, PRO_QUEUE);
attachListeners(freeWorker, FREE_QUEUE);

console.log('🚀 Headshot worker started — listening on pro and free queues');

// Graceful shutdown
process.on('SIGTERM', async () => {
  await Promise.all([proWorker.close(), freeWorker.close()]);
  process.exit(0);
});
