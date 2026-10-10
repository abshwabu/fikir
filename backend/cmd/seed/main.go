package main

import (
	"context"
	"encoding/json"
	"log"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"

	"github.com/abshwabu/fikir/backend/internal/config"
)

type seedCandidate struct {
	Phone        string
	Name         string
	Gender       string
	InterestedIn []string
	Age          int
	City         string
	Region       string
	Lat          float64
	Lng          float64
	JobTitle     string
	Education    string
	Religion     string
	Bio          string
	PhotoURL     string
	Blurhash     string
	Interests    []string
}

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	ctx := context.Background()

	// Connect to PostgreSQL
	dbPool, err := pgxpool.New(ctx, cfg.Database.DSN())
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer dbPool.Close()

	// Connect to Redis
	rdb := redis.NewClient(&redis.Options{
		Addr:     cfg.Redis.Addr(),
		Password: cfg.Redis.Password,
		DB:       cfg.Redis.CacheDB,
	})
	defer rdb.Close()

	candidates := []seedCandidate{
		{
			Phone:        "+251911000011",
			Name:         "Selamawit",
			Gender:       "woman",
			InterestedIn: []string{"man", "men", "everyone"},
			Age:          24,
			City:         "Addis Ababa (Bole)",
			Region:       "Addis Ababa",
			Lat:          9.0012,
			Lng:          38.7845,
			JobTitle:     "Architect",
			Education:    "Addis Ababa University",
			Religion:     "Orthodox",
			Bio:          "Coffee lover ☕, traditional music enthusiast, architect based in Bole. Always up for good conversations over buna.",
			PhotoURL:     "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800",
			Blurhash:     "L6PZfSi_.AyE_3t7t7R**0o#DgR4",
			Interests:    []string{"Coffee", "Art", "Travel"},
		},
		{
			Phone:        "+251911000012",
			Name:         "Bethlehem",
			Gender:       "woman",
			InterestedIn: []string{"man", "men", "everyone"},
			Age:          25,
			City:         "Addis Ababa (Kazanchis)",
			Region:       "Addis Ababa",
			Lat:          9.0150,
			Lng:          38.7690,
			JobTitle:     "Public Health Specialist",
			Education:    "Gondar University",
			Religion:     "Orthodox",
			Bio:          "Public health researcher with a heart for volunteering. Love traditional dance, shiro tagamino, and weekend runs.",
			PhotoURL:     "https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?w=800",
			Blurhash:     "LDF~G2~q000000-;~q00-;00~q00",
			Interests:    []string{"Dancing", "Cooking", "Hiking"},
		},
		{
			Phone:        "+251911000013",
			Name:         "Hanna",
			Gender:       "woman",
			InterestedIn: []string{"man", "men", "everyone"},
			Age:          23,
			City:         "Hawassa",
			Region:       "Sidama",
			Lat:          7.0621,
			Lng:          38.4764,
			JobTitle:     "Content Strategist",
			Education:    "Hawassa University",
			Religion:     "Protestant",
			Bio:          "Literature graduate, Tana sunset lover 🌅, fascinated by Ethiopian poetry and photography.",
			PhotoURL:     "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=800",
			Blurhash:     "LGF5]+Yk^6#M@-5c,1J5@[or[Q6.",
			Interests:    []string{"Reading", "Photography", "Travel"},
		},
		{
			Phone:        "+251911000014",
			Name:         "Rahel",
			Gender:       "woman",
			InterestedIn: []string{"man", "men", "everyone"},
			Age:          26,
			City:         "Addis Ababa (Sarbet)",
			Region:       "Addis Ababa",
			Lat:          9.0040,
			Lng:          38.7420,
			JobTitle:     "Fintech Product Manager",
			Education:    "AAU School of Commerce",
			Religion:     "Orthodox",
			Bio:          "Tech enthusiast building financial inclusion. When not working, finding the city's hidden art spots.",
			PhotoURL:     "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=800",
			Blurhash:     "L7A0v}00~q_3_300-;IU-;IU~qIU",
			Interests:    []string{"Music", "Art", "Coffee"},
		},
		{
			Phone:        "+251911000015",
			Name:         "Tigist",
			Gender:       "woman",
			InterestedIn: []string{"man", "men", "everyone"},
			Age:          27,
			City:         "Bahir Dar",
			Region:       "Amhara",
			Lat:          11.5936,
			Lng:          37.3908,
			JobTitle:     "Environmental Scientist",
			Education:    "Bahir Dar University",
			Religion:     "Orthodox",
			Bio:          "Nature enthusiast, Lake Tana admirer, bird watching and peaceful sunsets. Let's explore together.",
			PhotoURL:     "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=800",
			Blurhash:     "L9AB|G9Z00~q~q00%M%M?bM{4n%M",
			Interests:    []string{"Hiking", "Travel", "Photography"},
		},
		{
			Phone:        "+251911000016",
			Name:         "Samrawit",
			Gender:       "woman",
			InterestedIn: []string{"man", "men", "everyone"},
			Age:          24,
			City:         "Addis Ababa (CMC)",
			Region:       "Addis Ababa",
			Lat:          9.0230,
			Lng:          38.8250,
			JobTitle:     "Graphic Designer",
			Education:    "Alle School of Fine Arts",
			Religion:     "Orthodox",
			Bio:          "Creative soul passionate about Ethiopian typography, vibrant colors, and good jazz vibes.",
			PhotoURL:     "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=800",
			Blurhash:     "L8E_O$00_3~q0000-;IU-;IU~qIU",
			Interests:    []string{"Art", "Music", "Coffee"},
		},
		{
			Phone:        "+251911000021",
			Name:         "Yohannes",
			Gender:       "man",
			InterestedIn: []string{"woman", "women", "everyone"},
			Age:          27,
			City:         "Addis Ababa (Kazanchis)",
			Region:       "Addis Ababa",
			Lat:          9.0180,
			Lng:          38.7660,
			JobTitle:     "Tech Lead",
			Education:    "AAU Science Campus",
			Religion:     "Orthodox",
			Bio:          "Software engineer & jazz pianist. Weekend morning runner around Entoto. Looking for someone with good energy.",
			PhotoURL:     "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800",
			Blurhash:     "LEHV6nWB2yk8pyo0adR*.7kCMdnj",
			Interests:    []string{"Football", "Music", "Hiking"},
		},
		{
			Phone:        "+251911000022",
			Name:         "Dawit",
			Gender:       "man",
			InterestedIn: []string{"woman", "women", "everyone"},
			Age:          29,
			City:         "Addis Ababa (CMC)",
			Region:       "Addis Ababa",
			Lat:          9.0250,
			Lng:          38.8200,
			JobTitle:     "Senior Analyst",
			Education:    "Unity University",
			Religion:     "Orthodox",
			Bio:          "Financial analyst & amateur photographer. Passionate about Ethiopian history, museums, and exploring new cafes.",
			PhotoURL:     "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=800",
			Blurhash:     "L69P:x%200%M00~q00~q00%M%M00",
			Interests:    []string{"Photography", "Reading", "Coffee"},
		},
		{
			Phone:        "+251911000023",
			Name:         "Henok",
			Gender:       "man",
			InterestedIn: []string{"woman", "women", "everyone"},
			Age:          28,
			City:         "Addis Ababa (Piazza)",
			Region:       "Addis Ababa",
			Lat:          9.0350,
			Lng:          38.7510,
			JobTitle:     "Civil Engineer",
			Education:    "AAU Technology Campus",
			Religion:     "Orthodox",
			Bio:          "Building roads and bridges across the country. Big fan of traditional food, cycling, and family gatherings.",
			PhotoURL:     "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800",
			Blurhash:     "L28qf000-;~q0000_3_3-;~q_3_3",
			Interests:    []string{"Sports", "Travel", "Cooking"},
		},
		{
			Phone:        "+251911000024",
			Name:         "Natnael",
			Gender:       "man",
			InterestedIn: []string{"woman", "women", "everyone"},
			Age:          26,
			City:         "Hawassa",
			Region:       "Sidama",
			Lat:          7.0580,
			Lng:          38.4800,
			JobTitle:     "Hospitality Manager",
			Education:    "Hawassa University",
			Religion:     "Protestant",
			Bio:          "Resort manager by the lake. Passionate about tourism, good hospitality, and live acoustic music.",
			PhotoURL:     "https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=800",
			Blurhash:     "L8B:sV?b009F~qM{00IU~q%M00%M",
			Interests:    []string{"Music", "Travel", "Dancing"},
		},
		{
			Phone:        "+251911000031",
			Name:         "Liya",
			Gender:       "woman",
			InterestedIn: []string{"man", "men", "everyone"},
			Age:          23,
			City:         "Addis Ababa (Bole)",
			Region:       "Addis Ababa",
			Lat:          9.0020,
			Lng:          38.7830,
			JobTitle:     "Medical Doctor Intern",
			Education:    "Tikur Anbessa Hospital",
			Religion:     "Orthodox",
			Bio:          "Doctor in training with a love for literature, good tea, and peaceful walks in the botanical garden.",
			PhotoURL:     "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=800",
			Blurhash:     "L7G9r-00~q-;00M{?b%M~q%M%M_3",
			Interests:    []string{"Reading", "Coffee", "Yoga"},
		},
		{
			Phone:        "+251911000032",
			Name:         "Mahlet",
			Gender:       "woman",
			InterestedIn: []string{"man", "men", "everyone"},
			Age:          26,
			City:         "Addis Ababa (Kazanchis)",
			Region:       "Addis Ababa",
			Lat:          9.0160,
			Lng:          38.7670,
			JobTitle:     "Brand & Marketing Lead",
			Education:    "St. Mary's University",
			Religion:     "Orthodox",
			Bio:          "Storyteller and coffee enthusiast. Always exploring new viewpoints, art exhibitions, and culinary spots.",
			PhotoURL:     "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=800",
			Blurhash:     "L6PZfSi_.AyE_3t7t7R**0o#DgR4",
			Interests:    []string{"Art", "Cooking", "Photography"},
		},
		{
			Phone:        "+251911000033",
			Name:         "Eden",
			Gender:       "woman",
			InterestedIn: []string{"man", "men", "everyone"},
			Age:          24,
			City:         "Addis Ababa (Gerji)",
			Region:       "Addis Ababa",
			Lat:          9.0080,
			Lng:          38.8020,
			JobTitle:     "Product Designer",
			Education:    "Addis Ababa University",
			Religion:     "Protestant",
			Bio:          "Design enthusiast creating sleek user experiences. Weekend hiker and plant mom. Let's talk design & faith.",
			PhotoURL:     "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=800",
			Blurhash:     "LDF~G2~q000000-;~q00-;00~q00",
			Interests:    []string{"Hiking", "Design", "Nature"},
		},
		{
			Phone:        "+251911000034",
			Name:         "Meron",
			Gender:       "woman",
			InterestedIn: []string{"man", "men", "everyone"},
			Age:          25,
			City:         "Addis Ababa (Sarbet)",
			Region:       "Addis Ababa",
			Lat:          8.9950,
			Lng:          38.7450,
			JobTitle:     "Specialty Cafe Founder",
			Education:    "Hawassa University",
			Religion:     "Orthodox",
			Bio:          "Obsessed with single-origin beans, acoustic Ethiopian melodies, and warm conversations that last for hours.",
			PhotoURL:     "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800",
			Blurhash:     "L8E_O$00_3~q0000-;IU-;IU~qIU",
			Interests:    []string{"Coffee", "Music", "Travel"},
		},
		{
			Phone:        "+251911000035",
			Name:         "Hermela",
			Gender:       "woman",
			InterestedIn: []string{"man", "men", "everyone"},
			Age:          22,
			City:         "Addis Ababa (Piazza)",
			Region:       "Addis Ababa",
			Lat:          9.0340,
			Lng:          38.7520,
			JobTitle:     "Law Student",
			Education:    "Addis Ababa University",
			Religion:     "Orthodox",
			Bio:          "Future attorney passionate about human rights, vintage film cameras, and historic Addis architecture.",
			PhotoURL:     "https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?w=800",
			Blurhash:     "L28qf000-;~q0000_3_3-;~q_3_3",
			Interests:    []string{"Reading", "Photography", "Debate"},
		},
	}

	log.Printf("Seeding %d discoverable candidate profiles into Fikir database...", len(candidates))

	for _, c := range candidates {
		birthdate := time.Now().AddDate(-c.Age, -2, -10)

		// 1. Upsert user
		var userID uuid.UUID
		err := dbPool.QueryRow(ctx, `
			INSERT INTO users (phone_e164, status, locale, last_active_at)
			VALUES ($1, 'active', 'am', NOW())
			ON CONFLICT (phone_e164) DO UPDATE SET status = 'active', last_active_at = NOW()
			RETURNING id
		`, c.Phone).Scan(&userID)
		if err != nil {
			log.Printf("Failed to upsert user %s (%s): %v", c.Name, c.Phone, err)
			continue
		}

		// 2. Upsert profile
		_, err = dbPool.Exec(ctx, `
			INSERT INTO profiles (
				user_id, display_name, birthdate, gender, interested_in,
				bio, job_title, education, religion, city, region,
				geog, show_me, distance_pref_km, age_min, age_max,
				verified, completeness_score, updated_at
			) VALUES (
				$1, $2, $3, $4, $5,
				$6, $7, $8, $9, $10, $11,
				ST_SetSRID(ST_MakePoint($12, $13), 4326)::geography, TRUE, 100, 18, 50,
				TRUE, 95, NOW()
			)
			ON CONFLICT (user_id) DO UPDATE SET
				display_name = EXCLUDED.display_name,
				gender = EXCLUDED.gender,
				interested_in = EXCLUDED.interested_in,
				bio = EXCLUDED.bio,
				job_title = EXCLUDED.job_title,
				education = EXCLUDED.education,
				religion = EXCLUDED.religion,
				city = EXCLUDED.city,
				region = EXCLUDED.region,
				geog = EXCLUDED.geog,
				show_me = TRUE,
				verified = TRUE,
				completeness_score = 95,
				updated_at = NOW()
		`,
			userID, c.Name, birthdate, c.Gender, c.InterestedIn,
			c.Bio, c.JobTitle, c.Education, c.Religion, c.City, c.Region,
			c.Lng, c.Lat,
		)
		if err != nil {
			log.Printf("Failed to upsert profile for %s: %v", c.Name, err)
			continue
		}

		// 3. Upsert approved photo
		variantsJSON, _ := json.Marshal(map[string]any{
			"card": map[string]any{
				"webp": map[string]any{
					"path": c.PhotoURL,
				},
				"jpeg": map[string]any{
					"path": c.PhotoURL,
				},
			},
			"full": map[string]any{
				"webp": map[string]any{
					"path": c.PhotoURL,
				},
			},
		})

		_, err = dbPool.Exec(ctx, `
			INSERT INTO profile_photos (
				user_id, position, blurhash, width, height, variants, status
			) VALUES (
				$1, 0, $2, 800, 1000, $3::jsonb, 'approved'
			)
			ON CONFLICT (user_id, position) DO UPDATE SET
				variants = EXCLUDED.variants,
				blurhash = EXCLUDED.blurhash,
				status = 'approved'
		`, userID, c.Blurhash, string(variantsJSON))
		if err != nil {
			log.Printf("Failed to upsert photo for %s: %v", c.Name, err)
		}

		// 4. Link interests
		for _, interestName := range c.Interests {
			var interestID int
			err := dbPool.QueryRow(ctx, "SELECT id FROM interests WHERE name = $1 LIMIT 1", interestName).Scan(&interestID)
			if err == nil {
				_, _ = dbPool.Exec(ctx, `
					INSERT INTO user_interests (user_id, interest_id)
					VALUES ($1, $2)
					ON CONFLICT DO NOTHING
				`, userID, interestID)
			}
		}

		log.Printf("✓ Seeded candidate: %s (%s, %s, %s)", c.Name, c.Gender, c.City, c.Phone)
	}

	// Invalidate discovery decks in Redis so new candidates are immediately discoverable
	keys, err := rdb.Keys(ctx, "discovery:deck:*").Result()
	if err == nil && len(keys) > 0 {
		rdb.Del(ctx, keys...)
		log.Printf("Cleared %d cached discovery decks in Redis.", len(keys))
	}

	log.Println("Seeding complete! Discovery candidate pool is ready.")
}
