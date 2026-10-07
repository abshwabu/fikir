-- 000002_auth.down.sql

DROP TABLE IF EXISTS auth_audit_logs;
DROP TABLE IF EXISTS refresh_tokens;
ALTER TABLE users DROP COLUMN IF EXISTS deleted_at;
