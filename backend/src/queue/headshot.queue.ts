import { Queue } from 'bullmq';
import IORedis from 'ioredis';
import { env } from '../config/env.js';
import { PRO_QUEUE, FREE_QUEUE, type HeadshotJobData } from './job.types.js';

const connection = new IORedis(env.REDIS_URL, {
  maxRetriesPerRequest: null,
  enableReadyCheck: false,
});

const defaultJobOptions = {
  attempts: 3,
  backoff: { type: 'exponential' as const, delay: 5000 },
  removeOnComplete: { age: 3600 },
  removeOnFail: { age: 86400 },
};

export const proQueue = new Queue<HeadshotJobData>(PRO_QUEUE, {
  connection,
  defaultJobOptions,
});

export const freeQueue = new Queue<HeadshotJobData>(FREE_QUEUE, {
  connection,
  defaultJobOptions: { ...defaultJobOptions, attempts: 2 },
});

export async function enqueueHeadshotJob(data: HeadshotJobData): Promise<void> {
  const queue = data.tier === 'pro' ? proQueue : freeQueue;
  await queue.add('generate', data, { jobId: data.jobId });
}

export { connection as redisConnection };
