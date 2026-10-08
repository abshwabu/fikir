package cache_test

import (
	"context"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/alicebob/miniredis/v2"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/abshwabu/fikir/backend/internal/cache"
	"github.com/abshwabu/fikir/backend/internal/domain"
)

func setupTestRedis(t *testing.T) (*miniredis.Miniredis, *redis.Client) {
	mr, err := miniredis.Run()
	require.NoError(t, err)
	t.Cleanup(func() {
		mr.Close()
	})

	rdb := redis.NewClient(&redis.Options{
		Addr: mr.Addr(),
	})
	t.Cleanup(func() {
		_ = rdb.Close()
	})

	return mr, rdb
}

func TestJitter(t *testing.T) {
	base := 10 * time.Minute
	variance := 0.15

	for i := 0; i < 20; i++ {
		j := cache.Jitter(base, variance)
		assert.GreaterOrEqual(t, j, 8*time.Minute+30*time.Second)
		assert.LessOrEqual(t, j, 11*time.Minute+30*time.Second)
	}
}

func TestCardCache_GetWithSingleflight(t *testing.T) {
	_, rdb := setupTestRedis(t)
	cardCache := cache.NewProfileCardCache(rdb)
	ctx := context.Background()

	targetID := uuid.New()
	var fetchCount int32

	fetchFn := func() (*domain.ProfileCard, error) {
		atomic.AddInt32(&fetchCount, 1)
		time.Sleep(50 * time.Millisecond) // Simulate slow DB fetch
		return &domain.ProfileCard{
			UserID:      targetID,
			DisplayName: "Bethlehem",
			Age:         24,
			Gender:      "female",
		}, nil
	}

	// 10 concurrent requests for the exact same card
	var wg sync.WaitGroup
	cards := make([]*domain.ProfileCard, 10)
	for i := 0; i < 10; i++ {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()
			c, err := cardCache.Get(ctx, targetID, "", fetchFn)
			assert.NoError(t, err)
			cards[idx] = c
		}(i)
	}

	wg.Wait()

	// Singleflight must ensure fetchFn was called only once despite 10 concurrent requests
	assert.Equal(t, int32(1), atomic.LoadInt32(&fetchCount))
	for _, c := range cards {
		assert.NotNil(t, c)
		assert.Equal(t, "Bethlehem", c.DisplayName)
	}

	// Invalidation test
	err := cardCache.Invalidate(ctx, targetID)
	require.NoError(t, err)

	// Fetch again after invalidation triggers fetchFn once more
	_, err = cardCache.Get(ctx, targetID, "", fetchFn)
	require.NoError(t, err)
	assert.Equal(t, int32(2), atomic.LoadInt32(&fetchCount))
}

func TestSwipeCache_DailyLikeLimit(t *testing.T) {
	_, rdb := setupTestRedis(t)
	swipeCache := cache.NewSwipeCache(rdb)
	ctx := context.Background()

	userID := uuid.New()
	limit := 3
	window := 12 * time.Hour

	// 1st like
	ok, rem, _, err := swipeCache.CheckAndIncrLikeCount(ctx, userID, false, limit, window)
	require.NoError(t, err)
	assert.True(t, ok)
	assert.Equal(t, 2, rem)

	// 2nd like
	ok, rem, _, err = swipeCache.CheckAndIncrLikeCount(ctx, userID, false, limit, window)
	require.NoError(t, err)
	assert.True(t, ok)
	assert.Equal(t, 1, rem)

	// 3rd like
	ok, rem, _, err = swipeCache.CheckAndIncrLikeCount(ctx, userID, false, limit, window)
	require.NoError(t, err)
	assert.True(t, ok)
	assert.Equal(t, 0, rem)

	// 4th like (exceeds limit)
	ok, rem, resetAt, err := swipeCache.CheckAndIncrLikeCount(ctx, userID, false, limit, window)
	require.NoError(t, err)
	assert.False(t, ok)
	assert.Equal(t, 0, rem)
	assert.False(t, resetAt.IsZero())

	// Premium user always allowed
	ok, _, _, err = swipeCache.CheckAndIncrLikeCount(ctx, userID, true, limit, window)
	require.NoError(t, err)
	assert.True(t, ok)
}

func TestDeckCache_PopAndPush(t *testing.T) {
	_, rdb := setupTestRedis(t)
	deckCache := cache.NewDeckCache(rdb)
	ctx := context.Background()

	userID := uuid.New()
	ids := []uuid.UUID{uuid.New(), uuid.New(), uuid.New(), uuid.New(), uuid.New()}

	err := deckCache.Push(ctx, userID, ids, 15*time.Minute)
	require.NoError(t, err)

	l, err := deckCache.Len(ctx, userID)
	require.NoError(t, err)
	assert.Equal(t, int64(5), l)

	popped, err := deckCache.Pop(ctx, userID, 2)
	require.NoError(t, err)
	assert.Len(t, popped, 2)
	assert.Equal(t, ids[0], popped[0])
	assert.Equal(t, ids[1], popped[1])

	rem, err := deckCache.Len(ctx, userID)
	require.NoError(t, err)
	assert.Equal(t, int64(3), rem)
}
