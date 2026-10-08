package ws

import (
	"context"
	"encoding/json"
	"time"

	"github.com/google/uuid"
	"github.com/rs/zerolog/log"
	"nhooyr.io/websocket"

	"github.com/abshwabu/fikir/backend/internal/domain"
	"github.com/abshwabu/fikir/backend/internal/service"
)

const (
	writeWait  = 10 * time.Second
	pingPeriod = 30 * time.Second
	maxMsgSize = 64 * 1024 // 64 KB
)

// Client represents a single active WebSocket connection
type Client struct {
	hub         *Hub
	userID      uuid.UUID
	conn        *websocket.Conn
	send        chan []byte
	chatService service.ChatService
}

func NewClient(hub *Hub, userID uuid.UUID, conn *websocket.Conn, chatService service.ChatService) *Client {
	return &Client{
		hub:         hub,
		userID:      userID,
		conn:        conn,
		send:        make(chan []byte, 256),
		chatService: chatService,
	}
}

func (c *Client) Send(data []byte) {
	select {
	case c.send <- data:
	default:
		log.Warn().Str("user_id", c.userID.String()).Msg("WebSocket send buffer full; dropping frame")
	}
}

func (c *Client) SendFrame(frame domain.WSFrame) {
	bytes, err := json.Marshal(frame)
	if err != nil {
		log.Error().Err(err).Msg("Failed to marshal WSFrame")
		return
	}
	c.Send(bytes)
}

// ReadPump listens for incoming frames from the WebSocket connection
func (c *Client) ReadPump(ctx context.Context) {
	c.conn.SetReadLimit(maxMsgSize)

	for {
		_, data, err := c.conn.Read(ctx)
		if err != nil {
			if websocket.CloseStatus(err) != websocket.StatusNormalClosure &&
				websocket.CloseStatus(err) != websocket.StatusGoingAway {
				log.Debug().Err(err).Str("user_id", c.userID.String()).Msg("WebSocket read closed")
			}
			break
		}

		var frame domain.WSFrame
		if err := json.Unmarshal(data, &frame); err != nil {
			c.SendFrame(domain.WSFrame{
				Type:  domain.FrameTypeError,
				Error: "invalid frame payload",
			})
			continue
		}

		c.handleFrame(ctx, frame)
	}
}

func (c *Client) handleFrame(ctx context.Context, frame domain.WSFrame) {
	switch frame.Type {
	case domain.FrameTypePing:
		c.SendFrame(domain.WSFrame{Type: domain.FrameTypePong})

	case domain.FrameTypePresence:
		c.SendFrame(domain.WSFrame{
			Type:   domain.FrameTypePresence,
			Status: "online",
		})

	case domain.FrameTypeMessageSend:
		if frame.MatchID == nil {
			c.SendFrame(domain.WSFrame{
				Type:        domain.FrameTypeError,
				ClientMsgID: frame.ClientMsgID,
				Error:       "match_id is required",
			})
			return
		}

		msg, err := c.chatService.SendMessage(ctx, service.SendMessageRequest{
			MatchID:     *frame.MatchID,
			SenderID:    c.userID,
			Body:        frame.Body,
			Type:        frame.MsgType,
			ClientMsgID: frame.ClientMsgID,
			MediaURL:    frame.MediaURL,
			Metadata:    frame.Metadata,
		})
		if err != nil {
			c.SendFrame(domain.WSFrame{
				Type:        domain.FrameTypeError,
				ClientMsgID: frame.ClientMsgID,
				Error:       err.Error(),
			})
			return
		}

		// Acknowledge send to caller
		c.SendFrame(domain.WSFrame{
			Type:         domain.FrameTypeMessageAck,
			ClientMsgID:  msg.ClientMsgID,
			MatchID:      &msg.MatchID,
			MessageID:    msg.ID,
			Status:       "sent",
			WarningFlags: msg.WarningFlags,
			CreatedAt:    msg.CreatedAt,
		})

	case domain.FrameTypeTyping:
		if frame.MatchID != nil {
			_ = c.chatService.HandleTyping(ctx, c.userID, *frame.MatchID, frame.IsTyping)
		}

	case domain.FrameTypeRead:
		if frame.MatchID != nil {
			_ = c.chatService.MarkAsRead(ctx, c.userID, *frame.MatchID, frame.UpToID)
		}

	default:
		log.Debug().Str("type", frame.Type).Msg("Unhandled WS frame type received")
	}
}

// WritePump pushes frames from the send channel to the WebSocket connection
func (c *Client) WritePump(ctx context.Context) {
	ticker := time.NewTicker(pingPeriod)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return

		case msg, ok := <-c.send:
			if !ok {
				_ = c.conn.Close(websocket.StatusNormalClosure, "")
				return
			}

			writeCtx, cancel := context.WithTimeout(ctx, writeWait)
			err := c.conn.Write(writeCtx, websocket.MessageText, msg)
			cancel()
			if err != nil {
				log.Debug().Err(err).Str("user_id", c.userID.String()).Msg("WebSocket write error")
				return
			}

		case <-ticker.C:
			writeCtx, cancel := context.WithTimeout(ctx, writeWait)
			err := c.conn.Ping(writeCtx)
			cancel()
			if err != nil {
				log.Debug().Err(err).Str("user_id", c.userID.String()).Msg("WebSocket ping failed")
				return
			}
		}
	}
}
