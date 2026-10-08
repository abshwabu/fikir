package service_test

import (
	"context"
	"fmt"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/abshwabu/fikir/backend/internal/cache"
	"github.com/abshwabu/fikir/backend/internal/config"
	"github.com/abshwabu/fikir/backend/internal/domain"
	apperrors "github.com/abshwabu/fikir/backend/internal/platform/errors"
	"github.com/abshwabu/fikir/backend/internal/service"
)

// In-memory mock repositories and cache for unit testing
type mockUserRepo struct {
	users map[uuid.UUID]*domain.User
}

func (m *mockUserRepo) GetByID(ctx context.Context, id uuid.UUID) (*domain.User, error) {
	return m.users[id], nil
}
func (m *mockUserRepo) GetByPhone(ctx context.Context, phone string) (*domain.User, error) {
	return nil, nil
}
func (m *mockUserRepo) Create(ctx context.Context, user *domain.User) error {
	m.users[user.ID] = user
	return nil
}
func (m *mockUserRepo) UpdateLastActive(ctx context.Context, id uuid.UUID) error { return nil }
func (m *mockUserRepo) SoftDelete(ctx context.Context, id uuid.UUID) error       { return nil }
func (m *mockUserRepo) PurgeDeleted(ctx context.Context, before time.Time) (int64, error) {
	return 0, nil
}

type mockSwipeRepo struct {
	mu     sync.Mutex
	swipes map[string]*domain.Swipe
}

func newMockSwipeRepo() *mockSwipeRepo {
	return &mockSwipeRepo{swipes: make(map[string]*domain.Swipe)}
}

func (m *mockSwipeRepo) UpsertSwipe(ctx context.Context, swipe *domain.Swipe) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	key := fmt.Sprintf("%s:%s", swipe.SwiperID, swipe.TargetID)
	m.swipes[key] = swipe
	return nil
}

func (m *mockSwipeRepo) DeleteSwipe(ctx context.Context, swiperID, targetID uuid.UUID) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.swipes, fmt.Sprintf("%s:%s", swiperID, targetID))
	return nil
}

func (m *mockSwipeRepo) GetSwipe(ctx context.Context, swiperID, targetID uuid.UUID) (*domain.Swipe, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.swipes[fmt.Sprintf("%s:%s", swiperID, targetID)], nil
}

func (m *mockSwipeRepo) CheckMutualLike(ctx context.Context, userA, userB uuid.UUID) (bool, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	s1 := m.swipes[fmt.Sprintf("%s:%s", userA, userB)]
	s2 := m.swipes[fmt.Sprintf("%s:%s", userB, userA)]
	return s1 != nil && s2 != nil && (s1.Direction == "like" || s1.Direction == "super") && (s2.Direction == "like" || s2.Direction == "super"), nil
}

func (m *mockSwipeRepo) GetLikesYouList(ctx context.Context, userID uuid.UUID, limit int) ([]domain.LikesYouItem, error) {
	return nil, nil
}

func (m *mockSwipeRepo) CountLikesYou(ctx context.Context, userID uuid.UUID) (int64, error) {
	return 0, nil
}

type mockMatchRepo struct {
	mu      sync.Mutex
	matches map[string]*domain.Match
}

func newMockMatchRepo() *mockMatchRepo {
	return &mockMatchRepo{matches: make(map[string]*domain.Match)}
}

func (m *mockMatchRepo) CreateMatch(ctx context.Context, userA, userB uuid.UUID) (*domain.Match, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	first, second := userA, userB
	if second.String() < first.String() {
		first, second = second, first
	}

	key := fmt.Sprintf("%s:%s", first, second)
	if match, ok := m.matches[key]; ok {
		match.UnmatchedAt = nil
		return match, nil
	}

	match := &domain.Match{
		ID:        uuid.New(),
		UserA:     first,
		UserB:     second,
		CreatedAt: time.Now().UTC(),
	}
	m.matches[key] = match
	return match, nil
}

func (m *mockMatchRepo) Unmatch(ctx context.Context, matchID, userID uuid.UUID) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	for _, match := range m.matches {
		if match.ID == matchID {
			now := time.Now().UTC()
			match.UnmatchedAt = &now
			return nil
		}
	}
	return nil
}

