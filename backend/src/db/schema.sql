-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table
CREATE TABLE IF NOT EXISTS users (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  apple_user_id   TEXT UNIQUE NOT NULL,
  email           TEXT,
  tier            TEXT NOT NULL DEFAULT 'free' CHECK (tier IN ('free', 'pro')),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at      TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_users_apple_user_id ON users(apple_user_id);

-- Job status enum
DO $$ BEGIN
  CREATE TYPE job_status AS ENUM (
    'PENDING', 'FACE_CHECK', 'EMBEDDING', 'GENERATING',
    'UPSCALING', 'UPLOADING', 'DONE', 'FAILED'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Jobs table
CREATE TABLE IF NOT EXISTS jobs (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status            job_status NOT NULL DEFAULT 'PENDING',
  tier              TEXT NOT NULL DEFAULT 'free' CHECK (tier IN ('free', 'pro')),
  industry          TEXT NOT NULL,
  style             TEXT NOT NULL,
  error_code        TEXT,
  result_urls       TEXT[],
  photos_deleted_at TIMESTAMPTZ,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at      TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_jobs_user_id  ON jobs(user_id);
CREATE INDEX IF NOT EXISTS idx_jobs_status   ON jobs(status);

-- Subscriptions table
CREATE TABLE IF NOT EXISTS subscriptions (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  rc_customer_id      TEXT NOT NULL,
  plan                TEXT NOT NULL CHECK (plan IN ('monthly', 'annual')),
  status              TEXT NOT NULL CHECK (status IN ('active', 'cancelled', 'past_due', 'trial')),
  current_period_end  TIMESTAMPTZ NOT NULL,
  trial_end           TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_rc_customer_id ON subscriptions(rc_customer_id);

-- Templates table
CREATE TABLE IF NOT EXISTS templates (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name            TEXT NOT NULL,
  industry        TEXT NOT NULL,
  style_prompt    TEXT NOT NULL,
  preview_url     TEXT,
  tier_required   TEXT NOT NULL DEFAULT 'free' CHECK (tier_required IN ('free', 'pro')),
  active          BOOLEAN NOT NULL DEFAULT true,
  sort_order      INTEGER NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Generation credits table
CREATE TABLE IF NOT EXISTS generation_credits (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount     INTEGER NOT NULL,
  reason     TEXT NOT NULL CHECK (reason IN ('subscription', 'refund', 'bonus')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_generation_credits_user_id ON generation_credits(user_id);

-- Row Level Security
ALTER TABLE users              ENABLE ROW LEVEL SECURITY;
ALTER TABLE jobs               ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE templates          ENABLE ROW LEVEL SECURITY;
ALTER TABLE generation_credits ENABLE ROW LEVEL SECURITY;

-- Service role bypasses RLS — backend uses service role key only

-- Seed templates
INSERT INTO templates (name, industry, style_prompt, tier_required, sort_order) VALUES
  ('Tech Professional',  'Tech',     'modern tech company office, clean minimal background, professional lighting', 'free', 1),
  ('Finance Executive',  'Finance',  'wall street financial district backdrop, formal business attire, authoritative', 'pro', 2),
  ('Legal Authority',    'Legal',    'law firm bookshelf background, formal suit, trustworthy and confident', 'pro', 3),
  ('Medical Expert',     'Medical',  'clean clinical white background, healthcare professional, approachable', 'pro', 4),
  ('Creative Director',  'Creative', 'modern creative studio, artistic background, stylish professional', 'pro', 5),
  ('Sales Champion',     'Sales',    'warm office background, friendly smile, approachable business professional', 'free', 6)
ON CONFLICT DO NOTHING;
