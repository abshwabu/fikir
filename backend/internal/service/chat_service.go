package service

import (
	"context"
	"encoding/json"
	"fmt"
	"path/filepath"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	"github.com/rs/zerolog/log"

	"github.com/abshwabu/fikir/backend/internal/cache"
	"github.com/abshwabu/fikir/backend/internal/config"
	"github.com/abshwabu/fikir/backend/internal/domain"
	apperrors "github.com/abshwabu/fikir/backend/internal/platform/errors"
	"github.com/abshwabu/fikir/backend/internal/platform/safety"
	"github.com/abshwabu/fikir/backend/internal/queue"
	"github.com/abshwabu/fikir/backend/internal/storage"
)

type SendMessageRequest struct {
	MatchID     uuid.UUID      `json:"match_id"`
	SenderID    uuid.UUID      `json:"sender_id"`
	Body        string         `json:"body"`
	Type        string         `json:"type"`
	ClientMsgID string         `json:"client_msg_id"`
	MediaURL    string         `json:"media_url"`
	Metadata    map[string]any `json:"metadata"`
}

type MediaUploadResponse struct {
	UploadURL string `json:"upload_url"`
	MediaURL  string `json:"media_url"`
	MediaType string `json:"media_type"`
}

type ChatService interface {
	CreateWSTicket(ctx context.Context, userID uuid.UUID) (string, error)
	SendMessage(ctx context.Context, req SendMessageRequest) (*domain.Message, error)
	GetMessages(ctx context.Context, userID, matchID uuid.UUID, afterID, beforeID int64, limit int) ([]domain.Message, error)
	MarkAsRead(ctx context.Context, userID, matchID uuid.UUID, upToID int64) error
	HandleTyping(ctx context.Context, userID, matchID uuid.UUID, isTyping bool) error
	CreateMediaUploadURL(ctx context.Context, userID, matchID uuid.UUID, contentType, mediaType string, sizeBytes int64) (*MediaUploadResponse, error)

	RegisterDevice(ctx context.Context, userID uuid.UUID, fcmToken, platform string) error
	UnregisterDevice(ctx context.Context, userID uuid.UUID, fcmToken string) error
	GetNotificationSettings(ctx context.Context, userID uuid.UUID) (*domain.NotificationSettings, string, error)
	UpdateNotificationSettings(ctx context.Context, userID uuid.UUID, settings *domain.NotificationSettings) error

	PublishFrame(ctx context.Context, targetUserID uuid.UUID, frame *domain.WSFrame) error
}

type chatService struct {
	cfg            config.ChatConfig
	cdnBaseURL     string
	chatRepo       domain.ChatRepository
	blockRepo      domain.BlockRepository
	profileRepo    domain.ProfileRepository
	deviceRepo     domain.DeviceRepository
	notifRepo      domain.NotificationRepository
	chatCache      cache.ChatCache
	storageClient  *storage.Storage
	queueClient    *queue.Client
	rdb            redis.UniversalClient
	safetyAnalyzer safety.SafetyAnalyzer
}

func NewChatService(
	cfg config.ChatConfig,
	cdnBaseURL string,
	chatRepo domain.ChatRepository,
	blockRepo domain.BlockRepository,
	profileRepo domain.ProfileRepository,
	deviceRepo domain.DeviceRepository,
	notifRepo domain.NotificationRepository,
	chatCache cache.ChatCache,
	storageClient *storage.Storage,
	queueClient *queue.Client,
	rdb redis.UniversalClient,
	safetyAnalyzer safety.SafetyAnalyzer,
) ChatService {
	if safetyAnalyzer == nil {
		safetyAnalyzer = safety.NewSafetyAnalyzer()
	}
	return &chatService{
		cfg:            cfg,
		cdnBaseURL:     cdnBaseURL,
		chatRepo:       chatRepo,
		blockRepo:      blockRepo,
		profileRepo:    profileRepo,
		deviceRepo:     deviceRepo,
		notifRepo:      notifRepo,
		chatCache:      chatCache,
		storageClient:  storageClient,
		queueClient:    queueClient,
		rdb:            rdb,
		safetyAnalyzer: safetyAnalyzer,
	}
}

func (s *chatService) CreateWSTicket(ctx context.Context, userID uuid.UUID) (string, error) {
	return s.chatCache.CreateWSTicket(ctx, userID)
}

