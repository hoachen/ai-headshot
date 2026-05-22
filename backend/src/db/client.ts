import { createClient } from '@supabase/supabase-js';
import { env } from '../config/env.js';

export const supabase = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_KEY, {
  auth: { persistSession: false },
});

export type Database = {
  users: {
    id: string;
    apple_user_id: string;
    email: string | null;
    tier: 'free' | 'pro';
    created_at: string;
    deleted_at: string | null;
  };
  jobs: {
    id: string;
    user_id: string;
    status: JobStatus;
    tier: 'free' | 'pro';
    industry: string;
    style: string;
    error_code: string | null;
    result_urls: string[] | null;
    photos_deleted_at: string | null;
    created_at: string;
    completed_at: string | null;
  };
  subscriptions: {
    id: string;
    user_id: string;
    rc_customer_id: string;
    plan: 'monthly' | 'annual';
    status: 'active' | 'cancelled' | 'past_due' | 'trial';
    current_period_end: string;
    trial_end: string | null;
    created_at: string;
  };
  templates: {
    id: string;
    name: string;
    industry: string;
    style_prompt: string;
    preview_url: string | null;
    tier_required: 'free' | 'pro';
    active: boolean;
    sort_order: number;
    created_at: string;
  };
};

export type JobStatus =
  | 'PENDING' | 'FACE_CHECK' | 'EMBEDDING' | 'GENERATING'
  | 'UPSCALING' | 'UPLOADING' | 'DONE' | 'FAILED';
