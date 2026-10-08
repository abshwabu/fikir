package service

import (
	"context"
	"sync"
	"testing"
	"time"

	"github.com/alicebob/miniredis/v2"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/abshwabu/fikir/backend/internal/config"
	"github.com/abshwabu/fikir/backend/internal/domain"
	"github.com/abshwabu/fikir/backend/internal/platform/safety"
)

type mockChatRepo struct {
	mu           sync.RWMutex
	messages     map[int64]*domain.Message
	byClientMsg  map[string]*domain.Message
	participants map[uuid.UUID][2]uuid.UUID
	unmatched    map[uuid.UUID]bool
	nextID       int64
}

func newMockChatRepo() *mockChatRepo {
	return &mockChatRepo{
		messages:     make(map[int64]*domain.Message),
		byClientMsg:  make(map[string]*domain.Message),
		participants: make(map[uuid.UUID][2]uuid.UUID),
		unmatched:    make(map[uuid.UUID]bool),
		nextID:       1,
	}
}

func (m *mockChatRepo) CreateMessage(ctx context.Context, msg *domain.Message) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	msg.ID = m.nextID
	m.nextID++
	m.messages[msg.ID] = msg
	if msg.ClientMsgID != "" {
		m.byClientMsg[msg.ClientMsgID] = msg
	}
	return nil
}

func (m *mockChatRepo) GetMessageByID(ctx context.Context, id int64) (*domain.Message, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.messages[id], nil
}

func (m *mockChatRepo) GetMessageByClientMsgID(ctx context.Context, matchID uuid.UUID, clientMsgID string) (*domain.Message, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.byClientMsg[clientMsgID], nil
}

func (m *mockChatRepo) ListMessagesAfter(ctx context.Context, matchID uuid.UUID, afterID int64, limit int) ([]domain.Message, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	var res []domain.Message
	for _, msg := range m.messages {
		if msg.MatchID == matchID && msg.ID > afterID {
			res = append(res, *msg)
		}
	}
	return res, nil
}

func (m *mockChatRepo) ListMessagesBefore(ctx context.Context, matchID uuid.UUID, beforeID int64, limit int) ([]domain.Message, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	var res []domain.Message
	for _, msg := range m.messages {
		if msg.MatchID == matchID && (beforeID == 0 || msg.ID < beforeID) {
			res = append(res, *msg)
		}
	}
	return res, nil
}

func (m *mockChatRepo) MarkMessagesAsRead(ctx context.Context, matchID uuid.UUID, readerID uuid.UUID, upToID int64) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	now := time.Now()
	for _, msg := range m.messages {
		if msg.MatchID == matchID && msg.SenderID != readerID && (upToID == 0 || msg.ID <= upToID) {
			msg.ReadAt = &now
		}
	}
	return nil
}

func (m *mockChatRepo) UpdateMatchLastMessageAt(ctx context.Context, matchID uuid.UUID, t time.Time) error {
	return nil
}

func (m *mockChatRepo) GetMatchParticipants(ctx context.Context, matchID uuid.UUID) (uuid.UUID, uuid.UUID, *time.Time, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	pair, ok := m.participants[matchID]
	if !ok {
		return uuid.Nil, uuid.Nil, nil, nil
	}
	var un *time.Time
	if m.unmatched[matchID] {
		t := time.Now()
		un = &t
	}
	return pair[0], pair[1], un, nil
}

type mockChatCache struct {
	rateAllowed bool
	dedupes     map[string]bool
	onlineUsers map[uuid.UUID]bool
	unreadCount map[string]int64
	mu          sync.Mutex
}

func newMockChatCache() *mockChatCache {
	return &mockChatCache{
		rateAllowed: true,
		dedupes:     make(map[string]bool),
		onlineUsers: make(map[uuid.UUID]bool),
		unreadCount: make(map[string]int64),
	}
}

func (c *mockChatCache) CreateWSTicket(ctx context.Context, userID uuid.UUID) (string, error) {
	return "test-ticket", nil
}

func (c *mockChatCache) ConsumeWSTicket(ctx context.Context, ticket string) (uuid.UUID, error) {
	return uuid.New(), nil
}

func (c *mockChatCache) CheckAndSetDedupe(ctx context.Context, userID uuid.UUID, clientMsgID string) (bool, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.dedupes[clientMsgID] {
		return false, nil // duplicate
	}
	c.dedupes[clientMsgID] = true
	return true, nil
}

func (c *mockChatCache) IncrUnread(ctx context.Context, userID, matchID uuid.UUID) (int64, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	k := userID.String() + ":" + matchID.String()
	c.unreadCount[k]++
	return c.unreadCount[k], nil
}