func (s *chatService) SendMessage(ctx context.Context, req SendMessageRequest) (*domain.Message, error) {
	// 1. Rate limiting
	allowed, err := s.chatCache.CheckChatRateLimit(ctx, req.SenderID, s.cfg.RateLimitMessages, s.cfg.RateLimitWindow)
	if err != nil {
		log.Warn().Err(err).Msg("Chat rate limit check failed; continuing gracefully")
	} else if !allowed {
		return nil, apperrors.TooManyRequests("chat rate limit exceeded (maximum 30 messages per minute)")
	}

	// 2. Client message deduplication
	if req.ClientMsgID != "" {
		isNew, dErr := s.chatCache.CheckAndSetDedupe(ctx, req.SenderID, req.ClientMsgID)
		if dErr == nil && !isNew {
			// Idempotent hit: retrieve and return previously created message
			existing, getErr := s.chatRepo.GetMessageByClientMsgID(ctx, req.MatchID, req.ClientMsgID)
			if getErr == nil && existing != nil {
				return existing, nil
			}
		}
	}

	// 3. Match participation & block checks
	userA, userB, unmatchedAt, err := s.chatRepo.GetMatchParticipants(ctx, req.MatchID)
	if err != nil {
		return nil, fmt.Errorf("failed to verify match: %w", err)
	}
	if userA == uuid.Nil || unmatchedAt != nil {
		return nil, apperrors.NotFound("match not found or has been unmatched")
	}

	if req.SenderID != userA && req.SenderID != userB {
		return nil, apperrors.Forbidden("user is not a participant in this match")
	}

	recipientID := userB
	if req.SenderID == userB {
		recipientID = userA
	}

	// Block checks both directions
	blocked, err := s.blockRepo.IsBlocked(ctx, req.SenderID, recipientID)
	if err != nil {
		return nil, fmt.Errorf("failed to check block status: %w", err)
	}
	if blocked {
		return nil, apperrors.Forbidden("cannot message blocked user")
	}

	blockedBy, err := s.blockRepo.IsBlocked(ctx, recipientID, req.SenderID)
	if err != nil {
		return nil, fmt.Errorf("failed to check block status: %w", err)
	}
	if blockedBy {
		return nil, apperrors.Forbidden("cannot message user")
	}

	// 4. Safety & Content Moderation
	cleanBody := req.Body
	var warningFlags []string
	if req.Type == "" || req.Type == domain.MessageTypeText {
		req.Type = domain.MessageTypeText
		res, aErr := s.safetyAnalyzer.Analyze(req.Body)
		if aErr != nil {
			return nil, aErr
		}
		cleanBody = res.CleanBody
		warningFlags = res.WarningFlags
	}

	if req.Metadata == nil {
		req.Metadata = make(map[string]any)
	}
	if len(warningFlags) > 0 {
		req.Metadata["warning_flags"] = warningFlags
	}

	// 5. Persistence
	msg := &domain.Message{
		MatchID:      req.MatchID,
		SenderID:     req.SenderID,
		Body:         cleanBody,
		Type:         req.Type,
		ClientMsgID:  req.ClientMsgID,
		MediaURL:     req.MediaURL,
		Metadata:     req.Metadata,
		WarningFlags: warningFlags,
		CreatedAt:    time.Now().UTC(),
	}

	if err := s.chatRepo.CreateMessage(ctx, msg); err != nil {
		return nil, fmt.Errorf("failed to persist message: %w", err)
	}

	_ = s.chatRepo.UpdateMatchLastMessageAt(ctx, req.MatchID, msg.CreatedAt)

	// 6. Redis unread counter
	_, _ = s.chatCache.IncrUnread(ctx, recipientID, req.MatchID)

	// 7. Pub/Sub fan-out to recipient
	outFrame := &domain.WSFrame{
		Type:         domain.FrameTypeMessageNew,
		ClientMsgID:  msg.ClientMsgID,
		MatchID:      &msg.MatchID,
		SenderID:     &msg.SenderID,
		MessageID:    msg.ID,
		Body:         msg.Body,
		MsgType:      msg.Type,
		MediaURL:     msg.MediaURL,
		WarningFlags: msg.WarningFlags,
		Metadata:     msg.Metadata,
		CreatedAt:    msg.CreatedAt,
	}
	_ = s.PublishFrame(ctx, recipientID, outFrame)

	// 8. Offline push notification
	isOnline, _ := s.chatCache.IsUserOnline(ctx, recipientID)
	if !isOnline && s.queueClient != nil {
		settings, _, notifErr := s.notifRepo.GetUserNotificationSettings(ctx, recipientID)
		if notifErr == nil && (settings == nil || settings.NewMessage) {
			senderName := "Someone"
			if senderProfile, pErr := s.profileRepo.GetByUserID(ctx, req.SenderID); pErr == nil && senderProfile != nil {
				if senderProfile.DisplayName != "" {
					senderName = senderProfile.DisplayName
				}
			}

			snippet := msg.Body
			if msg.Type == domain.MessageTypeVoice {
				snippet = "🎤 Voice message"
			} else if msg.Type == domain.MessageTypeImage {
				snippet = "📷 Photo"
			}

			_, _ = s.queueClient.EnqueueChatMessageNotification(ctx, queue.ChatMessageNotificationPayload{
				MessageID:   msg.ID,
				MatchID:     msg.MatchID,
				SenderID:    msg.SenderID,
				RecipientID: recipientID,
				SenderName:  senderName,
				TextSnippet: snippet,
				MsgType:     msg.Type,
			})
		}
	}

	return msg, nil
}