func (m *mockMatchRepo) GetByID(ctx context.Context, id uuid.UUID) (*domain.Match, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	for _, match := range m.matches {
		if match.ID == id {
			return match, nil
		}
	}
	return nil, nil
}

func (m *mockMatchRepo) GetBetweenUsers(ctx context.Context, userA, userB uuid.UUID) (*domain.Match, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	first, second := userA, userB
	if second.String() < first.String() {
		first, second = second, first
	}
	return m.matches[fmt.Sprintf("%s:%s", first, second)], nil
}

func (m *mockMatchRepo) ListForUser(ctx context.Context, userID uuid.UUID, limit int, cursor *time.Time) ([]domain.MatchWithPreview, *time.Time, error) {
	return nil, nil, nil
}

type mockBlockRepo struct {
	blocks map[string]bool
}

func (m *mockBlockRepo) CreateBlock(ctx context.Context, blockerID, blockedID uuid.UUID) error {
	m.blocks[fmt.Sprintf("%s:%s", blockerID, blockedID)] = true
	return nil
}
func (m *mockBlockRepo) IsBlocked(ctx context.Context, userA, userB uuid.UUID) (bool, error) {
	return m.blocks[fmt.Sprintf("%s:%s", userA, userB)] || m.blocks[fmt.Sprintf("%s:%s", userB, userA)], nil
}

type mockReportRepo struct{}

func (m *mockReportRepo) CreateReport(ctx context.Context, report *domain.Report) error {
	return nil
}

type mockSwipeCache struct {
	mu            sync.Mutex
	swiped        map[string]bool
	likesReceived map[string]bool
	history       map[uuid.UUID][]cache.SwipedHistoryItem
	likeCounts    map[uuid.UUID]int
	superCounts   map[uuid.UUID]int
}

func newMockSwipeCache() *mockSwipeCache {
	return &mockSwipeCache{
		swiped:        make(map[string]bool),
		likesReceived: make(map[string]bool),
		history:       make(map[uuid.UUID][]cache.SwipedHistoryItem),
		likeCounts:    make(map[uuid.UUID]int),
		superCounts:   make(map[uuid.UUID]int),
	}
}

func (m *mockSwipeCache) AddSwiped(ctx context.Context, userID, targetID uuid.UUID) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.swiped[fmt.Sprintf("%s:%s", userID, targetID)] = true
	return nil
}
func (m *mockSwipeCache) IsSwiped(ctx context.Context, userID, targetID uuid.UUID) (bool, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.swiped[fmt.Sprintf("%s:%s", userID, targetID)], nil
}
func (m *mockSwipeCache) GetSwipedIDs(ctx context.Context, userID uuid.UUID) ([]uuid.UUID, error) {
	return nil, nil
}
func (m *mockSwipeCache) RemoveSwiped(ctx context.Context, userID, targetID uuid.UUID) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.swiped, fmt.Sprintf("%s:%s", userID, targetID))
	return nil
}
func (m *mockSwipeCache) AddLikeReceived(ctx context.Context, targetID, fromUserID uuid.UUID) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.likesReceived[fmt.Sprintf("%s:%s", targetID, fromUserID)] = true
	return nil
}
func (m *mockSwipeCache) HasLikeReceived(ctx context.Context, targetID, fromUserID uuid.UUID) (bool, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.likesReceived[fmt.Sprintf("%s:%s", targetID, fromUserID)], nil
}
func (m *mockSwipeCache) RemoveLikeReceived(ctx context.Context, targetID, fromUserID uuid.UUID) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.likesReceived, fmt.Sprintf("%s:%s", targetID, fromUserID))
	return nil
}
func (m *mockSwipeCache) GetLikesReceivedIDs(ctx context.Context, userID uuid.UUID) ([]uuid.UUID, error) {
	return nil, nil
}
func (m *mockSwipeCache) PushSwipeHistory(ctx context.Context, userID uuid.UUID, item cache.SwipedHistoryItem) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.history[userID] = append([]cache.SwipedHistoryItem{item}, m.history[userID]...)
	return nil
}
func (m *mockSwipeCache) PopSwipeHistory(ctx context.Context, userID uuid.UUID) (*cache.SwipedHistoryItem, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	items := m.history[userID]
	if len(items) == 0 {
		return nil, nil
	}
	item := items[0]
	m.history[userID] = items[1:]
	return &item, nil
}
func (m *mockSwipeCache) CheckAndIncrLikeCount(ctx context.Context, userID uuid.UUID, isPremium bool, limit int, window time.Duration) (bool, int, time.Time, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if isPremium {
		return true, 999999, time.Time{}, nil
	}
	m.likeCounts[userID]++
	if m.likeCounts[userID] > limit {
		return false, 0, time.Now().Add(12 * time.Hour), nil
	}
	return true, limit - m.likeCounts[userID], time.Now().Add(12 * time.Hour), nil
}
func (m *mockSwipeCache) CheckAndIncrSuperLike(ctx context.Context, userID uuid.UUID, isPremium bool) (bool, time.Time, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if isPremium {
		return true, time.Time{}, nil
	}
	m.superCounts[userID]++
	if m.superCounts[userID] > 1 {
		return false, time.Now().Add(24 * time.Hour), nil
	}
	return true, time.Now().Add(24 * time.Hour), nil
}

