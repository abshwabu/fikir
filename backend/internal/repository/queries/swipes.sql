-- name: UpsertSwipe :exec
INSERT INTO swipes (swiper_id, target_id, direction, created_at)
VALUES ($1, $2, $3, $4)
ON CONFLICT (swiper_id, target_id) 
DO UPDATE SET direction = EXCLUDED.direction, created_at = EXCLUDED.created_at;

-- name: DeleteSwipe :exec
DELETE FROM swipes 
WHERE swiper_id = $1 AND target_id = $2;

-- name: GetSwipe :one
SELECT swiper_id, target_id, direction, created_at
FROM swipes
WHERE swiper_id = $1 AND target_id = $2;

-- name: CheckMutualLike :one
SELECT EXISTS (
    SELECT 1 FROM swipes
    WHERE swiper_id = $1 AND target_id = $2 AND direction IN ('like', 'super')
)::bool AS is_mutual;

-- name: CreateMatch :one
INSERT INTO matches (id, user_a, user_b, created_at)
VALUES ($1, $2, $3, NOW())
ON CONFLICT (user_a, user_b)
DO UPDATE SET unmatched_at = NULL
RETURNING id, user_a, user_b, created_at, unmatched_at;

-- name: Unmatch :exec
UPDATE matches
SET unmatched_at = NOW()
WHERE id = $1 AND (user_a = $2 OR user_b = $2);

-- name: GetMatchByID :one
SELECT id, user_a, user_b, created_at, unmatched_at
FROM matches
WHERE id = $1;

-- name: GetMatchBetweenUsers :one
SELECT id, user_a, user_b, created_at, unmatched_at
FROM matches
WHERE user_a = $1 AND user_b = $2;

-- name: ListUserMatches :many
SELECT 
    m.id,
    m.user_a,
    m.user_b,
    m.created_at,
    m.unmatched_at,
    (CASE WHEN m.user_a = @user_id THEN m.user_b ELSE m.user_a END)::uuid AS other_user_id,
    COALESCE(msg.id, 0)::int8 AS last_message_id,
    COALESCE(msg.body, '')::text AS last_message_body,
    COALESCE(msg.type, '')::text AS last_message_type,
    COALESCE(msg.sender_id, '00000000-0000-0000-0000-000000000000'::uuid)::uuid AS last_message_sender_id,
    msg.created_at AS last_message_created_at
FROM matches m
LEFT JOIN LATERAL (
    SELECT id, body, type, sender_id, created_at
    FROM messages
    WHERE match_id = m.id
    ORDER BY id DESC
    LIMIT 1
) msg ON true
WHERE (m.user_a = @user_id OR m.user_b = @user_id)
  AND m.unmatched_at IS NULL
  AND (@cursor_created_at::timestamptz IS NULL OR m.created_at < @cursor_created_at)
ORDER BY COALESCE(msg.created_at, m.created_at) DESC
LIMIT @result_limit::int4;

-- name: CreateBlock :exec
INSERT INTO blocks (blocker_id, blocked_id, created_at)
VALUES ($1, $2, NOW())
ON CONFLICT (blocker_id, blocked_id) DO NOTHING;

-- name: IsBlocked :one
SELECT EXISTS (
    SELECT 1 FROM blocks
    WHERE (blocker_id = $1 AND blocked_id = $2)
       OR (blocker_id = $2 AND blocked_id = $1)
)::bool AS blocked;

-- name: CreateReport :one
INSERT INTO reports (id, reporter_id, reported_id, reason, details, status, created_at)
VALUES ($1, $2, $3, $4, $5, $6, NOW())
RETURNING id, reporter_id, reported_id, reason, details, status, created_at;

-- name: GetLikesYouList :many
SELECT 
    s.swiper_id,
    s.direction,
    s.created_at
FROM swipes s
WHERE s.target_id = @user_id 
  AND s.direction IN ('like', 'super')
  AND NOT EXISTS (
      SELECT 1 FROM swipes my 
      WHERE my.swiper_id = @user_id AND my.target_id = s.swiper_id
  )
  AND NOT EXISTS (
      SELECT 1 FROM blocks b 
      WHERE (b.blocker_id = @user_id AND b.blocked_id = s.swiper_id)
         OR (b.blocker_id = s.swiper_id AND b.blocked_id = @user_id)
  )
ORDER BY s.created_at DESC
LIMIT @result_limit::int4;

-- name: CountLikesYou :one
SELECT COUNT(*) FROM swipes s
WHERE s.target_id = @user_id 
  AND s.direction IN ('like', 'super')
  AND NOT EXISTS (
      SELECT 1 FROM swipes my 
      WHERE my.swiper_id = @user_id AND my.target_id = s.swiper_id
  )
  AND NOT EXISTS (
      SELECT 1 FROM blocks b 
      WHERE (b.blocker_id = @user_id AND b.blocked_id = s.swiper_id)
         OR (b.blocker_id = s.swiper_id AND b.blocked_id = @user_id)
  );
