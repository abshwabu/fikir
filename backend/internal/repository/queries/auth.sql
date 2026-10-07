-- name: CreateRefreshToken :one
INSERT INTO refresh_tokens (user_id, token_hash, family_id, expires_at)
VALUES ($1, $2, $3, $4)
RETURNING id, user_id, token_hash, family_id, is_revoked, expires_at, created_at;

-- name: GetRefreshTokenByHash :one
SELECT id, user_id, token_hash, family_id, is_revoked, expires_at, created_at
FROM refresh_tokens
WHERE token_hash = $1
LIMIT 1;

-- name: RevokeRefreshToken :exec
UPDATE refresh_tokens
SET is_revoked = TRUE
WHERE id = $1;

-- name: RevokeTokenFamily :exec
UPDATE refresh_tokens
SET is_revoked = TRUE
WHERE family_id = $1;

-- name: RevokeAllUserTokens :exec
UPDATE refresh_tokens
SET is_revoked = TRUE
WHERE user_id = $1;

-- name: CreateAuthAuditLog :one
INSERT INTO auth_audit_logs (user_id, phone_e164, event, ip_address, user_agent, device_fingerprint, metadata)
VALUES ($1, $2, $3, $4, $5, $6, $7)
RETURNING id, user_id, phone_e164, event, ip_address, user_agent, device_fingerprint, metadata, created_at;

-- name: UpsertDevice :one
INSERT INTO devices (user_id, fcm_token, platform, updated_at)
VALUES ($1, $2, $3, NOW())
ON CONFLICT (fcm_token) DO UPDATE
SET user_id = EXCLUDED.user_id,
    platform = EXCLUDED.platform,
    updated_at = NOW()
RETURNING id, user_id, fcm_token, platform, created_at, updated_at;
