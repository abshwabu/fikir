-- 000001_init.up.sql
-- Fikir database schema initialization

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone_e164 VARCHAR(32) NOT NULL UNIQUE,
    status VARCHAR(32) NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_active_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_premium BOOLEAN NOT NULL DEFAULT FALSE,
    premium_until TIMESTAMPTZ,
    locale VARCHAR(10) NOT NULL DEFAULT 'am'
);

CREATE INDEX IF NOT EXISTS idx_users_active ON users (last_active_at DESC) WHERE status = 'active';

-- Profiles table
CREATE TABLE IF NOT EXISTS profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    display_name VARCHAR(100) NOT NULL,
    birthdate DATE NOT NULL,
    gender VARCHAR(32) NOT NULL,
    interested_in TEXT[] NOT NULL DEFAULT '{}',
    bio TEXT,
    job_title VARCHAR(120),
    education VARCHAR(120),
    height_cm INT,
    religion VARCHAR(60),
    languages TEXT[] NOT NULL DEFAULT '{}',
    city VARCHAR(100),
    region VARCHAR(100),
    geog GEOGRAPHY(Point, 4326),
    show_me BOOLEAN NOT NULL DEFAULT TRUE,
    distance_pref_km INT NOT NULL DEFAULT 50,
    age_min INT NOT NULL DEFAULT 18,
    age_max INT NOT NULL DEFAULT 100,
    verified BOOLEAN NOT NULL DEFAULT FALSE,
    completeness_score INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_profiles_geog ON profiles USING GIST (geog);
CREATE INDEX IF NOT EXISTS idx_profiles_discoverable ON profiles (gender, geog) WHERE show_me = TRUE;
CREATE INDEX IF NOT EXISTS idx_profiles_trgm_display_name ON profiles USING GIN (display_name gin_trgm_ops);

-- Profile Photos table
CREATE TABLE IF NOT EXISTS profile_photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    position INT NOT NULL,
    blurhash TEXT,
    width INT,
    height INT,
    variants JSONB NOT NULL DEFAULT '{}'::jsonb,
    status VARCHAR(32) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_profile_photos_user_position UNIQUE (user_id, position)
);

CREATE INDEX IF NOT EXISTS idx_profile_photos_user_id ON profile_photos (user_id, position);

-- Interests & User Interests
CREATE TABLE IF NOT EXISTS interests (
    id SERIAL PRIMARY KEY,
    name VARCHAR(60) NOT NULL UNIQUE,
    category VARCHAR(60) NOT NULL,
    icon VARCHAR(60),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_interests (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    interest_id INT NOT NULL REFERENCES interests(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, interest_id)
);

CREATE INDEX IF NOT EXISTS idx_user_interests_interest_id ON user_interests (interest_id);

-- Swipes table
CREATE TABLE IF NOT EXISTS swipes (
    swiper_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    direction VARCHAR(16) NOT NULL CHECK (direction IN ('like', 'nope', 'super')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (swiper_id, target_id)
);

CREATE INDEX IF NOT EXISTS idx_swipes_target_direction ON swipes (target_id, direction);
CREATE INDEX IF NOT EXISTS idx_swipes_created_at ON swipes (created_at DESC);

-- Matches table
CREATE TABLE IF NOT EXISTS matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_a UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_b UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    unmatched_at TIMESTAMPTZ,
    CONSTRAINT chk_user_a_less_than_user_b CHECK (user_a < user_b),
    CONSTRAINT uq_matches_users UNIQUE (user_a, user_b)
);

CREATE INDEX IF NOT EXISTS idx_matches_user_a ON matches (user_a) WHERE unmatched_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_matches_user_b ON matches (user_b) WHERE unmatched_at IS NULL;

-- Messages table
CREATE TABLE IF NOT EXISTS messages (
    id BIGSERIAL PRIMARY KEY,
    match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    body TEXT,
    type VARCHAR(32) NOT NULL DEFAULT 'text',
    media_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    read_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_messages_match_id_id_desc ON messages (match_id, id DESC);

-- Blocks table
CREATE TABLE IF NOT EXISTS blocks (
    blocker_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (blocker_id, blocked_id)
);

-- Reports table
CREATE TABLE IF NOT EXISTS reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reported_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reason VARCHAR(60) NOT NULL,
    details TEXT,
    status VARCHAR(32) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'resolved', 'dismissed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reports_reported_id ON reports (reported_id);
CREATE INDEX IF NOT EXISTS idx_reports_status ON reports (status);

-- Devices table
CREATE TABLE IF NOT EXISTS devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL UNIQUE,
    platform VARCHAR(32) NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_devices_user_id ON devices (user_id);

-- Subscriptions table
CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plan VARCHAR(64) NOT NULL,
    status VARCHAR(32) NOT NULL CHECK (status IN ('active', 'expired', 'cancelled')),
    starts_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_subscriptions_user_status ON subscriptions (user_id, status);

-- Payments table
CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider VARCHAR(32) NOT NULL CHECK (provider IN ('telebirr', 'chapa')),
    reference VARCHAR(128) NOT NULL UNIQUE,
    amount NUMERIC(10, 2) NOT NULL,
    currency VARCHAR(10) NOT NULL DEFAULT 'ETB',
    status VARCHAR(32) NOT NULL CHECK (status IN ('pending', 'success', 'failed')),
    raw_response JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payments_user_id ON payments (user_id);
CREATE INDEX IF NOT EXISTS idx_payments_reference ON payments (reference);
