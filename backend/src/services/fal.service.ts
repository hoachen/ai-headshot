import * as fal from '@fal-ai/client';
import { env } from '../config/env.js';

fal.config({ credentials: env.FAL_KEY });

export interface FaceEmbeddingResult {
  embedding: number[];
  landmarks: Record<string, unknown>;
}

export interface GenerationResult {
  imageUrls: string[];
}

const STYLE_PROMPTS: Record<string, string> = {
  Conservative: 'formal professional headshot, conservative business attire, neutral background, traditional corporate style',
  Modern:       'modern professional headshot, contemporary business look, clean minimal background, polished appearance',
  Friendly:     'approachable professional headshot, warm smile, inviting background, personable and welcoming',
};

const INDUSTRY_PROMPTS: Record<string, string> = {
  Tech:     'modern tech company environment, clean minimalist aesthetic',
  Finance:  'financial district setting, authoritative corporate appearance',
  Legal:    'law firm environment, formal and trustworthy',
  Medical:  'healthcare professional, clinical clean background',
  Creative: 'creative studio environment, artistic and stylish',
  Sales:    'warm business setting, friendly professional environment',
};

export async function extractFaceEmbedding(imageUrl: string): Promise<FaceEmbeddingResult> {
  const result = await fal.run('fal-ai/insightface', {
    input: {
      image_url: imageUrl,
      model: 'buffalo_l',
    },
  });

  const output = result as any;
  if (!output?.embedding || !Array.isArray(output.embedding)) {
    throw new Error('No face embedding returned from InsightFace');
  }

  return {
    embedding: output.embedding,
    landmarks: output.landmarks ?? {},
  };
}

export async function generateHeadshots(params: {
  faceImageUrl: string;
  industry: string;
  style: string;
  count: number;
}): Promise<GenerationResult> {
  const stylePrompt = STYLE_PROMPTS[params.style] ?? STYLE_PROMPTS.Modern;
  const industryPrompt = INDUSTRY_PROMPTS[params.industry] ?? '';
  const prompt = `professional headshot portrait, ${stylePrompt}, ${industryPrompt}, high quality, photorealistic, studio lighting, sharp focus, 8k uhd`;
  const negativePrompt = 'cartoon, anime, painting, blurry, distorted, disfigured, watermark, text, logo, bad anatomy';

  const result = await fal.run('fal-ai/flux/dev', {
    input: {
      prompt,
      negative_prompt: negativePrompt,
      image_url: params.faceImageUrl,
      num_images: params.count,
      image_size: { width: 1024, height: 1024 },
      num_inference_steps: 28,
      guidance_scale: 3.5,
      enable_safety_checker: true,
    },
  });

  const output = result as any;
  const images: string[] = (output?.images ?? []).map((img: any) => img.url ?? img);

  if (images.length === 0) {
    throw new Error('No images returned from FLUX generation');
  }

  return { imageUrls: images };
}

export async function upscaleImage(imageUrl: string): Promise<string> {
  const result = await fal.run('fal-ai/real-esrgan', {
    input: {
      image_url: imageUrl,
      scale: 4,
      face_enhance: true,
    },
  });

  const output = result as any;
  const url = output?.image?.url ?? output?.output_image_url;
  if (!url) throw new Error('No upscaled image URL returned');
  return url;
}

export async function generateFreePreview(params: {
  faceImageUrl: string;
  industry: string;
  style: string;
}): Promise<string> {
  const stylePrompt = STYLE_PROMPTS[params.style] ?? STYLE_PROMPTS.Modern;
  const prompt = `professional headshot portrait, ${stylePrompt}, high quality, photorealistic`;

  const result = await fal.run('fal-ai/stable-diffusion-v3-medium', {
    input: {
      prompt,
      image_url: params.faceImageUrl,
      num_images: 1,
      image_size: { width: 512, height: 512 },
    },
  });

  const output = result as any;
  const url = (output?.images?.[0]?.url) ?? null;
  if (!url) throw new Error('No preview image returned');
  return url;
}
