package service

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"

	"github.com/abshwabu/fikir/backend/internal/cache"
	"github.com/abshwabu/fikir/backend/internal/config"
	"github.com/abshwabu/fikir/backend/internal/domain"
	apperrors "github.com/abshwabu/fikir/backend/internal/platform/errors"
	"github.com/abshwabu/fikir/backend/internal/queue"
)

type DiscoveryService interface {
	GetDeck(ctx context.Context, userID uuid.UUID, limit int, acceptHeader string) ([]domain.ProfileCard, error)
	RefillDeck(ctx context.Context, userID uuid.UUID) error
}

type discoveryService struct {
	cfg           config.DiscoveryConfig
	discoveryRepo domain.DiscoveryRepository
	profileRepo   domain.ProfileRepository
	deckCache     cache.DeckCache
	cardCache     cache.ProfileCardCache
	swipeCache    cache.SwipeCache
	queueClient   *queue.Client
}

func NewDiscoveryService(
	cfg config.DiscoveryConfig,
	discoveryRepo domain.DiscoveryRepository,
	profileRepo domain.ProfileRepository,
	deckCache cache.DeckCache,
	cardCache cache.ProfileCardCache,
	swipeCache cache.SwipeCache,
	queueClient *queue.Client,
) DiscoveryService {
	return &discoveryService{
		cfg:           cfg,
		discoveryRepo: discoveryRepo,
		profileRepo:   profileRepo,
		deckCache:     deckCache,
		cardCache:     cardCache,
		swipeCache:    swipeCache,
		queueClient:   queueClient,
	}
}

func (s *discoveryService) GetDeck(ctx context.Context, userID uuid.UUID, limit int, acceptHeader string) ([]domain.ProfileCard, error) {
	if limit <= 0 {
		limit = s.cfg.PageLimit
	}
	if limit > 50 {
		limit = 50
	}

	// 1. Verify user profile exists
	userProfile, err := s.profileRepo.GetByUserID(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch user profile: %w", err)
	}
	if userProfile == nil {
		return nil, apperrors.NotFound("profile not found; complete profile first")
	}

	// 2. Check current deck size in Redis
	deckLen, err := s.deckCache.Len(ctx, userID)
	if err != nil {
		deckLen = 0
	}

	// If deck has fewer items than requested, refill synchronously
	if deckLen < int64(limit) {
		_ = s.RefillDeck(ctx, userID)
	} else if deckLen < int64(s.cfg.DeckRefillThreshold) && s.queueClient != nil {
		// Trigger async refill when below threshold
		_, _ = s.queueClient.EnqueueDeckRefill(ctx, userID)
	}

	// 3. Pop candidate IDs from Redis list
	poppedIDs, err := s.deckCache.Pop(ctx, userID, limit)
	if err != nil {
		return nil, fmt.Errorf("failed to pop candidate IDs: %w", err)
	}

	if len(poppedIDs) == 0 {
		return []domain.ProfileCard{}, nil
	}

	// 4. Filter out any already swiped candidates (in case swiped on another device)
	swipedMap := make(map[uuid.UUID]bool)
	validIDs := make([]uuid.UUID, 0, len(poppedIDs))
	for _, id := range poppedIDs {
		swiped, _ := s.swipeCache.IsSwiped(ctx, userID, id)
		if !swiped {
			validIDs = append(validIDs, id)
		} else {
			swipedMap[id] = true
		}
	}

	if len(validIDs) == 0 {
		return []domain.ProfileCard{}, nil
	}

	// 5. Batch hydrate profile cards from card cache (with MGET pipeline & DB fallback)
	cardMap, err := s.cardCache.GetMany(ctx, validIDs, acceptHeader, func(missingIDs []uuid.UUID) (map[uuid.UUID]*domain.ProfileCard, error) {
		return s.discoveryRepo.GetProfileCards(ctx, missingIDs, acceptHeader)
	})
	if err != nil {
		return nil, fmt.Errorf("failed to hydrate profile cards: %w", err)
	}

	// 6. Return cards in popped order
	deckCards := make([]domain.ProfileCard, 0, len(validIDs))
	for _, id := range validIDs {
		if card, ok := cardMap[id]; ok && card != nil {
			deckCards = append(deckCards, *card)
		}
	}

	return deckCards, nil
}

func (s *discoveryService) RefillDeck(ctx context.Context, userID uuid.UUID) error {
	userProfile, err := s.profileRepo.GetByUserID(ctx, userID)
	if err != nil || userProfile == nil {
		return err
	}

	var lat, lng float64
	if userProfile.Location != nil {
		lat = userProfile.Location.Latitude
		lng = userProfile.Location.Longitude
	}

	// Collect already swiped IDs to exclude
	swipedIDs, _ := s.swipeCache.GetSwipedIDs(ctx, userID)

	baseRadiusKm := float64(userProfile.DistancePrefKm)
	if baseRadiusKm <= 0 {
		baseRadiusKm = 50.0
	}

	// Progressive radius expansion stages
	radiusStages := []float64{
		baseRadiusKm * 1000.0,
		baseRadiusKm * 1.5 * 1000.0,
		baseRadiusKm * 2.5 * 1000.0,
		200.0 * 1000.0,
		500.0 * 1000.0,
		0.0, // nationwide / unrestricted
	}

	targetSize := s.cfg.DeckTargetSize
	if targetSize <= 0 {
		targetSize = 100
	}

	seenIDs := make(map[uuid.UUID]bool)
	for _, id := range swipedIDs {
		seenIDs[id] = true
	}
	seenIDs[userID] = true

	var collectedCandidates []domain.DiscoveryCandidate

	for _, radiusMeters := range radiusStages {
		if len(collectedCandidates) >= targetSize {
			break
		}

		limit := targetSize - len(collectedCandidates)
		params := domain.DiscoveryParams{
			UserID:       userID,
			Gender:       userProfile.Gender,
			InterestedIn: userProfile.InterestedIn,
			Birthdate:    userProfile.Birthdate,
			AgeMin:       userProfile.AgeMin,
			AgeMax:       userProfile.AgeMax,
			Latitude:     lat,
			Longitude:    lng,
			RadiusMeters: radiusMeters,
			ExcludedIDs:  mapKeysToSlice(seenIDs),
			Limit:        limit,
		}

		candidates, err := s.discoveryRepo.GetCandidates(ctx, params)
		if err != nil {
			return fmt.Errorf("failed to fetch discovery candidates: %w", err)
		}

		for _, c := range candidates {
			if !seenIDs[c.UserID] {
				seenIDs[c.UserID] = true
				collectedCandidates = append(collectedCandidates, c)
			}
		}

		// If user has no coordinates, radius doesn't matter, stop after stage 1
		if lat == 0.0 && lng == 0.0 {
			break
		}
	}

	if len(collectedCandidates) == 0 {
		return nil
	}

	candidateIDs := make([]uuid.UUID, len(collectedCandidates))
	for i, c := range collectedCandidates {
		candidateIDs[i] = c.UserID
	}

	// Push candidate IDs into Redis list
	return s.deckCache.Push(ctx, userID, candidateIDs, 15*time.Minute)
}

func mapKeysToSlice(m map[uuid.UUID]bool) []uuid.UUID {
	keys := make([]uuid.UUID, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	return keys
}