func (s *chatService) GetMessages(ctx context.Context, userID, matchID uuid.UUID, afterID, beforeID int64, limit int) ([]domain.Message, error) {
	// Verify participant
	userA, userB, unmatchedAt, err := s.chatRepo.GetMatchParticipants(ctx, matchID)
	if err != nil {
		return nil, fmt.Errorf("failed to verify match: %w", err)
	}
	if userA == uuid.Nil || unmatchedAt != nil {
		return nil, apperrors.NotFound("match not found or has been unmatched")
	}
	if userID != userA && userID != userB {
		return nil, apperrors.Forbidden("user is not a participant in this match")
	}

	if limit <= 0 {
		limit = 30
	} else if limit > 100 {
		limit = 100
	}

	if afterID > 0 {
		return s.chatRepo.ListMessagesAfter(ctx, matchID, afterID, limit)
	}

	return s.chatRepo.ListMessagesBefore(ctx, matchID, beforeID, limit)
}

func (s *chatService) MarkAsRead(ctx context.Context, userID, matchID uuid.UUID, upToID int64) error {
	userA, userB, unmatchedAt, err := s.chatRepo.GetMatchParticipants(ctx, matchID)
	if err != nil {
		return fmt.Errorf("failed to verify match: %w", err)
	}
	if userA == uuid.Nil || unmatchedAt != nil {
		return apperrors.NotFound("match not found or has been unmatched")
	}
	if userID != userA && userID != userB {
		return apperrors.Forbidden("user is not a participant in this match")
	}

	partnerID := userB
	if userID == userB {
		partnerID = userA
	}

	if err := s.chatRepo.MarkMessagesAsRead(ctx, matchID, userID, upToID); err != nil {
		return fmt.Errorf("failed to mark messages as read: %w", err)
	}

	_ = s.chatCache.ResetUnread(ctx, userID, matchID)

	// Notify partner of read receipt via Pub/Sub
	readFrame := &domain.WSFrame{
		Type:     domain.FrameTypeRead,
		MatchID:  &matchID,
		SenderID: &userID,
		UpToID:   upToID,
	}
	_ = s.PublishFrame(ctx, partnerID, readFrame)

	return nil
}

func (s *chatService) HandleTyping(ctx context.Context, userID, matchID uuid.UUID, isTyping bool) error {
	userA, userB, unmatchedAt, err := s.chatRepo.GetMatchParticipants(ctx, matchID)
	if err != nil {
		return fmt.Errorf("failed to verify match: %w", err)
	}
	if userA == uuid.Nil || unmatchedAt != nil {
		return apperrors.NotFound("match not found or has been unmatched")
	}
	if userID != userA && userID != userB {
		return apperrors.Forbidden("user is not a participant in this match")
	}

	partnerID := userB
	if userID == userB {
		partnerID = userA
	}

	frame := &domain.WSFrame{
		Type:     domain.FrameTypeTyping,
		MatchID:  &matchID,
		SenderID: &userID,
		IsTyping: isTyping,
	}
	return s.PublishFrame(ctx, partnerID, frame)
}

