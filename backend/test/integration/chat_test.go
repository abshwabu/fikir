package integration_test

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"nhooyr.io/websocket"

	"github.com/abshwabu/fikir/backend/internal/cache"
	"github.com/abshwabu/fikir/backend/internal/config"
	"github.com/abshwabu/fikir/backend/internal/domain"
	apphttp "github.com/abshwabu/fikir/backend/internal/http"
	"github.com/abshwabu/fikir/backend/internal/platform/logger"
	"github.com/abshwabu/fikir/backend/internal/platform/safety"
	"github.com/abshwabu/fikir/backend/internal/platform/token"
	"github.com/abshwabu/fikir/backend/internal/repository"
	"github.com/abshwabu/fikir/backend/internal/service"
	"github.com/abshwabu/fikir/backend/internal/storage"
	"github.com/abshwabu/fikir/backend/internal/ws"
	"github.com/abshwabu/fikir/backend/test/integration"
)

func TestChatAndRealtime_IntegrationSuite(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping chat integration test in short mode")
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
		Chat: config.ChatConfig{
			MaxMessageLength:  1000,
			RateLimitMessages: 30,
			RateLimitWindow:   time.Minute,
		},
	}

	log := logger.New("test", "error")
	queries := repository.New(harness.DB)
	userRepo := repository.NewUserRepository(queries)
	authRepo := repository.NewAuthRepository(queries)
	tokenMgr, err := token.NewManager(cfg.JWT, authRepo)
	require.NoError(t, err)

	matchRepo := repository.NewMatchRepository(queries, harness.DB, nil)
	blockRepo := repository.NewBlockRepository(queries)
	profileRepo := repository.NewProfileRepository(queries)
	chatRepo := repository.NewChatRepository(queries)
	deviceRepo := repository.NewDeviceRepository(queries)
	notifRepo := repository.NewNotificationRepository(queries)
	chatCache := cache.NewChatCache(harness.Redis)

	// Create 2 test users
	userA := &domain.User{PhoneE164: "+251911111111", Status: domain.UserStatusActive, Locale: "en"}
	require.NoError(t, userRepo.Create(ctx, userA))
	userB := &domain.User{PhoneE164: "+251922222222", Status: domain.UserStatusActive, Locale: "am"}
	require.NoError(t, userRepo.Create(ctx, userB))

	// Create match between userA and userB
	match, err := matchRepo.CreateMatch(ctx, userA.ID, userB.ID)
	require.NoError(t, err)
	require.NotNil(t, match)

	// Spin up Node 1 (Hub 1) and Node 2 (Hub 2) connected to the same Redis
	hub1 := ws.NewHub("node-1", harness.Redis, chatCache)
	hub1.Start(ctx)
	defer hub1.Stop()

	hub2 := ws.NewHub("node-2", harness.Redis, chatCache)
	hub2.Start(ctx)
	defer hub2.Stop()

	storageClient, _ := storage.New(config.MinIOConfig{
		Endpoint:       "minio:9000",
		RootUser:       "minioadmin",
		RootPassword:   "miniopassword",
		BucketOriginal: "fikir-media-original",
		BucketPublic:   "fikir-media-public",
	})

	chatSvc1 := service.NewChatService(
		cfg.Chat,
		"http://localhost/media",
		chatRepo,
		blockRepo,
		profileRepo,
		deviceRepo,
		notifRepo,
		chatCache,
		storageClient,
		nil,
		harness.Redis,
		safety.NewSafetyAnalyzer(),
	)

	chatSvc2 := service.NewChatService(
		cfg.Chat,
		"http://localhost/media",
		chatRepo,
		blockRepo,
		profileRepo,
		deviceRepo,
		notifRepo,
		chatCache,
		storageClient,
		nil,
		harness.Redis,
		safety.NewSafetyAnalyzer(),
	)

	router1 := apphttp.NewRouter(apphttp.ServerDependencies{
		Config:      cfg,
		Logger:      log,
		DB:          harness.DB,
		Redis:       harness.Redis,
		TokenMgr:    tokenMgr,
		UserRepo:    userRepo,
		ChatRepo:    chatRepo,
		DeviceRepo:  deviceRepo,
		NotifRepo:   notifRepo,
		ChatCache:   chatCache,
		Hub:         hub1,
		ChatService: chatSvc1,
	})

	router2 := apphttp.NewRouter(apphttp.ServerDependencies{
		Config:      cfg,
		Logger:      log,
		DB:          harness.DB,
		Redis:       harness.Redis,
		TokenMgr:    tokenMgr,
		UserRepo:    userRepo,
		ChatRepo:    chatRepo,
		DeviceRepo:  deviceRepo,
		NotifRepo:   notifRepo,
		ChatCache:   chatCache,
		Hub:         hub2,
		ChatService: chatSvc2,
	})

	server1 := httptest.NewServer(router1)
	defer server1.Close()

	server2 := httptest.NewServer(router2)
	defer server2.Close()

	// Generate access tokens for users
	tokA, err := tokenMgr.GenerateAccessToken(userA.ID, "phone")
	require.NoError(t, err)
	tokB, err := tokenMgr.GenerateAccessToken(userB.ID, "phone")
	require.NoError(t, err)

	t.Run("Multi-node fanout via Redis Pub/Sub", func(t *testing.T) {
		// 1. Get WS ticket for User A on Server 1
		reqA, err := http.NewRequestWithContext(ctx, "POST", server1.URL+"/v1/ws-ticket", nil)
		require.NoError(t, err)
		reqA.Header.Set("Authorization", "Bearer "+tokA)
		respA, err := http.DefaultClient.Do(reqA)
		require.NoError(t, err)
		defer respA.Body.Close()
		require.Equal(t, http.StatusOK, respA.StatusCode)

		var ticketResA struct {
			Ticket string `json:"ticket"`
		}
		require.NoError(t, json.NewDecoder(respA.Body).Decode(&ticketResA))
		require.NotEmpty(t, ticketResA.Ticket)

		// 2. Get WS ticket for User B on Server 2
		reqB, err := http.NewRequestWithContext(ctx, "POST", server2.URL+"/v1/ws-ticket", nil)
		require.NoError(t, err)
		reqB.Header.Set("Authorization", "Bearer "+tokB)
		respB, err := http.DefaultClient.Do(reqB)
		require.NoError(t, err)
		defer respB.Body.Close()
		require.Equal(t, http.StatusOK, respB.StatusCode)

		var ticketResB struct {
			Ticket string `json:"ticket"`
		}
		require.NoError(t, json.NewDecoder(respB.Body).Decode(&ticketResB))
		require.NotEmpty(t, ticketResB.Ticket)

		// 3. Connect User A to Server 1 WebSocket
		wsURL1 := "ws" + strings.TrimPrefix(server1.URL, "http") + "/ws?ticket=" + ticketResA.Ticket
		wsConn1, _, err := websocket.Dial(ctx, wsURL1, nil)
		require.NoError(t, err)
		defer wsConn1.Close(websocket.StatusNormalClosure, "")

		// 4. Connect User B to Server 2 WebSocket
		wsURL2 := "ws" + strings.TrimPrefix(server2.URL, "http") + "/ws?ticket=" + ticketResB.Ticket
		wsConn2, _, err := websocket.Dial(ctx, wsURL2, nil)
		require.NoError(t, err)
		defer wsConn2.Close(websocket.StatusNormalClosure, "")

		// Allow connection registration
		time.Sleep(100 * time.Millisecond)

		// 5. User A sends message via WebSocket on Node 1
		sendFrame := domain.WSFrame{
			Type:        domain.FrameTypeMessageSend,
			MatchID:     &match.ID,
			ClientMsgID: "multi-node-msg-01",
			Body:        "Selam Helen! Endet nesh?",
			MsgType:     domain.MessageTypeText,
		}
		frameBytes, err := json.Marshal(sendFrame)
		require.NoError(t, err)

		err = wsConn1.Write(ctx, websocket.MessageText, frameBytes)
		require.NoError(t, err)

		// 6. User A should receive message.ack on Node 1
		_, ackBytes, err := wsConn1.Read(ctx)
		require.NoError(t, err)

		var ackFrame domain.WSFrame
		require.NoError(t, json.Unmarshal(ackBytes, &ackFrame))
		assert.Equal(t, domain.FrameTypeMessageAck, ackFrame.Type)
		assert.Equal(t, "multi-node-msg-01", ackFrame.ClientMsgID)
		assert.Equal(t, "sent", ackFrame.Status)
		assert.True(t, ackFrame.MessageID > 0)

		// 7. User B connected on Node 2 should receive message.new via Redis Pub/Sub!
		readCtx, readCancel := context.WithTimeout(ctx, 3*time.Second)
		defer readCancel()

		_, newBytes, err := wsConn2.Read(readCtx)
		require.NoError(t, err)

		var newFrame domain.WSFrame
		require.NoError(t, json.Unmarshal(newBytes, &newFrame))
		assert.Equal(t, domain.FrameTypeMessageNew, newFrame.Type)
		assert.Equal(t, "Selam Helen! Endet nesh?", newFrame.Body)
		assert.Equal(t, userA.ID, *newFrame.SenderID)
		assert.Equal(t, match.ID, *newFrame.MatchID)
	})

	t.Run("Idempotent deduplication via REST fallback", func(t *testing.T) {
		bodyPayload := map[string]any{
			"body":          "REST fallback message",
			"type":          "text",
			"client_msg_id": "rest-dedupe-id-123",
		}
		jsonBytes, _ := json.Marshal(bodyPayload)

		// First REST send
		req1, err := http.NewRequestWithContext(ctx, "POST", fmt.Sprintf("%s/v1/matches/%s/messages", server1.URL, match.ID), bytes.NewReader(jsonBytes))
		require.NoError(t, err)
		req1.Header.Set("Authorization", "Bearer "+tokA)
		req1.Header.Set("Content-Type", "application/json")
		resp1, err := http.DefaultClient.Do(req1)
		require.NoError(t, err)
		defer resp1.Body.Close()
		require.Equal(t, http.StatusCreated, resp1.StatusCode)

		var msg1 domain.Message
		require.NoError(t, json.NewDecoder(resp1.Body).Decode(&msg1))
		require.True(t, msg1.ID > 0)

		// Second REST send with same client_msg_id
		req2, err := http.NewRequestWithContext(ctx, "POST", fmt.Sprintf("%s/v1/matches/%s/messages", server1.URL, match.ID), bytes.NewReader(jsonBytes))
		require.NoError(t, err)
		req2.Header.Set("Authorization", "Bearer "+tokA)
		req2.Header.Set("Content-Type", "application/json")
		resp2, err := http.DefaultClient.Do(req2)
		require.NoError(t, err)
		defer resp2.Body.Close()
		require.Equal(t, http.StatusCreated, resp2.StatusCode)

		var msg2 domain.Message
		require.NoError(t, json.NewDecoder(resp2.Body).Decode(&msg2))
		// Must return same message ID
		assert.Equal(t, msg1.ID, msg2.ID)
	})

	t.Run("Replay messages with after_id parameter", func(t *testing.T) {
		req, err := http.NewRequestWithContext(ctx, "GET", fmt.Sprintf("%s/v1/matches/%s/messages?after_id=0", server1.URL, match.ID), nil)
		require.NoError(t, err)
		req.Header.Set("Authorization", "Bearer "+tokB)
		resp, err := http.DefaultClient.Do(req)
		require.NoError(t, err)
		defer resp.Body.Close()
		require.Equal(t, http.StatusOK, resp.StatusCode)

		var listRes struct {
			Messages []domain.Message `json:"messages"`
			Count    int              `json:"count"`
		}
		require.NoError(t, json.NewDecoder(resp.Body).Decode(&listRes))
		assert.GreaterOrEqual(t, listRes.Count, 2)

		var maxID int64
		for _, m := range listRes.Messages {
			if m.ID > maxID {
				maxID = m.ID
			}
		}

		// Replay after maxID should return 0 messages
		reqReplay, err := http.NewRequestWithContext(ctx, "GET", fmt.Sprintf("%s/v1/matches/%s/messages?after_id=%d", server1.URL, match.ID, maxID), nil)
		require.NoError(t, err)
		reqReplay.Header.Set("Authorization", "Bearer "+tokB)
		respReplay, err := http.DefaultClient.Do(reqReplay)
		require.NoError(t, err)
		defer respReplay.Body.Close()

		var emptyList struct {
			Messages []domain.Message `json:"messages"`
			Count    int              `json:"count"`
		}
		require.NoError(t, json.NewDecoder(respReplay.Body).Decode(&emptyList))
		assert.Equal(t, 0, emptyList.Count)
	})
}
