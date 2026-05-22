export interface HeadshotJobData {
  jobId:    string;
  userId:   string;
  tier:     'free' | 'pro';
  industry: string;
  style:    string;
  photoUrls: string[];  // temp upload URLs of the source photos
}

export interface HeadshotJobResult {
  resultUrls: string[];
  embeddingId?: string;
}

export const ErrorCode = {
  NO_FACE_DETECTED:  'NO_FACE_DETECTED',
  LOW_QUALITY_PHOTOS:'LOW_QUALITY_PHOTOS',
  FAL_API_ERROR:     'FAL_API_ERROR',
  TIMEOUT:           'TIMEOUT',
  UPLOAD_FAILED:     'UPLOAD_FAILED',
  UNKNOWN:           'UNKNOWN',
} as const;

export type ErrorCode = typeof ErrorCode[keyof typeof ErrorCode];

export const PRO_QUEUE  = 'headshot:pro';
export const FREE_QUEUE = 'headshot:free';

export const GENERATION_STEPS = [
  'FACE_CHECK',
  'EMBEDDING',
  'GENERATING',
  'UPSCALING',
  'UPLOADING',
] as const;

export type GenerationStep = typeof GENERATION_STEPS[number];

export function stepToPercent(step: GenerationStep): number {
  const map: Record<GenerationStep, number> = {
    FACE_CHECK:  10,
    EMBEDDING:   25,
    GENERATING:  60,
    UPSCALING:   80,
    UPLOADING:   95,
  };
  return map[step];
}
