-- 000003_media_verification.down.sql

DROP TABLE IF EXISTS verifications;

DELETE FROM interests WHERE name IN (
    'Coffee', 'Music', 'Travel', 'Football', 'Art',
    'Reading', 'Photography', 'Cooking', 'Dancing', 'Hiking',
    'Movies', 'Fitness', 'Tech', 'Fashion', 'Foodie'
);
