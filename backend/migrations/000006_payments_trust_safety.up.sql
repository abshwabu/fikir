-- Migration: 000006_payments_trust_safety.up.sql
-- Subscriptions plans, payment details, trust & safety, moderation, and cultural fields

-- 1. Subscription Plans table
CREATE TABLE IF NOT EXISTS subscription_plans (
    id VARCHAR(64) PRIMARY KEY,
    tier VARCHAR(32) NOT NULL CHECK (tier IN ('plus', 'gold')),
    name VARCHAR(64) NOT NULL,
    duration_days INT NOT NULL,
    price_etb NUMERIC(10, 2) NOT NULL,
    perks JSONB NOT NULL DEFAULT '[]'::jsonb,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed Ethiopian ETB plans
INSERT INTO subscription_plans (id, tier, name, duration_days, price_etb, perks) VALUES
    ('plus_weekly', 'plus', 'Fikir Plus Weekly', 7, 99.00, '["unlimited_likes", "rewind", "hide_distance", "five_super_likes_week"]'::jsonb),
    ('plus_monthly', 'plus', 'Fikir Plus Monthly', 30, 299.00, '["unlimited_likes", "rewind", "hide_distance", "five_super_likes_week"]'::jsonb),
    ('gold_weekly', 'gold', 'Fikir Gold Weekly', 7, 199.00, '["unlimited_likes", "rewind", "see_who_likes_you", "one_boost_week", "five_super_likes_week", "diaspora_mode", "verified_only_filter"]'::jsonb),
    ('gold_monthly', 'gold', 'Fikir Gold Monthly', 30, 499.00, '["unlimited_likes", "rewind", "see_who_likes_you", "one_boost_week", "five_super_likes_week", "diaspora_mode", "verified_only_filter"]'::jsonb),
    ('gold_quarterly', 'gold', 'Fikir Gold 3-Months', 90, 1199.00, '["unlimited_likes", "rewind", "see_who_likes_you", "one_boost_week", "five_super_likes_week", "diaspora_mode", "verified_only_filter"]'::jsonb)
ON CONFLICT (id) DO UPDATE SET
    price_etb = EXCLUDED.price_etb,
    perks = EXCLUDED.perks,
    is_active = EXCLUDED.is_active;

-- 2. Enhance Subscriptions table
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS tier VARCHAR(32) DEFAULT 'gold';
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS plan_id VARCHAR(64) REFERENCES subscription_plans(id) ON DELETE SET NULL;
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS auto_renew BOOLEAN DEFAULT FALSE;
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS reminder_sent_at TIMESTAMPTZ DEFAULT NULL;

-- 3. Enhance Payments table
ALTER TABLE payments ADD COLUMN IF NOT EXISTS plan_id VARCHAR(64) REFERENCES subscription_plans(id) ON DELETE SET NULL;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS checkout_url TEXT DEFAULT NULL;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS payment_method VARCHAR(32) DEFAULT 'chapa';
ALTER TABLE payments ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ DEFAULT NULL;
ALTER TABLE payments DROP CONSTRAINT IF EXISTS payments_provider_check;
ALTER TABLE payments ADD CONSTRAINT payments_provider_check CHECK (provider IN ('telebirr', 'chapa', 'google_play', 'cbe_birr'));

-- 4. Enhance profile_photos with pHash and moderation metadata
ALTER TABLE profile_photos ADD COLUMN IF NOT EXISTS phash VARCHAR(64) DEFAULT NULL;
ALTER TABLE profile_photos ADD COLUMN IF NOT EXISTS moderation_reason TEXT DEFAULT NULL;
ALTER TABLE profile_photos ADD COLUMN IF NOT EXISTS reviewed_by VARCHAR(64) DEFAULT NULL;
ALTER TABLE profile_photos ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ DEFAULT NULL;
CREATE INDEX IF NOT EXISTS idx_profile_photos_phash ON profile_photos (phash) WHERE phash IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_profile_photos_status ON profile_photos (status);

-- 5. Enhance profiles with Cultural Fit, Diaspora mode, and Obfuscated Location Offsets
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS looking_for VARCHAR(32) DEFAULT NULL;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS family_oriented BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS diaspora_mode BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS diaspora_city VARCHAR(100) DEFAULT NULL;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS diaspora_country VARCHAR(100) DEFAULT NULL;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_shadow_banned BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS display_lat_offset DOUBLE PRECISION DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS display_lon_offset DOUBLE PRECISION DEFAULT 0;

-- 6. Enhance users with Legal, Privacy, and Ban tracking
ALTER TABLE users ADD COLUMN IF NOT EXISTS terms_accepted_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE users ADD COLUMN IF NOT EXISTS privacy_accepted_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE users ADD COLUMN IF NOT EXISTS banned_at TIMESTAMPTZ DEFAULT NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS ban_reason TEXT DEFAULT NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS device_fingerprint VARCHAR(128) DEFAULT NULL;
CREATE INDEX IF NOT EXISTS idx_users_device_fingerprint ON users (device_fingerprint) WHERE device_fingerprint IS NOT NULL;

-- 7. Banned Identifiers (prevent banned phones, devices, and tokens from re-registering)
CREATE TABLE IF NOT EXISTS banned_identifiers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type VARCHAR(32) NOT NULL CHECK (type IN ('phone', 'device_fingerprint', 'fcm_token')),
    value VARCHAR(256) NOT NULL UNIQUE,
    reason TEXT,
    banned_by VARCHAR(64),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_banned_identifiers_lookup ON banned_identifiers (type, value);

-- 8. Admin Audit Logs
CREATE TABLE IF NOT EXISTS admin_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id VARCHAR(64) NOT NULL,
    action VARCHAR(64) NOT NULL,
    target_type VARCHAR(32) NOT NULL,
    target_id VARCHAR(128) NOT NULL,
    details JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_created_at ON admin_audit_logs (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_target ON admin_audit_logs (target_type, target_id);