func setupSwipeService() (service.SwipeService, *mockUserRepo, *mockSwipeRepo, *mockMatchRepo, *mockSwipeCache) {
	userRepo := &mockUserRepo{users: make(map[uuid.UUID]*domain.User)}
	swipeRepo := newMockSwipeRepo()
	matchRepo := newMockMatchRepo()
	blockRepo := &mockBlockRepo{blocks: make(map[string]bool)}
	reportRepo := &mockReportRepo{}
	swipeCache := newMockSwipeCache()

	cfg := config.SwipeConfig{
		DailyLikeLimit: 5,
		LimitWindow:    12 * time.Hour,
		SuperLikeLimit: 1,
	}

	svc := service.NewSwipeService(
		cfg,
		userRepo,
		nil, // profileRepo
		swipeRepo,
		matchRepo,
		blockRepo,
		reportRepo,
		nil, // discoveryRepo
		swipeCache,
		nil, // cardCache
		nil, // queueClient
	)

	return svc, userRepo, swipeRepo, matchRepo, swipeCache
}

func TestSwipe_SelfSwipeForbidden(t *testing.T) {
	svc, userRepo, _, _, _ := setupSwipeService()
	ctx := context.Background()

	uid := uuid.New()
	userRepo.users[uid] = &domain.User{ID: uid, Status: "active"}

	_, err := svc.Swipe(ctx, uid, uid, domain.SwipeDirectionLike)
	assert.Error(t, err)
	var appErr *apperrors.AppError
	assert.ErrorAs(t, err, &appErr)
	assert.Equal(t, 400, appErr.StatusCode)
}

func TestSwipe_FreeUserDailyLikeRateLimit(t *testing.T) {
	svc, userRepo, _, _, _ := setupSwipeService()
	ctx := context.Background()

	swiperID := uuid.New()
	userRepo.users[swiperID] = &domain.User{ID: swiperID, Status: "active", IsPremium: false}

	// Limit is 5
	for i := 0; i < 5; i++ {
		targetID := uuid.New()
		res, err := svc.Swipe(ctx, swiperID, targetID, domain.SwipeDirectionLike)
		require.NoError(t, err)
		assert.False(t, res.Matched)
	}

	// 6th like should hit 429
	targetID := uuid.New()
	res, err := svc.Swipe(ctx, swiperID, targetID, domain.SwipeDirectionLike)
	assert.Error(t, err)
	assert.Nil(t, res)
	var appErr *apperrors.AppError
	require.ErrorAs(t, err, &appErr)
	assert.Equal(t, 429, appErr.StatusCode)
}

func TestSwipe_PremiumUserUnlimitedLikes(t *testing.T) {
	svc, userRepo, _, _, _ := setupSwipeService()
	ctx := context.Background()

	swiperID := uuid.New()
	userRepo.users[swiperID] = &domain.User{ID: swiperID, Status: "active", IsPremium: true}

	for i := 0; i < 20; i++ {
		targetID := uuid.New()
		res, err := svc.Swipe(ctx, swiperID, targetID, domain.SwipeDirectionLike)
		require.NoError(t, err)
		assert.False(t, res.Matched)
	}
}

