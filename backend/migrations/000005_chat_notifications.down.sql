-- Migration: 000005_chat_notifications.down.sql

DROP INDEX IF EXISTS idx_devices_user_id_updated_at;

ALTER TABLE users DROP COLUMN IF EXISTS notification_settings;

DROP INDEX IF EXISTS idx_messages_client_msg_id;
DROP INDEX IF EXISTS idx_messages_match_id_id;

ALTER TABLE messages DROP COLUMN IF EXISTS metadata;
ALTER TABLE messages DROP COLUMN IF EXISTS media_url;
ALTER TABLE messages DROP COLUMN IF EXISTS client_msg_id;

DROP INDEX IF EXISTS idx_matches_last_message_at;
ALTER TABLE matches DROP COLUMN IF EXISTS last_message_at;
