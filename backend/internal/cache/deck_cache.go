package cache

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
)

const (
	defaultDeckTTL = 15 * time.Minute
)

// DeckCache defines operations on the pre-computed candidate ID decks
type DeckCache interface {
	Pop(ctx context.Context, userID uuid.UUID, count int) ([]uuid.UUID, error)
	Push(ctx context.Context, userID uuid.UUID, candidateIDs []uuid.UUID, ttl time.Duration) error
	Len(ctx context.Context, userID uuid.UUID) (int64, error)
	Clear(ctx context.Context, userID uuid.UUID) error
}

type redisDeckCache struct {
	rdb redis.UniversalClient
}

func NewDeckCache(rdb redis.UniversalClient) DeckCache {
	return &redisDeckCache{
		rdb: rdb,
	}
}

func (d *redisDeckCache) deckKey(userID uuid.UUID) string {
	return fmt.Sprintf("discovery:deck:%s", userID.String())
}

func (d *redisDeckCache) Pop(ctx context.Context, userID uuid.UUID, count int) ([]uuid.UUID, error) {
	if count <= 0 {
		return nil, nil
	}
	key := d.deckKey(userID)

	// LPop with count
	vals, err := d.rdb.LPopCount(ctx, key, count).Result()
	if err != nil {
		if err == redis.Nil {
			return nil, nil
		}
		return nil, err
	}

	if len(vals) > 0 {
		DeckPopsTotal.Add(float64(len(vals)))
	}

	results := make([]uuid.UUID, 0, len(vals))
	for _, v := range vals {
		id, err := uuid.Parse(v)
		if err == nil {
			results = append(results, id)
		}
	}
	return results, nil
}

func (d *redisDeckCache) Push(ctx context.Context, userID uuid.UUID, candidateIDs []uuid.UUID, ttl time.Duration) error {
	if len(candidateIDs) == 0 {
		return nil
	}
	key := d.deckKey(userID)

	members := make([]any, len(candidateIDs))
	for i, id := range candidateIDs {
		members[i] = id.String()
	}

	if ttl <= 0 {
		ttl = defaultDeckTTL
	}
	jitteredTTL := Jitter(ttl, 0.15)

	pipe := d.rdb.Pipeline()
	pipe.RPush(ctx, key, members...)
	pipe.Expire(ctx, key, jitteredTTL)
	_, err := pipe.Exec(ctx)
	if err == nil {
		DeckRefillsTotal.Inc()
	}
	return err
}

func (d *redisDeckCache) Len(ctx context.Context, userID uuid.UUID) (int64, error) {
	key := d.deckKey(userID)
	return d.rdb.LLen(ctx, key).Result()
}

func (d *redisDeckCache) Clear(ctx context.Context, userID uuid.UUID) error {
	key := d.deckKey(userID)
	return d.rdb.Del(ctx, key).Err()
}
