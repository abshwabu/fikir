package cache

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
	"golang.org/x/sync/singleflight"
)

var ErrNotFound = errors.New("cache: key not found")

// Cache wraps redis.Client and provides typed JSON operations and singleflight deduplication
type Cache struct {
	client *redis.Client
	sf     singleflight.Group
}

// New constructs a new Cache instance
func New(client *redis.Client) *Cache {
	return &Cache{
		client: client,
	}
}

// Client returns the underlying redis.Client
func (c *Cache) Client() *redis.Client {
	return c.client
}

// GetJSON retrieves a JSON-serialized object from Redis
func (c *Cache) GetJSON(ctx context.Context, key string, target any) error {
	data, err := c.client.Get(ctx, key).Bytes()
	if err != nil {
		if errors.Is(err, redis.Nil) {
			return ErrNotFound
		}
		return fmt.Errorf("redis get error for key %s: %w", key, err)
	}

	if err := json.Unmarshal(data, target); err != nil {
		return fmt.Errorf("failed to unmarshal cache data for key %s: %w", key, err)
	}

	return nil
}

// SetJSON serializes value to JSON and stores it in Redis with given expiration
func (c *Cache) SetJSON(ctx context.Context, key string, value any, expiration time.Duration) error {
	bytes, err := json.Marshal(value)
	if err != nil {
		return fmt.Errorf("failed to marshal cache data for key %s: %w", key, err)
	}

	if err := c.client.Set(ctx, key, bytes, expiration).Err(); err != nil {
		return fmt.Errorf("redis set error for key %s: %w", key, err)
	}

	return nil
}

// Delete removes one or more keys from Redis
func (c *Cache) Delete(ctx context.Context, keys ...string) error {
	return c.client.Del(ctx, keys...).Err()
}

// GetOrSet fetches a value from cache or executes fetchFn using singleflight to prevent stampedes
func (c *Cache) GetOrSet(ctx context.Context, key string, target any, expiration time.Duration, fetchFn func() (any, error)) error {
	// 1. Try cache hit
	err := c.GetJSON(ctx, key, target)
	if err == nil {
		return nil
	}

	// 2. Cache miss -> singleflight fetch
	res, sfErr, _ := c.sf.Do(key, func() (any, error) {
		val, err := fetchFn()
		if err != nil {
			return nil, err
		}
		_ = c.SetJSON(ctx, key, val, expiration)
		return val, nil
	})

	if sfErr != nil {
		return sfErr
	}

	// 3. Serialize and unmarshal result to target
	bytes, err := json.Marshal(res)
	if err != nil {
		return err
	}
	return json.Unmarshal(bytes, target)
}
