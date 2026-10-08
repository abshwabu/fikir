-- Migration: 000005_chat_notifications.up.sql

-- 1. Add last_message_at to matches for sorting and fast inbox preview
ALTER TABLE matches ADD COLUMN IF NOT EXISTS last_message_at TIMESTAMPTZ DEFAULT NULL;
CREATE INDEX IF NOT EXISTS idx_matches_last_message_at ON matches (last_message_at DESC NULLS LAST);

-- 2. Add client_msg_id, media_url, and metadata to messages table
ALTER TABLE messages ADD COLUMN IF NOT EXISTS client_msg_id VARCHAR(64) DEFAULT NULL;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS media_url TEXT DEFAULT NULL;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;

-- Indexes for replay and deduplication
CREATE INDEX IF NOT EXISTS idx_messages_match_id_id ON messages (match_id, id ASC);
CREATE INDEX IF NOT EXISTS idx_messages_client_msg_id ON messages (client_msg_id) WHERE client_msg_id IS NOT NULL;

-- 3. Add notification_settings to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS notification_settings JSONB DEFAULT '{"new_match": true, "new_message": true, "super_like": true}'::jsonb;

-- 4. Ensure devices index for active device lookups
CREATE INDEX IF NOT EXISTS idx_devices_user_id_updated_at ON devices (user_id, updated_at DESC);
