-- name: GetUserByID :one
SELECT id, phone_e164, status, created_at, last_active_at, is_premium, premium_until, locale, deleted_at
FROM users
WHERE id = $1 LIMIT 1;

-- name: GetUserByPhone :one
SELECT id, phone_e164, status, created_at, last_active_at, is_premium, premium_until, locale, deleted_at
FROM users
WHERE phone_e164 = $1 LIMIT 1;

-- name: CreateUser :one
INSERT INTO users (phone_e164, status, locale)
VALUES ($1, $2, $3)
RETURNING id, phone_e164, status, created_at, last_active_at, is_premium, premium_until, locale, deleted_at;

-- name: UpdateUserLastActive :exec
UPDATE users
SET last_active_at = NOW()
WHERE id = $1;

-- name: SoftDeleteUser :exec
UPDATE users
SET status = 'deleted', deleted_at = NOW()
WHERE id = $1;

-- name: PurgeDeletedUsers :execrows
DELETE FROM users
WHERE deleted_at IS NOT NULL AND deleted_at < $1;