func (s *chatService) CreateMediaUploadURL(ctx context.Context, userID, matchID uuid.UUID, contentType, mediaType string, sizeBytes int64) (*MediaUploadResponse, error) {
	// Verify participant
	userA, userB, unmatchedAt, err := s.chatRepo.GetMatchParticipants(ctx, matchID)
	if err != nil {
		return nil, fmt.Errorf("failed to verify match: %w", err)
	}
	if userA == uuid.Nil || unmatchedAt != nil {
		return nil, apperrors.NotFound("match not found or has been unmatched")
	}
	if userID != userA && userID != userB {
		return nil, apperrors.Forbidden("user is not a participant in this match")
	}

	mediaType = strings.ToLower(strings.TrimSpace(mediaType))
	contentType = strings.ToLower(strings.TrimSpace(contentType))

	var subDir string
	var ext string

	switch mediaType {
	case domain.MessageTypeVoice:
		// Voice note: up to 60s, max 1MB
		if sizeBytes > 1024*1024 {
			return nil, apperrors.BadRequest("voice notes must not exceed 1 MB")
		}
		switch contentType {
		case "audio/ogg", "audio/opus":
			ext = ".opus"
		case "audio/m4a", "audio/mp4", "audio/aac":
			ext = ".m4a"
		case "audio/mpeg", "audio/mp3":
			ext = ".mp3"
		case "audio/wav":
			ext = ".wav"
		default:
			return nil, apperrors.BadRequest("unsupported audio content type for voice note")
		}
		subDir = "voice"

	case domain.MessageTypeImage:
		// Chat image: max 8MB
		if sizeBytes > 8*1024*1024 {
			return nil, apperrors.BadRequest("chat images must not exceed 8 MB")
		}
		switch contentType {
		case "image/jpeg", "image/jpg":
			ext = ".jpg"
		case "image/png":
			ext = ".png"
		case "image/webp":
			ext = ".webp"
		default:
			return nil, apperrors.BadRequest("unsupported image content type")
		}
		subDir = "images"

	default:
		return nil, apperrors.BadRequest("invalid media type; must be 'voice' or 'image'")
	}

	objectKey := fmt.Sprintf("chat/%s/%s/%s%s", matchID.String(), subDir, uuid.New().String(), ext)
	putURL, err := s.storageClient.PresignedPutPublic(ctx, objectKey, 15*time.Minute)
	if err != nil {
		return nil, fmt.Errorf("failed to generate presigned upload URL: %w", err)
	}

	mediaURL := fmt.Sprintf("%s/%s", strings.TrimRight(s.cdnBaseURL, "/"), filepath.ToSlash(objectKey))

	return &MediaUploadResponse{
		UploadURL: putURL.String(),
		MediaURL:  mediaURL,
		MediaType: mediaType,
	}, nil
}

func (s *chatService) RegisterDevice(ctx context.Context, userID uuid.UUID, fcmToken, platform string) error {
	if fcmToken == "" {
		return apperrors.BadRequest("fcm_token is required")
	}
	if platform == "" {
		platform = "android"
	}
	return s.deviceRepo.UpsertDevice(ctx, userID, fcmToken, platform)
}

func (s *chatService) UnregisterDevice(ctx context.Context, userID uuid.UUID, fcmToken string) error {
	if fcmToken == "" {
		return apperrors.BadRequest("fcm_token is required")
	}
	return s.deviceRepo.DeleteDevice(ctx, userID, fcmToken)
}

func (s *chatService) GetNotificationSettings(ctx context.Context, userID uuid.UUID) (*domain.NotificationSettings, string, error) {
	return s.notifRepo.GetUserNotificationSettings(ctx, userID)
}

func (s *chatService) UpdateNotificationSettings(ctx context.Context, userID uuid.UUID, settings *domain.NotificationSettings) error {
	if settings == nil {
		return apperrors.BadRequest("notification settings cannot be empty")
	}
	return s.notifRepo.UpdateUserNotificationSettings(ctx, userID, settings)
}

func (s *chatService) PublishFrame(ctx context.Context, targetUserID uuid.UUID, frame *domain.WSFrame) error {
	bytes, err := json.Marshal(frame)
	if err != nil {
		return fmt.Errorf("failed to marshal WSFrame: %w", err)
	}

	channel := fmt.Sprintf("chat:user:%s", targetUserID.String())
	return s.rdb.Publish(ctx, channel, bytes).Err()
}
