package ws

import (
	"context"
	"strings"
	"sync"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	"github.com/rs/zerolog/log"

	"github.com/abshwabu/fikir/backend/internal/cache"
)

// Hub coordinates local WebSocket connections and Redis Pub/Sub multi-node fanout
type Hub struct {
	nodeID     string
	rdb        redis.UniversalClient
	chatCache  cache.ChatCache
	clients    map[uuid.UUID]map[*Client]bool
	clientsMu  sync.RWMutex
	cancel     context.CancelFunc
	pubsubDone chan struct{}
}

func NewHub(nodeID string, rdb redis.UniversalClient, chatCache cache.ChatCache) *Hub {
	if nodeID == "" {
		nodeID = uuid.New().String()
	}
	return &Hub{
		nodeID:     nodeID,
		rdb:        rdb,
		chatCache:  chatCache,
		clients:    make(map[uuid.UUID]map[*Client]bool),
		pubsubDone: make(chan struct{}),
	}
}

func (h *Hub) NodeID() string {
	return h.nodeID
}

// Start launches the Redis Pub/Sub subscriber listening to chat:user:* channels
func (h *Hub) Start(ctx context.Context) {
	subCtx, cancel := context.WithCancel(ctx)
	h.cancel = cancel

	pubsub := h.rdb.PSubscribe(subCtx, "chat:user:*")

	go func() {
		defer func() {
			_ = pubsub.Close()
			close(h.pubsubDone)
		}()

		ch := pubsub.Channel()
		for {
			select {
			case <-subCtx.Done():
				return
			case msg, ok := <-ch:
				if !ok {
					return
				}
				// Channel format: chat:user:<uuid>
				parts := strings.Split(msg.Channel, ":")
				if len(parts) != 3 {
					continue
				}
				targetID, err := uuid.Parse(parts[2])
				if err != nil {
					continue
				}

				h.BroadcastToUser(targetID, []byte(msg.Payload))
			}
		}
	}()
}

// Stop cleanly terminates the hub background listeners
func (h *Hub) Stop() {
	if h.cancel != nil {
		h.cancel()
	}
	<-h.pubsubDone
}

// Register registers a new client connection on this node
func (h *Hub) Register(ctx context.Context, c *Client) {
	h.clientsMu.Lock()
	conns, exists := h.clients[c.userID]
	if !exists {
		conns = make(map[*Client]bool)
		h.clients[c.userID] = conns
	}
	conns[c] = true
	h.clientsMu.Unlock()

	// Update presence in Redis cluster
	if h.chatCache != nil {
		_ = h.chatCache.RegisterPresence(ctx, c.userID, h.nodeID)
	}

	log.Debug().
		Str("node_id", h.nodeID).
		Str("user_id", c.userID.String()).
		Msg("WebSocket client registered on hub")
}

// Unregister removes a client connection from this node
func (h *Hub) Unregister(ctx context.Context, c *Client) {
	h.clientsMu.Lock()
	if conns, ok := h.clients[c.userID]; ok {
		delete(conns, c)
		if len(conns) == 0 {
			delete(h.clients, c.userID)
		}
	}
	h.clientsMu.Unlock()

	// Update presence in Redis cluster
	if h.chatCache != nil {
		_ = h.chatCache.UnregisterPresence(ctx, c.userID, h.nodeID)
	}

	log.Debug().
		Str("node_id", h.nodeID).
		Str("user_id", c.userID.String()).
		Msg("WebSocket client unregistered from hub")
}

// BroadcastToUser delivers a payload to all connections of a specific user on this node
func (h *Hub) BroadcastToUser(userID uuid.UUID, data []byte) {
	h.clientsMu.RLock()
	defer h.clientsMu.RUnlock()

	conns, exists := h.clients[userID]
	if !exists || len(conns) == 0 {
		return
	}

	for client := range conns {
		client.Send(data)
	}
}

// ConnectedUserCount returns the count of unique users connected locally
func (h *Hub) ConnectedUserCount() int {
	h.clientsMu.RLock()
	defer h.clientsMu.RUnlock()
	return len(h.clients)
}
