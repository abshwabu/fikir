package cache

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
)

const (
	maxSwipedSetSize = 5000
	swipedSetTTL     = 30 * 24 * time.Hour
	likesReceivedTTL = 30 * 24 * time.Hour
)

type SwipedHistoryItem struct {
	TargetID  uuid.UUID `json:"target_id"`
	Direction string    `json:"direction"`
	CreatedAt time.Time `json:"created_at"`
}

// SwipeCache defines operations for real-time swipe sets, mutual like tracking, and rate limits
type SwipeCache interface {
	AddSwiped(ctx context.Context, userID, targetID uuid.UUID) error
	IsSwiped(ctx context.Context, userID, targetID uuid.UUID) (bool, error)
	GetSwipedIDs(ctx context.Context, userID uuid.UUID) ([]uuid.UUID, error)
	RemoveSwiped(ctx context.Context, userID, targetID uuid.UUID) error

	AddLikeReceived(ctx context.Context, targetID, fromUserID uuid.UUID) error
	HasLikeReceived(ctx context.Context, targetID, fromUserID uuid.UUID) (bool, error)
	RemoveLikeReceived(ctx context.Context, targetID, fromUserID uuid.UUID) error
	GetLikesReceivedIDs(ctx context.Context, userID uuid.UUID) ([]uuid.UUID, error)

	PushSwipeHistory(ctx context.Context, userID uuid.UUID, item SwipedHistoryItem) error
	PopSwipeHistory(ctx context.Context, userID uuid.UUID) (*SwipedHistoryItem, error)

	CheckAndIncrLikeCount(ctx context.Context, userID uuid.UUID, isPremium bool, limit int, window time.Duration) (bool, int, time.Time, error)
	CheckAndIncrSuperLike(ctx context.Context, userID uuid.UUID, isPremium bool) (bool, time.Time, error)
}

type redisSwipeCache struct {
	rdb redis.UniversalClient
}

func NewSwipeCache(rdb redis.UniversalClient) SwipeCache {
	return &redisSwipeCache{
		rdb: rdb,
	}
}

func (s *redisSwipeCache) swipedKey(userID uuid.UUID) string {
	return fmt.Sprintf("swipes:swiped:%s", userID.String())
}

func (s *redisSwipeCache) likesReceivedKey(userID uuid.UUID) string {
	return fmt.Sprintf("swipes:likes_received:%s", userID.String())
}

func (s *redisSwipeCache) historyKey(userID uuid.UUID) string {
	return fmt.Sprintf("swipes:history:%s", userID.String())
}

func (s *redisSwipeCache) likeCounterKey(userID uuid.UUID) string {
	return fmt.Sprintf("swipes:limit:like:%s", userID.String())
}

func (s *redisSwipeCache) superLikeCounterKey(userID uuid.UUID) string {
	return fmt.Sprintf("swipes:limit:superlike:%s", userID.String())
}

func (s *redisSwipeCache) AddSwiped(ctx context.Context, userID, targetID uuid.UUID) error {
	key := s.swipedKey(userID)
	pipe := s.rdb.Pipeline()
	pipe.SAdd(ctx, key, targetID.String())
	pipe.Expire(ctx, key, swipedSetTTL)
	_, err := pipe.Exec(ctx)
	return err
}

func (s *redisSwipeCache) IsSwiped(ctx context.Context, userID, targetID uuid.UUID) (bool, error) {
	key := s.swipedKey(userID)
	return s.rdb.SIsMember(ctx, key, targetID.String()).Result()
}

func (s *redisSwipeCache) GetSwipedIDs(ctx context.Context, userID uuid.UUID) ([]uuid.UUID, error) {
	key := s.swipedKey(userID)
	members, err := s.rdb.SMembers(ctx, key).Result()
	if err != nil {
		return nil, err
	}

	results := make([]uuid.UUID, 0, len(members))
	for _, m := range members {
		id, err := uuid.Parse(m)
		if err == nil {
			results = append(results, id)
		}
	}
	return results, nil
}

func (s *redisSwipeCache) RemoveSwiped(ctx context.Context, userID, targetID uuid.UUID) error {
	key := s.swipedKey(userID)
	return s.rdb.SRem(ctx, key, targetID.String()).Err()
}

