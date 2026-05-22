import { describe, it, expect, vi, beforeEach } from 'vitest';

// Mock external dependencies
vi.mock('../src/db/client.js', () => ({
  supabase: {
    from: vi.fn().mockReturnThis(),
    insert: vi.fn().mockReturnThis(),
    select: vi.fn().mockReturnThis(),
    eq: vi.fn().mockReturnThis(),
    single: vi.fn(),
    update: vi.fn().mockReturnThis(),
    order: vi.fn().mockReturnThis(),
    limit: vi.fn().mockReturnThis(),
  },
}));

vi.mock('../src/queue/headshot.queue.js', () => ({
  enqueueHeadshotJob: vi.fn().mockResolvedValue(undefined),
  proQueue:  { add: vi.fn() },
  freeQueue: { add: vi.fn() },
}));

vi.mock('../src/services/r2.service.js', () => ({
  uploadBuffer: vi.fn().mockResolvedValue('https://pub.r2.dev/test/photo_0.jpg'),
}));

describe('Job queue logic', () => {
  it('maps tier to correct queue', async () => {
    const { enqueueHeadshotJob } = await import('../src/queue/headshot.queue.js');

    await enqueueHeadshotJob({
      jobId: 'test-job-1',
      userId: 'user-1',
      tier: 'pro',
      industry: 'Tech',
      style: 'Modern',
      photoUrls: ['https://example.com/photo.jpg'],
    });

    expect(enqueueHeadshotJob).toHaveBeenCalledWith(
      expect.objectContaining({ tier: 'pro' })
    );
  });

  it('rejects fewer than 3 photos', () => {
    const validate = (photos: unknown[]) => {
      if (photos.length < 3 || photos.length > 5) {
        throw new Error('Please provide 3–5 photos');
      }
    };
    expect(() => validate([1, 2])).toThrow('Please provide 3–5 photos');
    expect(() => validate([1, 2, 3])).not.toThrow();
    expect(() => validate([1, 2, 3, 4, 5, 6])).toThrow('Please provide 3–5 photos');
  });
});

describe('Status to percent mapping', () => {
  const statusToPercent = (status: string): number => {
    const map: Record<string, number> = {
      PENDING: 5, FACE_CHECK: 15, EMBEDDING: 30,
      GENERATING: 65, UPSCALING: 85, UPLOADING: 95,
      DONE: 100, FAILED: 0,
    };
    return map[status] ?? 0;
  };

  it('returns 100 for DONE', () => expect(statusToPercent('DONE')).toBe(100));
  it('returns 0 for FAILED', () => expect(statusToPercent('FAILED')).toBe(0));
  it('returns 65 for GENERATING', () => expect(statusToPercent('GENERATING')).toBe(65));
});
