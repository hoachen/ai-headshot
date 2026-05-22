import {
  S3Client,
  PutObjectCommand,
  DeleteObjectCommand,
  HeadObjectCommand,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import axios from 'axios';
import { env } from '../config/env.js';

const s3 = new S3Client({
  region: 'auto',
  endpoint: `https://${env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId:     env.R2_ACCESS_KEY_ID,
    secretAccessKey: env.R2_SECRET_ACCESS_KEY,
  },
});

const TTL_SECONDS = 86400; // 24 hours

export async function uploadFromUrl(remoteUrl: string, key: string): Promise<string> {
  const response = await axios.get(remoteUrl, { responseType: 'arraybuffer', timeout: 60_000 });
  const body = Buffer.from(response.data);
  const contentType = (response.headers['content-type'] as string) ?? 'image/jpeg';

  await s3.send(new PutObjectCommand({
    Bucket:      env.R2_BUCKET_NAME,
    Key:         key,
    Body:        body,
    ContentType: contentType,
    // R2 lifecycle rules handle actual deletion; this is for documentation
    Metadata: {
      expires_at: new Date(Date.now() + TTL_SECONDS * 1000).toISOString(),
    },
  }));

  return `${env.R2_PUBLIC_URL}/${key}`;
}

export async function uploadBuffer(buffer: Buffer, key: string, contentType: string): Promise<string> {
  await s3.send(new PutObjectCommand({
    Bucket:      env.R2_BUCKET_NAME,
    Key:         key,
    Body:        buffer,
    ContentType: contentType,
    Metadata: {
      expires_at: new Date(Date.now() + TTL_SECONDS * 1000).toISOString(),
    },
  }));
  return `${env.R2_PUBLIC_URL}/${key}`;
}

export async function deleteObject(key: string): Promise<void> {
  await s3.send(new DeleteObjectCommand({
    Bucket: env.R2_BUCKET_NAME,
    Key:    key,
  }));
}

export async function getPresignedUploadUrl(key: string, contentType: string): Promise<string> {
  return getSignedUrl(
    s3,
    new PutObjectCommand({ Bucket: env.R2_BUCKET_NAME, Key: key, ContentType: contentType }),
    { expiresIn: 300 }
  );
}

export function keyFromPublicUrl(publicUrl: string): string {
  return publicUrl.replace(`${env.R2_PUBLIC_URL}/`, '');
}

export async function objectExists(key: string): Promise<boolean> {
  try {
    await s3.send(new HeadObjectCommand({ Bucket: env.R2_BUCKET_NAME, Key: key }));
    return true;
  } catch {
    return false;
  }
}
