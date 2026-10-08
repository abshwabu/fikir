package cache

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
)

const (
	ticketTTL        = 60 * time.Second
	dedupeTTL        = 10 * time.Minute
	presenceTTL      = 24 * time.Hour
	typingTTL        = 5 * time.Second
	defaultChatLimit = 30
	defaultChatWin   = 1 * time.Minute
)

// ChatCache defines Redis caching and coordination operations for chat and WebSocket
type ChatCache interface {
	CreateWSTicket(ctx context.Context, userID uuid.UUID) (string, error)
	ConsumeWSTicket(ctx context.Context, ticket string) (uuid.UUID, error)

	CheckAndSetDedupe(ctx context.Context, userID uuid.UUID, clientMsgID string) (bool, error)

	IncrUnread(ctx context.Context, userID, matchID uuid.UUID) (int64, error)
	ResetUnread(ctx context.Context, userID, matchID uuid.UUID) error
	GetUnread(ctx context.Context, userID, matchID uuid.UUID) (int64, error)

	RegisterPresence(ctx context.Context, userID uuid.UUID, nodeID string) error
	UnregisterPresence(ctx context.Context, userID uuid.UUID, nodeID string) error
	IsUserOnline(ctx context.Context, userID uuid.UUID) (bool, error)

	CheckChatRateLimit(ctx context.Context, userID uuid.UUID, limit int, window time.Duration) (bool, error)
}

type redisChatCache struct {
	rdb redis.UniversalClient
}

func NewChatCache(rdb redis.UniversalClient) ChatCache {
	return &redisChatCache{
		rdb: rdb,
	}
}

// CreateWSTicket generates a secure random ticket stored in Redis with 60s TTL
func (c *redisChatCache) CreateWSTicket(ctx context.Context, userID uuid.UUID) (string, error) {
	bytes := make([]byte, 24)
	if _, err := rand.Read(bytes); err != nil {
		return "", fmt.Errorf("failed to generate ticket entropy: %w", err)
	}
	ticket := hex.EncodeToString(bytes)

	key := fmt.Sprintf("ws:ticket:%s", ticket)
	err := c.rdb.Set(ctx, key, userID.String(), ticketTTL).Err()
	if err != nil {
		return "", fmt.Errorf("failed to save ws ticket: %w", err)
	}

	return ticket, nil
}

// ConsumeWSTicket atomically validates and deletes the ticket to prevent replay
func (c *redisChatCache) ConsumeWSTicket(ctx context.Context, ticket string) (uuid.UUID, error) {
	if ticket == "" {
		return uuid.Nil, errors.New("empty ticket")
	}

	key := fmt.Sprintf("ws:ticket:%s", ticket)
	// Atomic Get and Del
	val, err := c.rdb.GetDel(ctx, key).Result()
	if err != nil {
		if errors.Is(err, redis.Nil) {
			return uuid.Nil, errors.New("invalid or expired ticket")
		}
		return uuid.Nil, err
	}

	userID, err := uuid.Parse(val)
	if err != nil {
		return uuid.Nil, errors.New("corrupted ticket payload")
	}

	return userID, nil
}

// CheckAndSetDedupe checks if client_msg_id was already processed in the last 10 minutes
func (c *redisChatCache) CheckAndSetDedupe(ctx context.Context, userID uuid.UUID, clientMsgID string) (bool, error) {
	if clientMsgID == "" {
		return true, nil
	}

	key := fmt.Sprintf("msg:dedupe:%s:%s", userID.String(), clientMsgID)
	// SetNX returns true if the key was set (i.e. is new, not duplicate)
	isNew, err := c.rdb.SetNX(ctx, key, "1", dedupeTTL).Result()
	if err != nil {
		return true, err
	}

	return isNew, nil
}

// IncrUnread increments unread counter for a user in a specific match
func (c *redisChatCache) IncrUnread(ctx context.Context, userID, matchID uuid.UUID) (int64, error) {
	key := fmt.Sprintf("unread:%s:%s", userID.String(), matchID.String())
	return c.rdb.Incr(ctx, key).Result()
}

// ResetUnread resets unread counter for a user in a specific match
func (c *redisChatCache) ResetUnread(ctx context.Context, userID, matchID uuid.UUID) error {
	key := fmt.Sprintf("unread:%s:%s", userID.String(), matchID.String())
	return c.rdb.Del(ctx, key).Err()
}

// GetUnread retrieves current unread count
func (c *redisChatCache) GetUnread(ctx context.Context, userID, matchID uuid.UUID) (int64, error) {
	key := fmt.Sprintf("unread:%s:%s", userID.String(), matchID.String())
	cnt, err := c.rdb.Get(ctx, key).Int64()
	if err != nil {
		if errors.Is(err, redis.Nil) {
			return 0, nil
		}
		return 0, err
	}
	return cnt, nil
}

// RegisterPresence marks user online on a given cluster node
func (c *redisChatCache) RegisterPresence(ctx context.Context, userID uuid.UUID, nodeID string) error {
	connKey := fmt.Sprintf("presence:conn:%s", userID.String())
	nodeKey := fmt.Sprintf("presence:nodes:%s", userID.String())

	pipe := c.rdb.Pipeline()
	pipe.Incr(ctx, connKey)
	pipe.Expire(ctx, connKey, presenceTTL)
	pipe.SAdd(ctx, nodeKey, nodeID)
	pipe.Expire(ctx, nodeKey, presenceTTL)
	_, err := pipe.Exec(ctx)
	return err
}

// UnregisterPresence decrements connection count and cleans up if 0
func (c *redisChatCache) UnregisterPresence(ctx context.Context, userID uuid.UUID, nodeID string) error {
	connKey := fmt.Sprintf("presence:conn:%s", userID.String())
	nodeKey := fmt.Sprintf("presence:nodes:%s", userID.String())

	cnt, err := c.rdb.Decr(ctx, connKey).Result()
	if err != nil && !errors.Is(err, redis.Nil) {
		return err
	}

	if cnt <= 0 {
		pipe := c.rdb.Pipeline()
		pipe.Del(ctx, connKey)
		pipe.Del(ctx, nodeKey)
		_, _ = pipe.Exec(ctx)
	}

	return nil
}

// IsUserOnline checks if the user has any active WebSocket connection across all nodes
func (c *redisChatCache) IsUserOnline(ctx context.Context, userID uuid.UUID) (bool, error) {
	connKey := fmt.Sprintf("presence:conn:%s", userID.String())
	cnt, err := c.rdb.Get(ctx, connKey).Int64()
	if err != nil {
		if errors.Is(err, redis.Nil) {
			return false, nil
		}
		return false, err
	}
	return cnt > 0, nil
}

// CheckChatRateLimit enforces rate limit (e.g. 30 messages per minute)
func (c *redisChatCache) CheckChatRateLimit(ctx context.Context, userID uuid.UUID, limit int, window time.Duration) (bool, error) {
	if limit <= 0 {
		limit = defaultChatLimit
	}
	if window <= 0 {
		window = defaultChatWin
	}

	key := fmt.Sprintf("rate:chat:%s", userID.String())
	cnt, err := c.rdb.Incr(ctx, key).Result()
	if err != nil {
		return true, err
	}

	if cnt == 1 {
		_ = c.rdb.Expire(ctx, key, window).Err()
	}

	return int(cnt) <= limit, nil
}
