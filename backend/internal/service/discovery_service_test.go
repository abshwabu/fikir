package service_test

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/abshwabu/fikir/backend/internal/config"
	"github.com/abshwabu/fikir/backend/internal/domain"
	"github.com/abshwabu/fikir/backend/internal/service"
)

type mockProfileRepo struct {
	profiles map[uuid.UUID]*domain.Profile
}

func (m *mockProfileRepo) GetByUserID(ctx context.Context, userID uuid.UUID) (*domain.Profile, error) {
	return m.profiles[userID], nil
}
func (m *mockProfileRepo) Upsert(ctx context.Context, profile *domain.Profile) error {
	m.profiles[profile.UserID] = profile
	return nil
}
func (m *mockProfileRepo) UpdateInterests(ctx context.Context, userID uuid.UUID, interests []string) error {
	return nil
}
func (m *mockProfileRepo) UpdateLocation(ctx context.Context, userID uuid.UUID, lat, lng float64, city, region string) error {
	return nil
}
func (m *mockProfileRepo) GetPhotos(ctx context.Context, userID uuid.UUID) ([]domain.ProfilePhoto, error) {
	return nil, nil
}
func (m *mockProfileRepo) GetPhotoByID(ctx context.Context, id uuid.UUID) (*domain.ProfilePhoto, error) {
	return nil, nil
}
func (m *mockProfileRepo) CreatePhoto(ctx context.Context, photo *domain.ProfilePhoto) error {
	return nil
}
func (m *mockProfileRepo) UpdatePhoto(ctx context.Context, photo *domain.ProfilePhoto) error {
	return nil
}
func (m *mockProfileRepo) DeletePhoto(ctx context.Context, photoID, userID uuid.UUID) error {
	return nil
}
func (m *mockProfileRepo) CountPhotos(ctx context.Context, userID uuid.UUID) (int, error) {
	return 1, nil
}
func (m *mockProfileRepo) ReorderPhotos(ctx context.Context, userID uuid.UUID, photoIDs []uuid.UUID) error {
	return nil
}
func (m *mockProfileRepo) GetUserInterests(ctx context.Context, userID uuid.UUID) ([]string, error) {
	return nil, nil
}
func (m *mockProfileRepo) CreateVerification(ctx context.Context, v *domain.Verification) error {
	return nil
}

type mockDeckCache struct {
	decks map[uuid.UUID][]uuid.UUID
}

func newMockDeckCache() *mockDeckCache {
	return &mockDeckCache{decks: make(map[uuid.UUID][]uuid.UUID)}
}

func (m *mockDeckCache) Pop(ctx context.Context, userID uuid.UUID, count int) ([]uuid.UUID, error) {
	items := m.decks[userID]
	if len(items) == 0 {
		return nil, nil
	}
	if count > len(items) {
		count = len(items)
	}
	popped := items[:count]
	m.decks[userID] = items[count:]
	return popped, nil
}

func (m *mockDeckCache) Push(ctx context.Context, userID uuid.UUID, candidateIDs []uuid.UUID, ttl time.Duration) error {
	m.decks[userID] = append(m.decks[userID], candidateIDs...)
	return nil
}

func (m *mockDeckCache) Len(ctx context.Context, userID uuid.UUID) (int64, error) {
	return int64(len(m.decks[userID])), nil
}

func (m *mockDeckCache) Clear(ctx context.Context, userID uuid.UUID) error {
	delete(m.decks, userID)
	return nil
}

func (m *mockDeckCache) Remove(ctx context.Context, userID, targetID uuid.UUID) error {
	items := m.decks[userID]
	newItems := make([]uuid.UUID, 0, len(items))
	for _, id := range items {
		if id != targetID {
			newItems = append(newItems, id)
		}
	}
	m.decks[userID] = newItems
	return nil
}

func (m *mockDeckCache) GetIDs(ctx context.Context, userID uuid.UUID) ([]uuid.UUID, error) {
	return m.decks[userID], nil
}

