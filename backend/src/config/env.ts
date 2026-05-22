import { z } from 'zod';
import dotenv from 'dotenv';

dotenv.config();

const envSchema = z.object({
  FAL_KEY:                   z.string().min(1),
  SUPABASE_URL:              z.string().url(),
  SUPABASE_SERVICE_KEY:      z.string().min(1),
  R2_ACCOUNT_ID:             z.string().min(1),
  R2_ACCESS_KEY_ID:          z.string().min(1),
  R2_SECRET_ACCESS_KEY:      z.string().min(1),
  R2_BUCKET_NAME:            z.string().default('headshots-prod'),
  R2_PUBLIC_URL:             z.string().url(),
  REDIS_URL:                 z.string().min(1),
  REVENUECAT_WEBHOOK_SECRET: z.string().min(1),
  JWT_SECRET:                z.string().min(32),
  ONESIGNAL_APP_ID:          z.string().min(1),
  ONESIGNAL_API_KEY:         z.string().min(1),
  APPLE_BUNDLE_ID:           z.string().default('com.yourcompany.aiheadshot'),
  PORT:                      z.coerce.number().default(3000),
  NODE_ENV:                  z.enum(['development', 'production', 'test']).default('development'),
});

function validateEnv() {
  const result = envSchema.safeParse(process.env);
  if (!result.success) {
    console.error('❌ Invalid environment variables:');
    result.error.issues.forEach(issue => {
      console.error(`  ${issue.path.join('.')}: ${issue.message}`);
    });
    process.exit(1);
  }
  return result.data;
}

export const env = validateEnv();
export type Env = z.infer<typeof envSchema>;
