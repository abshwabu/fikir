-- Add boost_until to users and profiles
ALTER TABLE users ADD COLUMN IF NOT EXISTS boost_until TIMESTAMPTZ;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS boost_until TIMESTAMPTZ;

-- Performance indexes for Discovery, Swipes, Matches, and Blocks
CREATE INDEX IF NOT EXISTS idx_swipes_swiper_created ON swipes (swiper_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_swipes_target_direction_created ON swipes (target_id, direction, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_matches_users_active ON matches (user_a, user_b) WHERE unmatched_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_blocks_blocker_blocked ON blocks (blocker_id, blocked_id);
CREATE INDEX IF NOT EXISTS idx_blocks_blocked_blocker ON blocks (blocked_id, blocker_id);
