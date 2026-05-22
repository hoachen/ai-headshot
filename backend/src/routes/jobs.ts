import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';
import { verifyAuth } from '../middleware/auth.js';
import { jobSubmitRateLimit } from '../middleware/rateLimit.js';
import { createJob, getJobForUser, listUserJobs, deleteJobPhotos } from '../db/jobs.repo.js';
import { enqueueHeadshotJob } from '../queue/headshot.queue.js';
import { uploadBuffer, getPresignedUploadUrl } from '../services/r2.service.js';
import multipart from '@fastify/multipart';

const submitSchema = z.object({
  industry: z.enum(['Tech', 'Finance', 'Legal', 'Medical', 'Creative', 'Sales']),
  style:    z.enum(['Conservative', 'Modern', 'Friendly']),
});

export async function jobRoutes(app: FastifyInstance): Promise<void> {
  // POST /jobs — submit a new generation job
  app.post('/jobs', {
    preHandler: [verifyAuth],
    ...jobSubmitRateLimit,
  }, async (request: FastifyRequest, reply: FastifyReply) => {
    const user = request.user;
    const photoBuffers: Buffer[] = [];
    const fields: Record<string, string> = {};

    // Parse multipart form
    const parts = request.parts();
    for await (const part of parts) {
      if (part.type === 'file' && part.fieldname === 'photos') {
        const chunks: Buffer[] = [];
        for await (const chunk of part.file) {
          chunks.push(chunk);
        }
        const buffer = Buffer.concat(chunks);
        if (buffer.length > 10 * 1024 * 1024) {
          return reply.status(413).send({ error: 'Each photo must be under 10MB' });
        }
        photoBuffers.push(buffer);
      } else if (part.type === 'field') {
        fields[part.fieldname] = part.value as string;
      }
    }

    if (photoBuffers.length < 3 || photoBuffers.length > 5) {
      return reply.status(400).send({ error: 'Please provide 3–5 photos' });
    }

    const parsed = submitSchema.safeParse(fields);
    if (!parsed.success) {
      return reply.status(400).send({ error: parsed.error.flatten() });
    }

    const tier = user.tier;

    // Create job record
    const job = await createJob({
      userId:   user.sub,
      tier,
      industry: parsed.data.industry,
      style:    parsed.data.style,
    });

    // Upload source photos to R2 as temp files
    const photoUrls: string[] = [];
    for (let i = 0; i < photoBuffers.length; i++) {
      const key = `temp/${job.id}/photo_${i}.jpg`;
      const url = await uploadBuffer(photoBuffers[i], key, 'image/jpeg');
      photoUrls.push(url);
    }

    // Enqueue to BullMQ
    await enqueueHeadshotJob({
      jobId:     job.id,
      userId:    user.sub,
      tier,
      industry:  parsed.data.industry,
      style:     parsed.data.style,
      photoUrls,
    });

    return reply.status(202).send({ jobId: job.id });
  });

  // GET /jobs/:id/stream — SSE progress stream
  app.get('/jobs/:id/stream', {
    preHandler: [verifyAuth],
  }, async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
    const { id } = request.params;
    const user = request.user;

    const job = await getJobForUser(id, user.sub);
    if (!job) return reply.status(404).send({ error: 'Job not found' });

    reply.raw.writeHead(200, {
      'Content-Type':  'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection':    'keep-alive',
      'X-Accel-Buffering': 'no',
    });

    const sendEvent = (data: object) => {
      reply.raw.write(`data: ${JSON.stringify(data)}\n\n`);
    };

    const poll = setInterval(async () => {
      try {
        const current = await getJobForUser(id, user.sub);
        if (!current) { clearInterval(poll); reply.raw.end(); return; }

        const pct = statusToPercent(current.status);
        sendEvent({
          state: current.status,
          pct,
          urls:       current.status === 'DONE' ? current.result_urls : undefined,
          error:      current.error_code ?? undefined,
          error_code: current.error_code ?? undefined,
        });

        if (current.status === 'DONE' || current.status === 'FAILED') {
          clearInterval(poll);
          setTimeout(() => reply.raw.end(), 500);
        }
      } catch (err) {
        console.error('SSE poll error:', err);
        clearInterval(poll);
        reply.raw.end();
      }
    }, 1500);

    // Cleanup on client disconnect
    request.raw.on('close', () => clearInterval(poll));
  });

  // GET /jobs/:id — poll job status
  app.get('/jobs/:id', {
    preHandler: [verifyAuth],
  }, async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
    const job = await getJobForUser(request.params.id, request.user.sub);
    if (!job) return reply.status(404).send({ error: 'Job not found' });
    return reply.send(job);
  });

  // GET /jobs — list recent jobs
  app.get('/jobs', {
    preHandler: [verifyAuth],
  }, async (request: FastifyRequest, reply: FastifyReply) => {
    const jobs = await listUserJobs(request.user.sub);
    return reply.send({ jobs });
  });

  // DELETE /jobs/:id/photos — early deletion
  app.delete('/jobs/:id/photos', {
    preHandler: [verifyAuth],
  }, async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
    const deleted = await deleteJobPhotos(request.params.id, request.user.sub);
    if (!deleted) return reply.status(404).send({ error: 'Job not found' });
    return reply.status(204).send();
  });
}

function statusToPercent(status: string): number {
  const map: Record<string, number> = {
    PENDING:    5,
    FACE_CHECK: 15,
    EMBEDDING:  30,
    GENERATING: 65,
    UPSCALING:  85,
    UPLOADING:  95,
    DONE:       100,
    FAILED:     0,
  };
  return map[status] ?? 0;
}
