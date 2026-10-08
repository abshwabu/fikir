-- Performance & Index Hardening Migration
-- Enable query performance statistics tracking
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Swipes Hot-Path Composite Indexes
CREATE INDEX IF NOT EXISTS idx_swipes_swiper_created ON swipes (swiper_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_swipes_target_direction_created ON swipes (target_id, direction, created_at DESC);

-- Matches Hot-Path Composite Indexes with last_message_at
CREATE INDEX IF NOT EXISTS idx_matches_user_a_last_msg ON matches (user_a, last_message_at DESC NULLS LAST) WHERE unmatched_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_matches_user_b_last_msg ON matches (user_b, last_message_at DESC NULLS LAST) WHERE unmatched_at IS NULL;

-- Messages match cursor index
CREATE INDEX IF NOT EXISTS idx_messages_match_created_id ON messages (match_id, created_at DESC, id DESC);

-- Payment Ledger Status Filter Lookups
CREATE INDEX IF NOT EXISTS idx_payments_status_created ON payments (status, created_at DESC);

-- Profiles Discovery Filter Partial Index for active non-shadow-banned candidates
CREATE INDEX IF NOT EXISTS idx_profiles_discovery_filters ON profiles (gender, birthdate, diaspora_mode) WHERE (show_me = true AND is_shadow_banned = false);
