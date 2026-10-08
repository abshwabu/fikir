package cache

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	"golang.org/x/sync/singleflight"

	"github.com/abshwabu/fikir/backend/internal/domain"
)

const (
	defaultCardTTL     = 10 * time.Minute
	defaultNegativeTTL = 2 * time.Minute
	negativeCardMarker = "__negative__"
)

// ProfileCardCache defines caching operations for candidate cards
type ProfileCardCache interface {
	Get(ctx context.Context, userID uuid.UUID, acceptHeader string, fetchFn func() (*domain.ProfileCard, error)) (*domain.ProfileCard, error)
	GetMany(ctx context.Context, userIDs []uuid.UUID, acceptHeader string, fetchBatchFn func([]uuid.UUID) (map[uuid.UUID]*domain.ProfileCard, error)) (map[uuid.UUID]*domain.ProfileCard, error)
	Set(ctx context.Context, card *domain.ProfileCard) error
	Invalidate(ctx context.Context, userID uuid.UUID) error
}

type redisProfileCardCache struct {
	rdb redis.UniversalClient
	sf  singleflight.Group
}

func NewProfileCardCache(rdb redis.UniversalClient) ProfileCardCache {
	return &redisProfileCardCache{
		rdb: rdb,
	}
}

func (c *redisProfileCardCache) cardKey(id uuid.UUID) string {
	return fmt.Sprintf("profile:card:%s", id.String())
}

func (c *redisProfileCardCache) Get(ctx context.Context, userID uuid.UUID, acceptHeader string, fetchFn func() (*domain.ProfileCard, error)) (*domain.ProfileCard, error) {
	key := c.cardKey(userID)

	// 1. Try cache lookup
	val, err := c.rdb.Get(ctx, key).Result()
	if err == nil {
		if val == negativeCardMarker {
			RecordCacheHit("card_negative")
			return nil, nil
		}
		var card domain.ProfileCard
		if err := json.Unmarshal([]byte(val), &card); err == nil {
			RecordCacheHit("card")
			return &card, nil
		}
	}

	RecordCacheMiss("card")

	// 2. Cache miss -> singleflight fetch
	res, sfErr, _ := c.sf.Do(key, func() (any, error) {
		card, err := fetchFn()
		if err != nil {
			return nil, err
		}
		if card == nil {
			// Cache negative lookup briefly
			ttl := Jitter(defaultNegativeTTL, 0.15)
			_ = c.rdb.Set(ctx, key, negativeCardMarker, ttl).Err()
			return nil, nil
		}

		_ = c.Set(ctx, card)
		return card, nil
	})

	if sfErr != nil {
		return nil, sfErr
	}

	if res == nil {
		return nil, nil
	}

	return res.(*domain.ProfileCard), nil
}

func (c *redisProfileCardCache) GetMany(
	ctx context.Context,
	userIDs []uuid.UUID,
	acceptHeader string,
	fetchBatchFn func([]uuid.UUID) (map[uuid.UUID]*domain.ProfileCard, error),
) (map[uuid.UUID]*domain.ProfileCard, error) {
	if len(userIDs) == 0 {
		return make(map[uuid.UUID]*domain.ProfileCard), nil
	}

	keys := make([]string, len(userIDs))
	idByKey := make(map[string]uuid.UUID, len(userIDs))
	for i, id := range userIDs {
		k := c.cardKey(id)
		keys[i] = k
		idByKey[k] = id
	}

	// 1. Pipeline MGET for low-latency batch retrieval
	results, err := c.rdb.MGet(ctx, keys...).Result()
	if err != nil {
		results = make([]any, len(keys))
	}

	cards := make(map[uuid.UUID]*domain.ProfileCard, len(userIDs))
	var missingIDs []uuid.UUID

	for i, raw := range results {
		id := userIDs[i]
		if raw == nil {
			missingIDs = append(missingIDs, id)
			RecordCacheMiss("card")
			continue
		}

		strVal, ok := raw.(string)
		if !ok {
			missingIDs = append(missingIDs, id)
			RecordCacheMiss("card")
			continue
		}

		if strVal == negativeCardMarker {
			RecordCacheHit("card_negative")
			continue
		}

		var card domain.ProfileCard
		if err := json.Unmarshal([]byte(strVal), &card); err != nil {
			missingIDs = append(missingIDs, id)
			RecordCacheMiss("card")
			continue
		}

		cards[id] = &card
		RecordCacheHit("card")
	}

	// 2. Fetch missing cards from DB
	if len(missingIDs) > 0 && fetchBatchFn != nil {
		fetched, err := fetchBatchFn(missingIDs)
		if err != nil {
			return nil, err
		}

		pipe := c.rdb.Pipeline()
		for _, missID := range missingIDs {
			k := c.cardKey(missID)
			if card, ok := fetched[missID]; ok && card != nil {
				cards[missID] = card
				if bytes, err := json.Marshal(card); err == nil {
					ttl := Jitter(defaultCardTTL, 0.15)
					pipe.Set(ctx, k, bytes, ttl)
				}
			} else {
				// Negative cache
				ttl := Jitter(defaultNegativeTTL, 0.15)
				pipe.Set(ctx, k, negativeCardMarker, ttl)
			}
		}
		_, _ = pipe.Exec(ctx)
	}

	return cards, nil
}

func (c *redisProfileCardCache) Set(ctx context.Context, card *domain.ProfileCard) error {
	if card == nil {
		return nil
	}
	bytes, err := json.Marshal(card)
	if err != nil {
		return err
	}

	key := c.cardKey(card.UserID)
	ttl := Jitter(defaultCardTTL, 0.15)
	return c.rdb.Set(ctx, key, bytes, ttl).Err()
}

func (c *redisProfileCardCache) Invalidate(ctx context.Context, userID uuid.UUID) error {
	key := c.cardKey(userID)
	return c.rdb.Del(ctx, key).Err()
}
