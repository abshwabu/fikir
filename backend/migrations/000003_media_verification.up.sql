-- 000003_media_verification.up.sql
-- Selfie verifications table and seed interests

CREATE TABLE IF NOT EXISTS verifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    photo_url TEXT NOT NULL,
    pose VARCHAR(50) NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reviewed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_verifications_user_id ON verifications (user_id);
CREATE INDEX IF NOT EXISTS idx_verifications_status ON verifications (status);

-- Seed initial interests
INSERT INTO interests (name, category) VALUES
    ('Coffee', 'Lifestyle'),
    ('Music', 'Entertainment'),
    ('Travel', 'Adventure'),
    ('Football', 'Sports'),
    ('Art', 'Creativity'),
    ('Reading', 'Culture'),
    ('Photography', 'Creativity'),
    ('Cooking', 'Food'),
    ('Dancing', 'Entertainment'),
    ('Hiking', 'Adventure'),
    ('Movies', 'Entertainment'),
    ('Fitness', 'Health'),
    ('Tech', 'Lifestyle'),
    ('Fashion', 'Lifestyle'),
    ('Foodie', 'Food')
ON CONFLICT (name) DO NOTHING;
