-- Migration: 000006_payments_trust_safety.down.sql

DROP TABLE IF EXISTS admin_audit_logs;
DROP TABLE IF EXISTS banned_identifiers;

ALTER TABLE users DROP COLUMN IF EXISTS terms_accepted_at;
ALTER TABLE users DROP COLUMN IF EXISTS privacy_accepted_at;
ALTER TABLE users DROP COLUMN IF EXISTS banned_at;
ALTER TABLE users DROP COLUMN IF EXISTS ban_reason;
ALTER TABLE users DROP COLUMN IF EXISTS device_fingerprint;

ALTER TABLE profiles DROP COLUMN IF EXISTS looking_for;
ALTER TABLE profiles DROP COLUMN IF EXISTS family_oriented;
ALTER TABLE profiles DROP COLUMN IF EXISTS diaspora_mode;
ALTER TABLE profiles DROP COLUMN IF EXISTS diaspora_city;
ALTER TABLE profiles DROP COLUMN IF EXISTS diaspora_country;
ALTER TABLE profiles DROP COLUMN IF EXISTS is_shadow_banned;
ALTER TABLE profiles DROP COLUMN IF EXISTS display_lat_offset;
ALTER TABLE profiles DROP COLUMN IF EXISTS display_lon_offset;

ALTER TABLE profile_photos DROP COLUMN IF EXISTS phash;
ALTER TABLE profile_photos DROP COLUMN IF EXISTS moderation_reason;
ALTER TABLE profile_photos DROP COLUMN IF EXISTS reviewed_by;
ALTER TABLE profile_photos DROP COLUMN IF EXISTS reviewed_at;

ALTER TABLE payments DROP COLUMN IF EXISTS plan_id;
ALTER TABLE payments DROP COLUMN IF EXISTS checkout_url;
ALTER TABLE payments DROP COLUMN IF EXISTS payment_method;
ALTER TABLE payments DROP COLUMN IF EXISTS completed_at;

ALTER TABLE subscriptions DROP COLUMN IF EXISTS tier;
ALTER TABLE subscriptions DROP COLUMN IF EXISTS plan_id;
ALTER TABLE subscriptions DROP COLUMN IF EXISTS auto_renew;
ALTER TABLE subscriptions DROP COLUMN IF EXISTS reminder_sent_at;

DROP TABLE IF EXISTS subscription_plans;