func (c *mockChatCache) ResetUnread(ctx context.Context, userID, matchID uuid.UUID) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	k := userID.String() + ":" + matchID.String()
	c.unreadCount[k] = 0
	return nil
}

func (c *mockChatCache) GetUnread(ctx context.Context, userID, matchID uuid.UUID) (int64, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	k := userID.String() + ":" + matchID.String()
	return c.unreadCount[k], nil
}

func (c *mockChatCache) RegisterPresence(ctx context.Context, userID uuid.UUID, nodeID string) error {
	c.onlineUsers[userID] = true
	return nil
}

func (c *mockChatCache) UnregisterPresence(ctx context.Context, userID uuid.UUID, nodeID string) error {
	delete(c.onlineUsers, userID)
	return nil
}

func (c *mockChatCache) IsUserOnline(ctx context.Context, userID uuid.UUID) (bool, error) {
	return c.onlineUsers[userID], nil
}

func (c *mockChatCache) CheckChatRateLimit(ctx context.Context, userID uuid.UUID, limit int, window time.Duration) (bool, error) {
	return c.rateAllowed, nil
}

type mockNotifRepo struct {
	settings map[uuid.UUID]*domain.NotificationSettings
}

func (n *mockNotifRepo) GetUserNotificationSettings(ctx context.Context, userID uuid.UUID) (*domain.NotificationSettings, string, error) {
	if s, ok := n.settings[userID]; ok {
		return s, "am", nil
	}
	def := domain.DefaultNotificationSettings()
	return &def, "en", nil
}

func (n *mockNotifRepo) UpdateUserNotificationSettings(ctx context.Context, userID uuid.UUID, settings *domain.NotificationSettings) error {
	n.settings[userID] = settings
	return nil
}

type mockDeviceRepo struct {
	devices map[uuid.UUID][]domain.Device
}

func (d *mockDeviceRepo) UpsertDevice(ctx context.Context, userID uuid.UUID, fcmToken, platform string) error {
	d.devices[userID] = append(d.devices[userID], domain.Device{
		UserID:   userID,
		FCMToken: fcmToken,
		Platform: platform,
	})
	return nil
}

func (d *mockDeviceRepo) DeleteDevice(ctx context.Context, userID uuid.UUID, fcmToken string) error {
	delete(d.devices, userID)
	return nil
}

func (d *mockDeviceRepo) GetActiveDevicesForUser(ctx context.Context, userID uuid.UUID) ([]domain.Device, error) {
	return d.devices[userID], nil
}

type mockChatBlockRepo struct {
	blockedPairs map[string]bool
}

func (m *mockChatBlockRepo) CreateBlock(ctx context.Context, blockerID, blockedID uuid.UUID) error {
	m.blockedPairs[blockerID.String()+":"+blockedID.String()] = true
	return nil
}

func (m *mockChatBlockRepo) IsBlocked(ctx context.Context, userA, userB uuid.UUID) (bool, error) {
	return m.blockedPairs[userA.String()+":"+userB.String()], nil
}

type mockChatProfileRepo struct {
	profiles map[uuid.UUID]*domain.Profile
}

func (m *mockChatProfileRepo) GetByUserID(ctx context.Context, userID uuid.UUID) (*domain.Profile, error) {
	return m.profiles[userID], nil
}

func (m *mockChatProfileRepo) Upsert(ctx context.Context, profile *domain.Profile) error { return nil }
func (m *mockChatProfileRepo) UpdateInterests(ctx context.Context, userID uuid.UUID, interests []string) error { return nil }
func (m *mockChatProfileRepo) UpdateLocation(ctx context.Context, userID uuid.UUID, lat, lng float64, city, region string) error { return nil }
func (m *mockChatProfileRepo) GetPhotos(ctx context.Context, userID uuid.UUID) ([]domain.ProfilePhoto, error) { return nil, nil }
func (m *mockChatProfileRepo) GetPhotoByID(ctx context.Context, id uuid.UUID) (*domain.ProfilePhoto, error) { return nil, nil }
func (m *mockChatProfileRepo) CreatePhoto(ctx context.Context, photo *domain.ProfilePhoto) error { return nil }
func (m *mockChatProfileRepo) UpdatePhoto(ctx context.Context, photo *domain.ProfilePhoto) error { return nil }
func (m *mockChatProfileRepo) DeletePhoto(ctx context.Context, photoID, userID uuid.UUID) error { return nil }
func (m *mockChatProfileRepo) CountPhotos(ctx context.Context, userID uuid.UUID) (int, error) { return 0, nil }
func (m *mockChatProfileRepo) ReorderPhotos(ctx context.Context, userID uuid.UUID, photoIDs []uuid.UUID) error { return nil }
func (m *mockChatProfileRepo) GetUserInterests(ctx context.Context, userID uuid.UUID) ([]string, error) { return nil, nil }
func (m *mockChatProfileRepo) CreateVerification(ctx context.Context, v *domain.Verification) error { return nil }

