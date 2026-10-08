package handler

import (
	"context"
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/rs/zerolog/log"
	"nhooyr.io/websocket"

	"github.com/abshwabu/fikir/backend/internal/cache"
	"github.com/abshwabu/fikir/backend/internal/domain"
	"github.com/abshwabu/fikir/backend/internal/http/middleware"
	"github.com/abshwabu/fikir/backend/internal/http/response"
	apperrors "github.com/abshwabu/fikir/backend/internal/platform/errors"
	"github.com/abshwabu/fikir/backend/internal/service"
	"github.com/abshwabu/fikir/backend/internal/ws"
)

type ChatHandler struct {
	chatService service.ChatService
	chatCache   cache.ChatCache
	hub         *ws.Hub
}

func NewChatHandler(chatService service.ChatService, chatCache cache.ChatCache, hub *ws.Hub) *ChatHandler {
	return &ChatHandler{
		chatService: chatService,
		chatCache:   chatCache,
		hub:         hub,
	}
}

// RequestWSTicket generates a one-time ticket for WebSocket connection
func (h *ChatHandler) RequestWSTicket(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		response.Error(w, apperrors.Unauthorized("authentication required"))
		return
	}

	ticket, err := h.chatService.CreateWSTicket(r.Context(), userID)
	if err != nil {
		response.Error(w, err)
		return
	}

	response.OK(w, map[string]any{
		"ticket":             ticket,
		"expires_in_seconds": 60,
	})
}

// ServeWS upgrades the HTTP request to WebSocket after validating the ticket
func (h *ChatHandler) ServeWS(w http.ResponseWriter, r *http.Request) {
	ticket := r.URL.Query().Get("ticket")
	if ticket == "" {
		ticket = r.Header.Get("Sec-WebSocket-Protocol")
	}

	if ticket == "" {
		response.Error(w, apperrors.Unauthorized("missing WebSocket ticket"))
		return
	}

	userID, err := h.chatCache.ConsumeWSTicket(r.Context(), ticket)
	if err != nil {
		response.Error(w, apperrors.Unauthorized("invalid or expired WebSocket ticket"))
		return
	}

	conn, err := websocket.Accept(w, r, &websocket.AcceptOptions{
		OriginPatterns: []string{"*"},
	})
	if err != nil {
		log.Error().Err(err).Msg("Failed to accept WebSocket connection")
		return
	}

	client := ws.NewClient(h.hub, userID, conn, h.chatService)
	h.hub.Register(r.Context(), client)

	defer func() {
		h.hub.Unregister(r.Context(), client)
		_ = conn.Close(websocket.StatusNormalClosure, "disconnect")
	}()

	ctx, cancel := context.WithCancel(r.Context())
	defer cancel()

	go client.WritePump(ctx)
	client.ReadPump(ctx)
}

type SendMessageHTTPReq struct {
	Body        string         `json:"body"`
	Type        string         `json:"type"`
	ClientMsgID string         `json:"client_msg_id"`
	MediaURL    string         `json:"media_url"`
	Metadata    map[string]any `json:"metadata"`
}

// SendMessage provides REST fallback for sending a message
func (h *ChatHandler) SendMessage(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		response.Error(w, apperrors.Unauthorized("authentication required"))
		return
	}

	matchIDStr := chi.URLParam(r, "id")
	matchID, err := uuid.Parse(matchIDStr)
	if err != nil {
		response.Error(w, apperrors.BadRequest("invalid match id"))
		return
	}

	var req SendMessageHTTPReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, apperrors.BadRequest("invalid request payload"))
		return
	}

	msg, err := h.chatService.SendMessage(r.Context(), service.SendMessageRequest{
		MatchID:     matchID,
		SenderID:    userID,
		Body:        req.Body,
		Type:        req.Type,
		ClientMsgID: req.ClientMsgID,
		MediaURL:    req.MediaURL,
		Metadata:    req.Metadata,
	})
	if err != nil {
		response.Error(w, err)
		return
	}

	response.Created(w, msg)
}

