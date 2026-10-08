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

type SwipeResponse struct {
	Matched bool          `json:"matched"`
	Match   *domain.Match `json:"match,omitempty"`
}

type RewindResponse struct {
	Undone    bool      `json:"undone"`
	TargetID  uuid.UUID `json:"target_id"`
	Direction string    `json:"direction"`
}

type LikesYouPreview struct {
	Blurhash        string `json:"blurhash,omitempty"`
	BlurredPhotoURL string `json:"blurred_photo_url,omitempty"`
}

type LikesYouResponse struct {
	Count    int64                 `json:"count"`
	Profiles []domain.ProfileCard `json:"profiles,omitempty"`
	Preview  *LikesYouPreview      `json:"preview,omitempty"`
}

type SwipeService interface {
	Swipe(ctx context.Context, swiperID, targetID uuid.UUID, direction domain.SwipeDirection) (*SwipeResponse, error)
	Rewind(ctx context.Context, userID uuid.UUID) (*RewindResponse, error)
	GetLikesYou(ctx context.Context, userID uuid.UUID, isPremium bool, limit int, acceptHeader string) (*LikesYouResponse, error)
	GetMatches(ctx context.Context, userID uuid.UUID, limit int, cursor string) ([]domain.MatchWithPreview, string, error)
	Unmatch(ctx context.Context, matchID, userID uuid.UUID) error
	Block(ctx context.Context, blockerID, blockedID uuid.UUID, reason string) error
	Report(ctx context.Context, reporterID, reportedID uuid.UUID, reason, details string) error
	ProcessSwipeRecord(ctx context.Context, swiperID, targetID uuid.UUID, direction string, createdAt time.Time) error
}

type swipeService struct {
	cfg           config.SwipeConfig
	userRepo      domain.UserRepository
	profileRepo   domain.ProfileRepository
	swipeRepo     domain.SwipeRepository
	matchRepo     domain.MatchRepository
	blockRepo     domain.BlockRepository
	reportRepo    domain.ReportRepository
	discoveryRepo domain.DiscoveryRepository
	swipeCache    cache.SwipeCache
	cardCache     cache.ProfileCardCache
	queueClient   *queue.Client
}

func NewSwipeService(
	cfg config.SwipeConfig,
	userRepo domain.UserRepository,
	profileRepo domain.ProfileRepository,
	swipeRepo domain.SwipeRepository,
	matchRepo domain.MatchRepository,
	blockRepo domain.BlockRepository,
	reportRepo domain.ReportRepository,
	discoveryRepo domain.DiscoveryRepository,
	swipeCache cache.SwipeCache,
	cardCache cache.ProfileCardCache,
	queueClient *queue.Client,
) SwipeService {
	return &swipeService{
		cfg:           cfg,
		userRepo:      userRepo,
		profileRepo:   profileRepo,
		swipeRepo:     swipeRepo,
		matchRepo:     matchRepo,
		blockRepo:     blockRepo,
		reportRepo:    reportRepo,
		discoveryRepo: discoveryRepo,
		swipeCache:    swipeCache,
		cardCache:     cardCache,
		queueClient:   queueClient,
	}
}