func TestSwipe_FreeUserSuperLikeLimit(t *testing.T) {
	svc, userRepo, _, _, _ := setupSwipeService()
	ctx := context.Background()

	swiperID := uuid.New()
	userRepo.users[swiperID] = &domain.User{ID: swiperID, Status: "active", IsPremium: false}

	// 1st super like allowed
	target1 := uuid.New()
	res, err := svc.Swipe(ctx, swiperID, target1, domain.SwipeDirectionSuper)
	require.NoError(t, err)
	assert.False(t, res.Matched)

	// 2nd super like blocked
	target2 := uuid.New()
	_, err = svc.Swipe(ctx, swiperID, target2, domain.SwipeDirectionSuper)
	assert.Error(t, err)
	var appErr *apperrors.AppError
	require.ErrorAs(t, err, &appErr)
	assert.Equal(t, 429, appErr.StatusCode)
}

func TestSwipe_MutualLikeRaceConditionFormsSingleMatch(t *testing.T) {
	svc, userRepo, _, matchRepo, _ := setupSwipeService()
	ctx := context.Background()

	userA := uuid.New()
	userB := uuid.New()
	userRepo.users[userA] = &domain.User{ID: userA, Status: "active", IsPremium: true}
	userRepo.users[userB] = &domain.User{ID: userB, Status: "active", IsPremium: true}

	var wg sync.WaitGroup
	wg.Add(2)

	var resA, resB *service.SwipeResponse
	var errA, errB error

	go func() {
		defer wg.Done()
		resA, errA = svc.Swipe(ctx, userA, userB, domain.SwipeDirectionLike)
	}()

	go func() {
		defer wg.Done()
		resB, errB = svc.Swipe(ctx, userB, userA, domain.SwipeDirectionLike)
	}()

	wg.Wait()

	require.NoError(t, errA)
	require.NoError(t, errB)

	// Exactly one match record must exist in matchRepo
	matchRepo.mu.Lock()
	matchCount := len(matchRepo.matches)
	matchRepo.mu.Unlock()

	assert.Equal(t, 1, matchCount, "Concurrent mutual likes must produce exactly one match")
	// At least one of the callers must observe Matched = true
	assert.True(t, resA.Matched || resB.Matched)
}

func TestSwipe_Rewind(t *testing.T) {
	svc, userRepo, swipeRepo, matchRepo, swipeCache := setupSwipeService()
	ctx := context.Background()

	freeUser := uuid.New()
	premUser := uuid.New()
	targetID := uuid.New()

	userRepo.users[freeUser] = &domain.User{ID: freeUser, Status: "active", IsPremium: false}
	userRepo.users[premUser] = &domain.User{ID: premUser, Status: "active", IsPremium: true}

	// 1. Free user gets 403 Forbidden
	_, err := svc.Rewind(ctx, freeUser)
	assert.Error(t, err)
	var appErr *apperrors.AppError
	require.ErrorAs(t, err, &appErr)
	assert.Equal(t, 403, appErr.StatusCode)

	// 2. Premium user swipes and then rewinds
	swipeRes, err := svc.Swipe(ctx, premUser, targetID, domain.SwipeDirectionLike)
	require.NoError(t, err)
	assert.False(t, swipeRes.Matched)

	swiped, _ := swipeCache.IsSwiped(ctx, premUser, targetID)
	assert.True(t, swiped)

	rewindRes, err := svc.Rewind(ctx, premUser)
	require.NoError(t, err)
	assert.True(t, rewindRes.Undone)
	assert.Equal(t, targetID, rewindRes.TargetID)
	assert.Equal(t, "like", rewindRes.Direction)

	// Check state reverted
	swipedAfter, _ := swipeCache.IsSwiped(ctx, premUser, targetID)
	assert.False(t, swipedAfter)

	dbSwipe, _ := swipeRepo.GetSwipe(ctx, premUser, targetID)
	assert.Nil(t, dbSwipe)

	match, _ := matchRepo.GetBetweenUsers(ctx, premUser, targetID)
	assert.Nil(t, match)
}