func TestChatService_SendMessage(t *testing.T) {
	ctx := context.Background()
	mr, err := miniredis.Run()
	require.NoError(t, err)
	defer mr.Close()

	rdb := redis.NewClient(&redis.Options{Addr: mr.Addr()})

	userA := uuid.New()
	userB := uuid.New()
	matchID := uuid.New()

	chatRepo := newMockChatRepo()
	chatRepo.participants[matchID] = [2]uuid.UUID{userA, userB}

	blockRepo := &mockChatBlockRepo{blockedPairs: make(map[string]bool)}
	profileRepo := &mockChatProfileRepo{profiles: map[uuid.UUID]*domain.Profile{
		userA: {UserID: userA, DisplayName: "Dawit"},
		userB: {UserID: userB, DisplayName: "Helen"},
	}}
	deviceRepo := &mockDeviceRepo{devices: make(map[uuid.UUID][]domain.Device)}
	notifRepo := &mockNotifRepo{settings: make(map[uuid.UUID]*domain.NotificationSettings)}
	chatCache := newMockChatCache()
	analyzer := safety.NewSafetyAnalyzer()

	chatSvc := NewChatService(
		config.ChatConfig{MaxMessageLength: 1000, RateLimitMessages: 30, RateLimitWindow: time.Minute},
		"http://cdn.test",
		chatRepo,
		blockRepo,
		profileRepo,
		deviceRepo,
		notifRepo,
		chatCache,
		nil,
		nil,
		rdb,
		analyzer,
	)

	t.Run("Successfully sends message and flags safety warnings", func(t *testing.T) {
		msg, err := chatSvc.SendMessage(ctx, SendMessageRequest{
			MatchID:     matchID,
			SenderID:    userA,
			Body:        "Hey check this link https://fikir.et or call 0911223344",
			ClientMsgID: "client-msg-1",
		})
		require.NoError(t, err)
		assert.Equal(t, int64(1), msg.ID)
		assert.Contains(t, msg.WarningFlags, safety.FlagHasLink)
		assert.Contains(t, msg.WarningFlags, safety.FlagHasPhoneNumber)

		// Verify unread count incremented for recipient UserB
		unread, _ := chatCache.GetUnread(ctx, userB, matchID)
		assert.Equal(t, int64(1), unread)
	})

	t.Run("Idempotent deduplication returns existing message", func(t *testing.T) {
		// Sending exact same client_msg_id
		dupMsg, err := chatSvc.SendMessage(ctx, SendMessageRequest{
			MatchID:     matchID,
			SenderID:    userA,
			Body:        "Hey duplicate send",
			ClientMsgID: "client-msg-1",
		})
		require.NoError(t, err)
		assert.Equal(t, int64(1), dupMsg.ID)
	})

	t.Run("Rate limit exceeded rejects send", func(t *testing.T) {
		chatCache.rateAllowed = false
		defer func() { chatCache.rateAllowed = true }()

		_, err := chatSvc.SendMessage(ctx, SendMessageRequest{
			MatchID:     matchID,
			SenderID:    userA,
			Body:        "Too fast!",
			ClientMsgID: "msg-rate-limit",
		})
		require.Error(t, err)
		assert.Contains(t, err.Error(), "chat rate limit exceeded")
	})

	t.Run("Blocked user cannot send message", func(t *testing.T) {
		blockRepo.blockedPairs[userA.String()+":"+userB.String()] = true
		defer func() { delete(blockRepo.blockedPairs, userA.String()+":"+userB.String()) }()

		_, err := chatSvc.SendMessage(ctx, SendMessageRequest{
			MatchID:     matchID,
			SenderID:    userA,
			Body:        "Blocked hello",
			ClientMsgID: "blocked-msg",
		})
		require.Error(t, err)
		assert.Contains(t, err.Error(), "blocked")
	})

	t.Run("Replay messages after ID", func(t *testing.T) {
		msgs, err := chatSvc.GetMessages(ctx, userA, matchID, 0, 0, 10)
		require.NoError(t, err)
		assert.NotEmpty(t, msgs)

		// Replay with after_id = 1 (should find 0 newer messages)
		replay, err := chatSvc.GetMessages(ctx, userA, matchID, 1, 0, 10)
		require.NoError(t, err)
		assert.Empty(t, replay)
	})
}
