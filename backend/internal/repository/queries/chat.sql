-- name: CreateMessage :one
INSERT INTO messages (
    match_id,
    sender_id,
    body,
    type,
    client_msg_id,
    media_url,
    metadata,
    created_at
)
VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
RETURNING id, match_id, sender_id, body, type, client_msg_id, media_url, metadata, created_at, read_at;

-- name: GetMessageByID :one
SELECT id, match_id, sender_id, body, type, client_msg_id, media_url, metadata, created_at, read_at
FROM messages
WHERE id = $1;

-- name: GetMessageByClientMsgID :one
SELECT id, match_id, sender_id, body, type, client_msg_id, media_url, metadata, created_at, read_at
FROM messages
WHERE match_id = $1 AND client_msg_id = $2
LIMIT 1;

-- name: ListMessagesAfter :many
SELECT id, match_id, sender_id, body, type, client_msg_id, media_url, metadata, created_at, read_at
FROM messages
WHERE match_id = $1 AND id > $2
ORDER BY id ASC
LIMIT $3;

-- name: ListMessagesBefore :many
SELECT id, match_id, sender_id, body, type, client_msg_id, media_url, metadata, created_at, read_at
FROM messages
WHERE match_id = $1 AND (@before_id::int8 = 0 OR id < @before_id)
ORDER BY id DESC
LIMIT @result_limit::int4;

-- name: MarkMessagesAsRead :exec
UPDATE messages
SET read_at = NOW()
WHERE match_id = $1 
  AND sender_id != $2 
  AND read_at IS NULL 
  AND id <= $3;

-- name: UpdateMatchLastMessageAt :exec
UPDATE matches
SET last_message_at = $2
WHERE id = $1;

-- name: GetMatchParticipants :one
SELECT user_a, user_b, unmatched_at
FROM matches
WHERE id = $1;

-- name: DeleteDevice :exec
DELETE FROM devices
WHERE user_id = $1 AND fcm_token = $2;

-- name: GetActiveDevicesForUser :many
SELECT id, user_id, fcm_token, platform, updated_at
FROM devices
WHERE user_id = $1
ORDER BY updated_at DESC;

-- name: GetUserNotificationSettings :one
SELECT id, locale, notification_settings
FROM users
WHERE id = $1;

-- name: UpdateUserNotificationSettings :exec
UPDATE users
SET notification_settings = $2
WHERE id = $1;