func (s *redisSwipeCache) AddLikeReceived(ctx context.Context, targetID, fromUserID uuid.UUID) error {
	key := s.likesReceivedKey(targetID)
	pipe := s.rdb.Pipeline()
	pipe.SAdd(ctx, key, fromUserID.String())
	pipe.Expire(ctx, key, likesReceivedTTL)
	_, err := pipe.Exec(ctx)
	return err
}

func (s *redisSwipeCache) HasLikeReceived(ctx context.Context, targetID, fromUserID uuid.UUID) (bool, error) {
	key := s.likesReceivedKey(targetID)
	return s.rdb.SIsMember(ctx, key, fromUserID.String()).Result()
}

func (s *redisSwipeCache) RemoveLikeReceived(ctx context.Context, targetID, fromUserID uuid.UUID) error {
	key := s.likesReceivedKey(targetID)
	return s.rdb.SRem(ctx, key, fromUserID.String()).Err()
}

func (s *redisSwipeCache) GetLikesReceivedIDs(ctx context.Context, userID uuid.UUID) ([]uuid.UUID, error) {
	key := s.likesReceivedKey(userID)
	members, err := s.rdb.SMembers(ctx, key).Result()
	if err != nil {
		return nil, err
	}

	results := make([]uuid.UUID, 0, len(members))
	for _, m := range members {
		id, err := uuid.Parse(m)
		if err == nil {
			results = append(results, id)
		}
	}
	return results, nil
}

func (s *redisSwipeCache) PushSwipeHistory(ctx context.Context, userID uuid.UUID, item SwipedHistoryItem) error {
	key := s.historyKey(userID)
	bytes, err := json.Marshal(item)
	if err != nil {
		return err
	}

	pipe := s.rdb.Pipeline()
	pipe.LPush(ctx, key, bytes)
	pipe.LTrim(ctx, key, 0, 99) // keep recent 100 swipes for rewind
	pipe.Expire(ctx, key, 24*time.Hour)
	_, err = pipe.Exec(ctx)
	return err
}

func (s *redisSwipeCache) PopSwipeHistory(ctx context.Context, userID uuid.UUID) (*SwipedHistoryItem, error) {
	key := s.historyKey(userID)
	val, err := s.rdb.LPop(ctx, key).Result()
	if err != nil {
		if errors.Is(err, redis.Nil) {
			return nil, nil
		}
		return nil, err
	}

	var item SwipedHistoryItem
	if err := json.Unmarshal([]byte(val), &item); err != nil {
		return nil, err
	}
	return &item, nil
}

func (s *redisSwipeCache) CheckAndIncrLikeCount(
	ctx context.Context,
	userID uuid.UUID,
	isPremium bool,
	limit int,
	window time.Duration,
) (bool, int, time.Time, error) {
	if isPremium {
		return true, 999999, time.Time{}, nil
	}

	key := s.likeCounterKey(userID)
	cnt, err := s.rdb.Incr(ctx, key).Result()
	if err != nil {
		return true, 0, time.Time{}, err
	}

	if cnt == 1 {
		_ = s.rdb.Expire(ctx, key, window).Err()
	}

	ttl, _ := s.rdb.TTL(ctx, key).Result()
	if ttl <= 0 {
		ttl = window
	}
	resetAt := time.Now().Add(ttl)

	if int(cnt) > limit {
		return false, 0, resetAt, nil
	}

	remaining := limit - int(cnt)
	return true, remaining, resetAt, nil
}

func (s *redisSwipeCache) CheckAndIncrSuperLike(
	ctx context.Context,
	userID uuid.UUID,
	isPremium bool,
) (bool, time.Time, error) {
	if isPremium {
		return true, time.Time{}, nil
	}

	window := 24 * time.Hour
	key := s.superLikeCounterKey(userID)
	cnt, err := s.rdb.Incr(ctx, key).Result()
	if err != nil {
		return true, time.Time{}, err
	}

	if cnt == 1 {
		_ = s.rdb.Expire(ctx, key, window).Err()
	}

	ttl, _ := s.rdb.TTL(ctx, key).Result()
	if ttl <= 0 {
		ttl = window
	}
	resetAt := time.Now().Add(ttl)

	if cnt > 1 {
		return false, resetAt, nil
	}

	return true, resetAt, nil
}
