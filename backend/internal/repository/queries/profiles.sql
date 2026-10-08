-- name: GetProfileByUserID :one
SELECT user_id, display_name, birthdate, gender, interested_in, bio,
       job_title, education, height_cm, religion, languages, city, region,
       ST_Y(geog::geometry) AS latitude, ST_X(geog::geometry) AS longitude,
       show_me, distance_pref_km, age_min, age_max, verified, completeness_score,
       created_at, updated_at
FROM profiles
WHERE user_id = $1 LIMIT 1;

-- name: UpsertProfile :one
INSERT INTO profiles (
    user_id, display_name, birthdate, gender, interested_in, bio,
    job_title, education, height_cm, religion, languages, city, region,
    show_me, distance_pref_km, age_min, age_max, completeness_score, updated_at
) VALUES (
    $1, $2, $3, $4, $5, $6,
    $7, $8, $9, $10, $11, $12, $13,
    $14, $15, $16, $17, $18, NOW()
)
ON CONFLICT (user_id) DO UPDATE SET
    display_name = COALESCE(EXCLUDED.display_name, profiles.display_name),
    birthdate = COALESCE(EXCLUDED.birthdate, profiles.birthdate),
    gender = COALESCE(EXCLUDED.gender, profiles.gender),
    interested_in = COALESCE(EXCLUDED.interested_in, profiles.interested_in),
    bio = COALESCE(EXCLUDED.bio, profiles.bio),
    job_title = COALESCE(EXCLUDED.job_title, profiles.job_title),
    education = COALESCE(EXCLUDED.education, profiles.education),
    height_cm = COALESCE(EXCLUDED.height_cm, profiles.height_cm),
    religion = COALESCE(EXCLUDED.religion, profiles.religion),
    languages = COALESCE(EXCLUDED.languages, profiles.languages),
    city = COALESCE(EXCLUDED.city, profiles.city),
    region = COALESCE(EXCLUDED.region, profiles.region),
    show_me = EXCLUDED.show_me,
    distance_pref_km = EXCLUDED.distance_pref_km,
    age_min = EXCLUDED.age_min,
    age_max = EXCLUDED.age_max,
    completeness_score = EXCLUDED.completeness_score,
    updated_at = NOW()
RETURNING user_id, display_name, birthdate, gender, interested_in, bio,
          job_title, education, height_cm, religion, languages, city, region,
          ST_Y(geog::geometry) AS latitude, ST_X(geog::geometry) AS longitude,
          show_me, distance_pref_km, age_min, age_max, verified, completeness_score,
          created_at, updated_at;

-- name: UpdateProfileLocation :exec
UPDATE profiles
SET geog = ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography,
    city = $4,
    region = $5,
    updated_at = NOW()
WHERE user_id = $1;

-- name: UpdateProfileCompleteness :exec
UPDATE profiles
SET completeness_score = $2,
    show_me = CASE WHEN $3 = 0 THEN FALSE ELSE show_me END,
    updated_at = NOW()
WHERE user_id = $1;

-- name: GetPhotosByUserID :many
SELECT id, user_id, position, blurhash, width, height, variants, status, created_at
FROM profile_photos
WHERE user_id = $1
ORDER BY position ASC;

-- name: GetPhotoByID :one
SELECT id, user_id, position, blurhash, width, height, variants, status, created_at
FROM profile_photos
WHERE id = $1 LIMIT 1;

-- name: CreateProfilePhoto :one
INSERT INTO profile_photos (id, user_id, position, blurhash, width, height, variants, status)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
RETURNING id, user_id, position, blurhash, width, height, variants, status, created_at;

-- name: UpdateProfilePhoto :exec
UPDATE profile_photos
SET blurhash = $2,
    width = $3,
    height = $4,
    variants = $5,
    status = $6
WHERE id = $1;

-- name: DeleteProfilePhoto :exec
DELETE FROM profile_photos
WHERE id = $1 AND user_id = $2;

-- name: CountProfilePhotos :one
SELECT COUNT(*) FROM profile_photos
WHERE user_id = $1;

-- name: CountApprovedProfilePhotos :one
SELECT COUNT(*) FROM profile_photos
WHERE user_id = $1 AND status = 'approved';

-- name: UpdatePhotoPosition :exec
UPDATE profile_photos
SET position = $2
WHERE id = $1 AND user_id = $3;

-- name: GetUserInterests :many
SELECT i.name
FROM interests i
JOIN user_interests ui ON i.id = ui.interest_id
WHERE ui.user_id = $1
ORDER BY i.name ASC;

-- name: ClearUserInterests :exec
DELETE FROM user_interests WHERE user_id = $1;

-- name: AddUserInterestByName :exec
INSERT INTO user_interests (user_id, interest_id)
SELECT $1, id FROM interests WHERE LOWER(name) = LOWER($2)
ON CONFLICT DO NOTHING;

-- name: CreateVerification :one
INSERT INTO verifications (id, user_id, photo_url, pose, status)
VALUES ($1, $2, $3, $4, $5)
RETURNING id, user_id, photo_url, pose, status, created_at, reviewed_at;