// GetMessages lists messages for replay or chat history
func (h *ChatHandler) GetMessages(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		response.Error(w, apperrors.Unauthorized("authentication required"))
		return
	}

	matchIDStr := chi.URLParam(r, "id")
	matchID, err := uuid.Parse(matchIDStr)
	if err != nil {
		response.Error(w, apperrors.BadRequest("invalid match id"))
		return
	}

	var afterID int64
	if s := r.URL.Query().Get("after_id"); s != "" {
		if id, err := strconv.ParseInt(s, 10, 64); err == nil {
			afterID = id
		}
	}

	var beforeID int64
	if s := r.URL.Query().Get("before_id"); s != "" {
		if id, err := strconv.ParseInt(s, 10, 64); err == nil {
			beforeID = id
		}
	}

	limit := 30
	if s := r.URL.Query().Get("limit"); s != "" {
		if l, err := strconv.Atoi(s); err == nil && l > 0 {
			limit = l
		}
	}

	messages, err := h.chatService.GetMessages(r.Context(), userID, matchID, afterID, beforeID, limit)
	if err != nil {
		response.Error(w, err)
		return
	}

	response.OK(w, map[string]any{
		"messages": messages,
		"count":    len(messages),
	})
}

type MarkReadReq struct {
	UpToID int64 `json:"up_to_id"`
}

// MarkRead marks messages in a match as read
func (h *ChatHandler) MarkRead(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		response.Error(w, apperrors.Unauthorized("authentication required"))
		return
	}

	matchIDStr := chi.URLParam(r, "id")
	matchID, err := uuid.Parse(matchIDStr)
	if err != nil {
		response.Error(w, apperrors.BadRequest("invalid match id"))
		return
	}

	var req MarkReadReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, apperrors.BadRequest("invalid request payload"))
		return
	}

	if err := h.chatService.MarkAsRead(r.Context(), userID, matchID, req.UpToID); err != nil {
		response.Error(w, err)
		return
	}

	response.OK(w, map[string]bool{"success": true})
}

type MediaUploadReq struct {
	MediaType   string `json:"media_type"`
	ContentType string `json:"content_type"`
	SizeBytes   int64  `json:"size_bytes"`
}

// RequestMediaUploadURL generates a presigned URL for audio/image attachments
func (h *ChatHandler) RequestMediaUploadURL(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		response.Error(w, apperrors.Unauthorized("authentication required"))
		return
	}

	matchIDStr := chi.URLParam(r, "id")
	matchID, err := uuid.Parse(matchIDStr)
	if err != nil {
		response.Error(w, apperrors.BadRequest("invalid match id"))
		return
	}

	var req MediaUploadReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, apperrors.BadRequest("invalid request payload"))
		return
	}

	upload, err := h.chatService.CreateMediaUploadURL(r.Context(), userID, matchID, req.ContentType, req.MediaType, req.SizeBytes)
	if err != nil {
		response.Error(w, err)
		return
	}

	response.Created(w, upload)
}

type RegisterDeviceReq struct {
	FCMToken string `json:"fcm_token"`
	Platform string `json:"platform"`
}

// RegisterDevice registers a push token
func (h *ChatHandler) RegisterDevice(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		response.Error(w, apperrors.Unauthorized("authentication required"))
		return
	}

	var req RegisterDeviceReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, apperrors.BadRequest("invalid request payload"))
		return
	}

	if err := h.chatService.RegisterDevice(r.Context(), userID, req.FCMToken, req.Platform); err != nil {
		response.Error(w, err)
		return
	}

	response.OK(w, map[string]bool{"success": true})
}

// UnregisterDevice deletes a push token
func (h *ChatHandler) UnregisterDevice(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		response.Error(w, apperrors.Unauthorized("authentication required"))
		return
	}

	token := chi.URLParam(r, "token")
	if token == "" {
		response.Error(w, apperrors.BadRequest("token path parameter required"))
		return
	}

	if err := h.chatService.UnregisterDevice(r.Context(), userID, token); err != nil {
		response.Error(w, err)
		return
	}

	response.OK(w, map[string]bool{"success": true})
}

// GetNotificationSettings retrieves user's notification preferences
func (h *ChatHandler) GetNotificationSettings(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		response.Error(w, apperrors.Unauthorized("authentication required"))
		return
	}

	settings, locale, err := h.chatService.GetNotificationSettings(r.Context(), userID)
	if err != nil {
		response.Error(w, err)
		return
	}

	response.OK(w, map[string]any{
		"settings": settings,
		"locale":   locale,
	})
}

// UpdateNotificationSettings modifies user's notification preferences
func (h *ChatHandler) UpdateNotificationSettings(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		response.Error(w, apperrors.Unauthorized("authentication required"))
		return
	}

	var settings domain.NotificationSettings
	if err := json.NewDecoder(r.Body).Decode(&settings); err != nil {
		response.Error(w, apperrors.BadRequest("invalid request payload"))
		return
	}

	if err := h.chatService.UpdateNotificationSettings(r.Context(), userID, &settings); err != nil {
		response.Error(w, err)
		return
	}

	response.OK(w, settings)
}
