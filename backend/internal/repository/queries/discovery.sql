-- name: GetDiscoveryCandidates :many
SELECT 
    p.user_id,
    p.display_name,
    p.birthdate,
    p.gender,
    p.bio,
    p.job_title,
    p.education,
    p.height_cm,
    p.religion,
    p.city,
    p.region,
    ST_Y(p.geog::geometry) AS latitude,
    ST_X(p.geog::geometry) AS longitude,
    CASE WHEN p.geog IS NOT NULL AND @my_lat::float8 != 0.0 AND @my_lng::float8 != 0.0
         THEN ST_Distance(p.geog, ST_SetSRID(ST_MakePoint(@my_lng, @my_lat), 4326)::geography) / 1000.0
         ELSE 0.0 END AS distance_km,
    p.verified,
    p.completeness_score,
    u.last_active_at,
    p.boost_until,
    (
        (1.0 / (1.0 + EXTRACT(EPOCH FROM (NOW() - u.last_active_at)) / 86400.0)) * 30.0 +
        (p.completeness_score * 0.2) +
        (CASE WHEN p.geog IS NOT NULL AND @my_lat::float8 != 0.0 AND @my_lng::float8 != 0.0
              THEN (1.0 / (1.0 + ST_Distance(p.geog, ST_SetSRID(ST_MakePoint(@my_lng, @my_lat), 4326)::geography) / 10000.0)) * 20.0
              ELSE 10.0 END) +
        (CASE WHEN EXISTS (
            SELECT 1 FROM swipes sw 
            WHERE sw.swiper_id = p.user_id AND sw.target_id = @user_id AND sw.direction IN ('like', 'super')
        ) THEN 50.0 ELSE 0.0 END) +
        (CASE WHEN (u.boost_until IS NOT NULL AND u.boost_until > NOW()) OR (p.boost_until IS NOT NULL AND p.boost_until > NOW())
              THEN 100.0 ELSE 0.0 END) +
        (random() * 5.0)
    )::float8 AS score
FROM profiles p
JOIN users u ON u.id = p.user_id
WHERE p.user_id != @user_id
  AND p.show_me = TRUE
  AND u.status = 'active'
  AND u.last_active_at >= NOW() - INTERVAL '30 days'
  AND (
      @my_gender::text = ANY(p.interested_in)
      OR (@my_gender::text = 'man' AND ('men' = ANY(p.interested_in) OR 'everyone' = ANY(p.interested_in)))
      OR (@my_gender::text = 'woman' AND ('women' = ANY(p.interested_in) OR 'everyone' = ANY(p.interested_in)))
      OR 'everyone' = ANY(p.interested_in)
  )
  AND (
      p.gender = ANY(@my_interested_in::text[])
      OR (p.gender = 'man' AND ('men' = ANY(@my_interested_in::text[]) OR 'everyone' = ANY(@my_interested_in::text[])))
      OR (p.gender = 'woman' AND ('women' = ANY(@my_interested_in::text[]) OR 'everyone' = ANY(@my_interested_in::text[])))
      OR 'everyone' = ANY(@my_interested_in::text[])
  )
  AND EXTRACT(YEAR FROM age(CURRENT_DATE, @my_birthdate::date)) BETWEEN p.age_min AND p.age_max
  AND EXTRACT(YEAR FROM age(CURRENT_DATE, p.birthdate)) BETWEEN @age_min::int4 AND @age_max::int4
  AND (
      @radius_meters::float8 <= 0.0 
      OR p.geog IS NULL 
      OR @my_lat::float8 = 0.0 
      OR ST_DWithin(p.geog, ST_SetSRID(ST_MakePoint(@my_lng, @my_lat), 4326)::geography, @radius_meters)
  )
  AND EXISTS (
      SELECT 1 FROM profile_photos ph
      WHERE ph.user_id = p.user_id AND ph.status IN ('approved', 'pending')
  )
  AND NOT EXISTS (
      SELECT 1 FROM blocks b
      WHERE (b.blocker_id = @user_id AND b.blocked_id = p.user_id)
         OR (b.blocker_id = p.user_id AND b.blocked_id = @user_id)
  )
  AND NOT EXISTS (
      SELECT 1 FROM swipes s
      WHERE s.swiper_id = @user_id AND s.target_id = p.user_id
  )
  AND NOT (p.user_id = ANY(@excluded_ids::uuid[]))
ORDER BY score DESC
LIMIT @result_limit::int4;

-- name: GetProfileCardByUserID :one
SELECT 
    p.user_id,
    p.display_name,
    p.birthdate,
    p.gender,
    p.bio,
    p.job_title,
    p.education,
    p.height_cm,
    p.religion,
    p.city,
    p.region,
    p.verified,
    p.completeness_score,
    u.last_active_at
FROM profiles p
JOIN users u ON u.id = p.user_id
WHERE p.user_id = $1 LIMIT 1;