func (s *swipeService) Swipe(ctx context.Context, swiperID, targetID uuid.UUID, direction domain.SwipeDirection) (*SwipeResponse, error) {
	if swiperID == targetID {
		return nil, apperrors.BadRequest("cannot swipe on yourself")
	}

	if direction != domain.SwipeDirectionLike &&
		direction != domain.SwipeDirectionNope &&
		direction != domain.SwipeDirectionSuper {
		return nil, apperrors.BadRequest("invalid direction; must be like, nope, or super")
	}

	// 1. Fetch user to check premium status
	user, err := s.userRepo.GetByID(ctx, swiperID)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch user: %w", err)
	}
	if user == nil {
		return nil, apperrors.Unauthorized("user not found")
	}

	// 2. Daily limits for free users
	if direction == domain.SwipeDirectionSuper {
		allowed, resetAt, err := s.swipeCache.CheckAndIncrSuperLike(ctx, swiperID, user.IsPremium)
		if err != nil {
			return nil, fmt.Errorf("rate limit check error: %w", err)
		}
		if !allowed {
			return nil, apperrors.New(429, apperrors.CodeTooManyRequests, fmt.Sprintf("Super like limit reached. Resets at %s", resetAt.Format(time.RFC3339)))
		}
	} else if direction == domain.SwipeDirectionLike {
		allowed, _, resetAt, err := s.swipeCache.CheckAndIncrLikeCount(ctx, swiperID, user.IsPremium, s.cfg.DailyLikeLimit, s.cfg.LimitWindow)
		if err != nil {
			return nil, fmt.Errorf("rate limit check error: %w", err)
		}
		if !allowed {
			return nil, apperrors.New(429, apperrors.CodeTooManyRequests, fmt.Sprintf("Daily like limit reached. Resets at %s", resetAt.Format(time.RFC3339)))
		}
	}

	now := time.Now().UTC()

	// 3. Fast Redis write path (<20 ms)
	_ = s.swipeCache.AddSwiped(ctx, swiperID, targetID)
	if direction == domain.SwipeDirectionLike || direction == domain.SwipeDirectionSuper {
		_ = s.swipeCache.AddLikeReceived(ctx, targetID, swiperID)
	}

	// Push swipe history for potential rewind
	_ = s.swipeCache.PushSwipeHistory(ctx, swiperID, cache.SwipedHistoryItem{
		TargetID:  targetID,
		Direction: string(direction),
		CreatedAt: now,
	})

	cache.SwipesProcessedTotal.WithLabelValues(string(direction)).Inc()

	// 4. Asynchronously persist to Postgres via queue
	if s.queueClient != nil {
		_, _ = s.queueClient.EnqueueSwipeRecord(ctx, swiperID, targetID, string(direction), now.Format(time.RFC3339Nano))
	} else {
		// Fallback synchronous write if worker queue not attached
		_ = s.swipeRepo.UpsertSwipe(ctx, &domain.Swipe{
			SwiperID:  swiperID,
			TargetID:  targetID,
			Direction: direction,
			CreatedAt: now,
		})
	}

	// 5. Mutual like detection
	if direction == domain.SwipeDirectionLike || direction == domain.SwipeDirectionSuper {
		hasLiked, _ := s.swipeCache.HasLikeReceived(ctx, swiperID, targetID)
		if !hasLiked {
			// Fallback DB check
			hasLiked, _ = s.swipeRepo.CheckMutualLike(ctx, targetID, swiperID)
		}

		if hasLiked {
			// Mutual match!
			match, err := s.matchRepo.CreateMatch(ctx, swiperID, targetID)
			if err != nil {
				return nil, fmt.Errorf("failed to create match: %w", err)
			}

			cache.MatchesCreatedTotal.Inc()

			// Enqueue match notifications
			if s.queueClient != nil && match != nil {
				_, _ = s.queueClient.EnqueueMatchNotification(ctx, match.ID, match.UserA, match.UserB)
			}

			return &SwipeResponse{
				Matched: true,
				Match:   match,
			}, nil
		}
	}

	return &SwipeResponse{
		Matched: false,
	}, nil
}

func (s *swipeService) Rewind(ctx context.Context, userID uuid.UUID) (*RewindResponse, error) {
	// 1. Premium check
	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil || user == nil {
		return nil, apperrors.Unauthorized("user not found")
	}
	if !user.IsPremium {
		return nil, apperrors.Forbidden("rewind is a premium feature")
	}

	// 2. Pop last swipe from Redis history
	lastSwipe, err := s.swipeCache.PopSwipeHistory(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to pop swipe history: %w", err)
	}
	if lastSwipe == nil {
		return nil, apperrors.BadRequest("no recent swipe to rewind")
	}

	targetID := lastSwipe.TargetID
	direction := lastSwipe.Direction

	// 3. Revert Redis state
	_ = s.swipeCache.RemoveSwiped(ctx, userID, targetID)
	if direction == "like" || direction == "super" {
		_ = s.swipeCache.RemoveLikeReceived(ctx, targetID, userID)
	}

	// 4. Revert DB swipe
	_ = s.swipeRepo.DeleteSwipe(ctx, userID, targetID)

	// If a match existed between them, soft-unmatch
	existingMatch, _ := s.matchRepo.GetBetweenUsers(ctx, userID, targetID)
	if existingMatch != nil {
		_ = s.matchRepo.Unmatch(ctx, existingMatch.ID, userID)
	}

	return &RewindResponse{
		Undone:    true,
		TargetID:  targetID,
		Direction: direction,
	}, nil
}

