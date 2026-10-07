package ws

import (
	"sync"
)

// Hub maintains active client connections and broadcasts messages
type Hub struct {
	clients    map[string]bool
	broadcast  chan []byte
	register   chan string
	unregister chan string
	mu         sync.RWMutex
}

// NewHub creates a new WebSocket Hub
func NewHub() *Hub {
	return &Hub{
		clients:    make(map[string]bool),
		broadcast:  make(chan []byte),
		register:   make(chan string),
		unregister: make(chan string),
	}
}

// Run executes the hub event loop
func (h *Hub) Run() {
	for {
		select {
		case clientID := <-h.register:
			h.mu.Lock()
			h.clients[clientID] = true
			h.mu.Unlock()

		case clientID := <-h.unregister:
			h.mu.Lock()
			delete(h.clients, clientID)
			h.mu.Unlock()

		case message := <-h.broadcast:
			_ = message
			// Broadcast distribution logic for later prompts
		}
	}
}
