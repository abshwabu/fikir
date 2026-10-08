DROP INDEX IF EXISTS idx_blocks_blocked_blocker;
DROP INDEX IF EXISTS idx_blocks_blocker_blocked;
DROP INDEX IF EXISTS idx_matches_users_active;
DROP INDEX IF EXISTS idx_swipes_target_direction_created;
DROP INDEX IF EXISTS idx_swipes_swiper_created;

ALTER TABLE profiles DROP COLUMN IF EXISTS boost_until;
ALTER TABLE users DROP COLUMN IF EXISTS boost_until;