type mockCardCache struct {
	cards map[uuid.UUID]*domain.ProfileCard
}

func (m *mockCardCache) Get(ctx context.Context, userID uuid.UUID, acceptHeader string, fetchFn func() (*domain.ProfileCard, error)) (*domain.ProfileCard, error) {
	if c, ok := m.cards[userID]; ok {
		return c, nil
	}
	return fetchFn()
}

func (m *mockCardCache) GetMany(ctx context.Context, userIDs []uuid.UUID, acceptHeader string, fetchBatchFn func([]uuid.UUID) (map[uuid.UUID]*domain.ProfileCard, error)) (map[uuid.UUID]*domain.ProfileCard, error) {
	res := make(map[uuid.UUID]*domain.ProfileCard)
	for _, id := range userIDs {
		if c, ok := m.cards[id]; ok {
			res[id] = c
		}
	}
	return res, nil
}

func (m *mockCardCache) Set(ctx context.Context, card *domain.ProfileCard) error {
	m.cards[card.UserID] = card
	return nil
}

func (m *mockCardCache) Invalidate(ctx context.Context, userID uuid.UUID) error {
	delete(m.cards, userID)
	return nil
}

type mockDiscoveryRepo struct {
	candidates []domain.DiscoveryCandidate
}

func (m *mockDiscoveryRepo) GetCandidates(ctx context.Context, params domain.DiscoveryParams) ([]domain.DiscoveryCandidate, error) {
	return m.candidates, nil
}

func (m *mockDiscoveryRepo) GetProfileCard(ctx context.Context, userID uuid.UUID, acceptHeader string) (*domain.ProfileCard, error) {
	return nil, nil
}

func (m *mockDiscoveryRepo) GetProfileCards(ctx context.Context, userIDs []uuid.UUID, acceptHeader string) (map[uuid.UUID]*domain.ProfileCard, error) {
	return nil, nil
}

func TestDiscovery_GetDeck(t *testing.T) {
	ctx := context.Background()
	myID := uuid.New()

	profileRepo := &mockProfileRepo{
		profiles: map[uuid.UUID]*domain.Profile{
			myID: {
				UserID:         myID,
				DisplayName:    "Abebe",
				Gender:         "male",
				InterestedIn:   []string{"female"},
				Birthdate:      time.Now().AddDate(-25, 0, 0),
				AgeMin:         18,
				AgeMax:         30,
				DistancePrefKm: 50,
			},
		},
	}

	c1 := uuid.New()
	c2 := uuid.New()
	c3 := uuid.New()

	deckCache := newMockDeckCache()
	_ = deckCache.Push(ctx, myID, []uuid.UUID{c1, c2, c3}, 15*time.Minute)

	cardCache := &mockCardCache{
		cards: map[uuid.UUID]*domain.ProfileCard{
			c1: {UserID: c1, DisplayName: "Selam", Age: 23, Gender: "female"},
			c2: {UserID: c2, DisplayName: "Hanan", Age: 25, Gender: "female"},
			c3: {UserID: c3, DisplayName: "Eden", Age: 22, Gender: "female"},
		},
	}

	swipeCache := newMockSwipeCache()
	// c2 was already swiped in another tab/device
	_ = swipeCache.AddSwiped(ctx, myID, c2)

	cfg := config.DiscoveryConfig{
		DeckTargetSize:      100,
		DeckRefillThreshold: 30,
		PageLimit:           15,
	}

	discoveryRepo := &mockDiscoveryRepo{}
	svc := service.NewDiscoveryService(cfg, discoveryRepo, profileRepo, deckCache, cardCache, swipeCache, nil)

	deck, err := svc.GetDeck(ctx, myID, 15, "")
	require.NoError(t, err)

	// c2 should be filtered out
	assert.Len(t, deck, 2)
	assert.Equal(t, c1, deck[0].UserID)
	assert.Equal(t, c3, deck[1].UserID)
}
