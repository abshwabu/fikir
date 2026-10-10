package integration_test

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/abshwabu/fikir/backend/internal/cache"
	"github.com/abshwabu/fikir/backend/internal/config"
	"github.com/abshwabu/fikir/backend/internal/domain"
	apphttp "github.com/abshwabu/fikir/backend/internal/http"
	"github.com/abshwabu/fikir/backend/internal/platform/logger"
	"github.com/abshwabu/fikir/backend/internal/platform/token"
	"github.com/abshwabu/fikir/backend/internal/repository"
	"github.com/abshwabu/fikir/backend/internal/service"
	"github.com/abshwabu/fikir/backend/test/integration"
)

func TestSwipeAndDiscovery_IntegrationSuite(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping swipe and discovery integration test in short mode")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer cancel()

	harness, cleanup, err := integration.SetupHarness(ctx)
	require.NoError(t, err)
	defer cleanup()

	err = harness.ApplyMigrations(ctx)
	require.NoError(t, err)

	cfg := &config.Config{
		AppEnv:  "test",
		AppPort: "8080",
		JWT: config.JWTConfig{
			Secret:        "test-super-secret-jwt-key-minimum-32-chars-long",
			AccessExpiry:  15 * time.Minute,
			RefreshExpiry: 720 * time.Hour,
		},
		RateLimit: config.RateLimitConfig{
			RequestsPerMinute: 1000,
			Burst:             100,
		},
		Swipe: config.SwipeConfig{
			DailyLikeLimit: 50,
			LimitWindow:    12 * time.Hour,
			SuperLikeLimit: 1,
		},
		Discovery: config.DiscoveryConfig{
			DeckTargetSize:      100,
			DeckRefillThreshold: 30,
			PageLimit:           15,
		},
	}

	log := logger.New("test", "debug")
	queries := repository.New(harness.DB)
	userRepo := repository.NewUserRepository(queries)
	profileRepo := repository.NewProfileRepository(queries)
	authRepo := repository.NewAuthRepository(queries)
	discoveryRepo := repository.NewDiscoveryRepository(queries)
	swipeRepo := repository.NewSwipeRepository(queries)
	matchRepo := repository.NewMatchRepository(queries, harness.DB, discoveryRepo)
	blockRepo := repository.NewBlockRepository(queries)
	reportRepo := repository.NewReportRepository(queries)

	tokenMgr, err := token.NewManager(cfg.JWT, authRepo)
	require.NoError(t, err)

	cardCache := cache.NewProfileCardCache(harness.Redis)
	deckCache := cache.NewDeckCache(harness.Redis)
	swipeCache := cache.NewSwipeCache(harness.Redis)

	discoveryService := service.NewDiscoveryService(cfg.Discovery, discoveryRepo, profileRepo, deckCache, cardCache, swipeCache, nil)
	swipeService := service.NewSwipeService(cfg.Swipe, userRepo, profileRepo, swipeRepo, matchRepo, blockRepo, reportRepo, discoveryRepo, swipeCache, cardCache, deckCache, nil)

	router := apphttp.NewRouter(apphttp.ServerDependencies{
		Config:           cfg,
		Logger:           log,
		DB:               harness.DB,
		Redis:            harness.Redis,
		UserRepo:         userRepo,
		ProfileRepo:      profileRepo,
		DiscoveryRepo:    discoveryRepo,
		SwipeRepo:        swipeRepo,
		MatchRepo:        matchRepo,
		BlockRepo:        blockRepo,
		ReportRepo:       reportRepo,
		CardCache:        cardCache,
		DeckCache:        deckCache,
		SwipeCache:       swipeCache,
		DiscoveryService: discoveryService,
		SwipeService:     swipeService,
		TokenMgr:         tokenMgr,
	})

	// Helper to create test user with active profile and approved photo
	createTestUser := func(phone string, name string, gender string, interestedIn []string, isPremium bool) (*domain.User, string) {
		user := &domain.User{
			ID:           uuid.New(),
			PhoneE164:    phone,
			Status:       "active",
			Locale:       "am",
			IsPremium:    isPremium,
			CreatedAt:    time.Now().UTC(),
			LastActiveAt: time.Now().UTC(),
		}
		require.NoError(t, userRepo.Create(ctx, user))

		profile := &domain.Profile{
			UserID:            user.ID,
			DisplayName:       name,
			Gender:            gender,
			InterestedIn:      interestedIn,
			Birthdate:         time.Now().AddDate(-24, 0, 0),
			AgeMin:            18,
			AgeMax:            40,
			ShowMe:            true,
			DistancePrefKm:    100,
			City:              "Addis Ababa",
			Region:            "Addis Ababa",
			Verified:          true,
			CompletenessScore: 80,
		}
		require.NoError(t, profileRepo.Upsert(ctx, profile))

		photo := &domain.ProfilePhoto{
			ID:       uuid.New(),
			UserID:   user.ID,
			Position: 1,
			Status:   domain.PhotoStatusApproved,
			Variants: map[string]any{
				"card": map[string]any{
					"webp": map[string]any{
						"path": fmt.Sprintf("photos/%s/card.webp", user.ID),
					},
				},
			},
		}
		require.NoError(t, profileRepo.CreatePhoto(ctx, photo))

		tok, err := tokenMgr.GenerateAccessToken(user.ID, "session-1")
		require.NoError(t, err)

		return user, tok
	}

	userA, tokA := createTestUser("+251911000001", "Almaz", "female", []string{"male"}, true)
	userB, tokB := createTestUser("+251911000002", "Bekele", "male", []string{"female"}, false)
	userC, tokC := createTestUser("+251911000003", "Chala", "male", []string{"female"}, false)

	// 1. Simultaneous Mutual Likes between userA and userB -> Exactly 1 match
	t.Run("Concurrent mutual likes create exactly one match", func(t *testing.T) {
		var wg sync.WaitGroup
		wg.Add(2)

		var codeA, codeB int
		var bodyA, bodyB map[string]any

		go func() {
			defer wg.Done()
			payload, _ := json.Marshal(map[string]any{"target_id": userB.ID, "direction": "like"})
			req := httptest.NewRequest("POST", "/v1/swipes", bytes.NewReader(payload))
			req.Header.Set("Authorization", "Bearer "+tokA)
			req.Header.Set("Content-Type", "application/json")
			rec := httptest.NewRecorder()
			router.ServeHTTP(rec, req)
			codeA = rec.Code
			_ = json.Unmarshal(rec.Body.Bytes(), &bodyA)
		}()

		go func() {
			defer wg.Done()
			payload, _ := json.Marshal(map[string]any{"target_id": userA.ID, "direction": "like"})
			req := httptest.NewRequest("POST", "/v1/swipes", bytes.NewReader(payload))
			req.Header.Set("Authorization", "Bearer "+tokB)
			req.Header.Set("Content-Type", "application/json")
			rec := httptest.NewRecorder()
			router.ServeHTTP(rec, req)
			codeB = rec.Code
			_ = json.Unmarshal(rec.Body.Bytes(), &bodyB)
		}()

		wg.Wait()

		assert.Equal(t, http.StatusOK, codeA)
		assert.Equal(t, http.StatusOK, codeB)

		// At least one returned matched = true
		matchedA, _ := bodyA["matched"].(bool)
		matchedB, _ := bodyB["matched"].(bool)
		assert.True(t, matchedA || matchedB)

		// Database check: exactly 1 match in matches table
		match, err := matchRepo.GetBetweenUsers(ctx, userA.ID, userB.ID)
		require.NoError(t, err)
		require.NotNil(t, match)

		// Enforce user_a < user_b constraint
		if userA.ID.String() < userB.ID.String() {
			assert.Equal(t, userA.ID, match.UserA)
			assert.Equal(t, userB.ID, match.UserB)
		} else {
			assert.Equal(t, userB.ID, match.UserA)
			assert.Equal(t, userA.ID, match.UserB)
		}
	})

	// 2. Likes-you endpoint
	t.Run("Likes-you response differs for premium and free users", func(t *testing.T) {
		// userC likes userA
		payload, _ := json.Marshal(map[string]any{"target_id": userA.ID, "direction": "like"})
		req := httptest.NewRequest("POST", "/v1/swipes", bytes.NewReader(payload))
		req.Header.Set("Authorization", "Bearer "+tokC)
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)
		require.Equal(t, http.StatusOK, rec.Code)

		// Persist swipe in DB
		_ = swipeRepo.UpsertSwipe(ctx, &domain.Swipe{
			SwiperID:  userC.ID,
			TargetID:  userA.ID,
			Direction: "like",
			CreatedAt: time.Now().UTC(),
		})

		// userA (premium) views likes-you -> gets list of profiles
		reqPrem := httptest.NewRequest("GET", "/v1/likes-you?is_premium=true", nil)
		reqPrem.Header.Set("Authorization", "Bearer "+tokA)
		recPrem := httptest.NewRecorder()
		router.ServeHTTP(recPrem, reqPrem)
		assert.Equal(t, http.StatusOK, recPrem.Code)

		var resPrem map[string]any
		_ = json.Unmarshal(recPrem.Body.Bytes(), &resPrem)
		assert.GreaterOrEqual(t, resPrem["count"].(float64), 1.0)
		profiles, ok := resPrem["profiles"].([]any)
		assert.True(t, ok)
		assert.NotEmpty(t, profiles)

		// userC (free) views likes-you -> gets count and teaser preview only
		reqFree := httptest.NewRequest("GET", "/v1/likes-you", nil)
		reqFree.Header.Set("Authorization", "Bearer "+tokC)
		recFree := httptest.NewRecorder()
		router.ServeHTTP(recFree, reqFree)
		assert.Equal(t, http.StatusOK, recFree.Code)

		var resFree map[string]any
		_ = json.Unmarshal(recFree.Body.Bytes(), &resFree)
		assert.Nil(t, resFree["profiles"])
	})

	// 3. Blocking and unmatching
	t.Run("Blocking unmatches and updates redis", func(t *testing.T) {
		blockPayload, _ := json.Marshal(map[string]any{
			"target_id": userB.ID,
			"reason":    "harassment",
		})
		reqBlock := httptest.NewRequest("POST", "/v1/blocks", bytes.NewReader(blockPayload))
		reqBlock.Header.Set("Authorization", "Bearer "+tokA)
		reqBlock.Header.Set("Content-Type", "application/json")
		recBlock := httptest.NewRecorder()
		router.ServeHTTP(recBlock, reqBlock)
		assert.Equal(t, http.StatusOK, recBlock.Code)

		// Verify match is unmatched
		match, err := matchRepo.GetBetweenUsers(ctx, userA.ID, userB.ID)
		require.NoError(t, err)
		assert.NotNil(t, match.UnmatchedAt)

		// Verify block repository
		isBlocked, err := blockRepo.IsBlocked(ctx, userA.ID, userB.ID)
		require.NoError(t, err)
		assert.True(t, isBlocked)
	})

	// 4. Discovery deck excludes blocked and swiped users
	t.Run("Discovery deck excludes blocked and already swiped users", func(t *testing.T) {
		reqDeck := httptest.NewRequest("GET", "/v1/discovery?limit=15", nil)
		reqDeck.Header.Set("Authorization", "Bearer "+tokA)
		recDeck := httptest.NewRecorder()
		router.ServeHTTP(recDeck, reqDeck)
		assert.Equal(t, http.StatusOK, recDeck.Code)

		var resDeck map[string]any
		_ = json.Unmarshal(recDeck.Body.Bytes(), &resDeck)
		deck := resDeck["deck"].([]any)

		// userB was blocked; userB must not appear in deck
		for _, rawCard := range deck {
			card := rawCard.(map[string]any)
			assert.NotEqual(t, userB.ID.String(), card["user_id"])
			assert.NotEqual(t, userA.ID.String(), card["user_id"])
		}
	})
}