func (s *swipeService) GetLikesYou(ctx context.Context, userID uuid.UUID, isPremium bool, limit int, acceptHeader string) (*LikesYouResponse, error) {
	if limit <= 0 {
		limit = 20
	}

	count, err := s.swipeRepo.CountLikesYou(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to count likes received: %w", err)
	}

	if isPremium {
		// Full profile list for premium members
		items, err := s.swipeRepo.GetLikesYouList(ctx, userID, limit)
		if err != nil {
			return nil, fmt.Errorf("failed to query likes you list: %w", err)
		}

		userIDs := make([]uuid.UUID, len(items))
		for i, item := range items {
			userIDs[i] = item.UserID
		}

		cardMap, err := s.cardCache.GetMany(ctx, userIDs, acceptHeader, func(missingIDs []uuid.UUID) (map[uuid.UUID]*domain.ProfileCard, error) {
			return s.discoveryRepo.GetProfileCards(ctx, missingIDs, acceptHeader)
		})
		if err != nil {
			return nil, err
		}

		cards := make([]domain.ProfileCard, 0, len(items))
		for _, id := range userIDs {
			if card, ok := cardMap[id]; ok && card != nil {
				cards = append(cards, *card)
			}
		}

		return &LikesYouResponse{
			Count:    count,
			Profiles: cards,
		}, nil
	}

	// Free members: return count and blurred teaser preview
	var preview *LikesYouPreview
	if count > 0 {
		items, err := s.swipeRepo.GetLikesYouList(ctx, userID, 1)
		if err == nil && len(items) > 0 {
			teaserCard, _ := s.cardCache.Get(ctx, items[0].UserID, acceptHeader, func() (*domain.ProfileCard, error) {
				return s.discoveryRepo.GetProfileCard(ctx, items[0].UserID, acceptHeader)
			})
			if teaserCard != nil && len(teaserCard.Photos) > 0 {
				preview = &LikesYouPreview{
					Blurhash:        teaserCard.Photos[0].Blurhash,
					BlurredPhotoURL: teaserCard.Photos[0].URL,
				}
			}
		}
	}

	return &LikesYouResponse{
		Count:   count,
		Preview: preview,
	}, nil
}

func (s *swipeService) GetMatches(ctx context.Context, userID uuid.UUID, limit int, cursor string) ([]domain.MatchWithPreview, string, error) {
	if limit <= 0 {
		limit = 20
	}
	if limit > 50 {
		limit = 50
	}

	var cursorTime *time.Time
	if cursor != "" {
		t, err := time.Parse(time.RFC3339Nano, cursor)
		if err == nil {
			cursorTime = &t
		}
	}

	matches, nextCursor, err := s.matchRepo.ListForUser(ctx, userID, limit, cursorTime)
	if err != nil {
		return nil, "", fmt.Errorf("failed to list matches: %w", err)
	}

	var nextCursorStr string
	if nextCursor != nil {
		nextCursorStr = nextCursor.Format(time.RFC3339Nano)
	}

	return matches, nextCursorStr, nil
}

func (s *swipeService) Unmatch(ctx context.Context, matchID, userID uuid.UUID) error {
	match, err := s.matchRepo.GetByID(ctx, matchID)
	if err != nil {
		return err
	}
	if match == nil {
		return apperrors.NotFound("match not found")
	}

	if match.UserA != userID && match.UserB != userID {
		return apperrors.Forbidden("you are not part of this match")
	}

	return s.matchRepo.Unmatch(ctx, matchID, userID)
}

func (s *swipeService) Block(ctx context.Context, blockerID, blockedID uuid.UUID, reason string) error {
	if blockerID == blockedID {
		return apperrors.BadRequest("cannot block yourself")
	}

	if err := s.blockRepo.CreateBlock(ctx, blockerID, blockedID); err != nil {
		return fmt.Errorf("failed to create block: %w", err)
	}

	// Soft-unmatch any existing match
	match, _ := s.matchRepo.GetBetweenUsers(ctx, blockerID, blockedID)
	if match != nil {
		_ = s.matchRepo.Unmatch(ctx, match.ID, blockerID)
	}

	// Clean up Redis sets
	_ = s.swipeCache.AddSwiped(ctx, blockerID, blockedID)
	_ = s.swipeCache.RemoveLikeReceived(ctx, blockerID, blockedID)
	_ = s.swipeCache.RemoveLikeReceived(ctx, blockedID, blockerID)

	return nil
}

func (s *swipeService) Report(ctx context.Context, reporterID, reportedID uuid.UUID, reason, details string) error {
	if reporterID == reportedID {
		return apperrors.BadRequest("cannot report yourself")
	}
	if reason == "" {
		return apperrors.BadRequest("report reason is required")
	}

	report := &domain.Report{
		ID:         uuid.New(),
		ReporterID: reporterID,
		ReportedID: reportedID,
		Reason:     reason,
		Details:    details,
		Status:     "pending",
	}

	return s.reportRepo.CreateReport(ctx, report)
}

func (s *swipeService) ProcessSwipeRecord(ctx context.Context, swiperID, targetID uuid.UUID, direction string, createdAt time.Time) error {
	return s.swipeRepo.UpsertSwipe(ctx, &domain.Swipe{
		SwiperID:  swiperID,
		TargetID:  targetID,
		Direction: domain.SwipeDirection(direction),
		CreatedAt: createdAt,
	})
}
