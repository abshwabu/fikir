package queue

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/hibiken/asynq"

	"github.com/abshwabu/fikir/backend/internal/config"
)

// Task type constants
const (
	QueueCritical = "critical"
	QueueDefault  = "default"
	QueueLow      = "low"

	TypeImageProcess     = "image:process"
	TypeSendNotification = "notification:send"
	TypePaymentWebhook   = "payment:webhook"
	TypeSendSMS          = "sms:send"
	TypeAccountPurge     = "account:purge"
	TypeSwipeRecord      = "swipe:record"
	TypeDeckRefill       = "discovery:deck_refill"
	TypeMatchNotification = "notification:match"
	TypeChatMessageNotification = "notification:chat_message"
	TypeSuperLikeNotification   = "notification:super_like"
)

type SendSMSPayload struct {
	To      string `json:"to"`
	Message string `json:"message"`
}

type AccountPurgePayload struct {
	RetentionDays int `json:"retention_days"`
}

type ImageProcessPayload struct {
	PhotoID     uuid.UUID `json:"photo_id"`
	UserID      uuid.UUID `json:"user_id"`
	OriginalKey string    `json:"original_key"`
}

type SwipeRecordPayload struct {
	SwiperID  uuid.UUID `json:"swiper_id"`
	TargetID  uuid.UUID `json:"target_id"`
	Direction string    `json:"direction"`
	CreatedAt string    `json:"created_at"`
}

type DeckRefillPayload struct {
	UserID uuid.UUID `json:"user_id"`
}

type MatchNotificationPayload struct {
	MatchID uuid.UUID `json:"match_id"`
	UserA   uuid.UUID `json:"user_a"`
	UserB   uuid.UUID `json:"user_b"`
}

type ChatMessageNotificationPayload struct {
	MessageID   int64     `json:"message_id"`
	MatchID     uuid.UUID `json:"match_id"`
	SenderID    uuid.UUID `json:"sender_id"`
	RecipientID uuid.UUID `json:"recipient_id"`
	SenderName  string    `json:"sender_name"`
	TextSnippet string    `json:"text_snippet"`
	MsgType     string    `json:"msg_type"`
}

type SuperLikeNotificationPayload struct {
	SenderID    uuid.UUID `json:"sender_id"`
	RecipientID uuid.UUID `json:"recipient_id"`
	SenderName  string    `json:"sender_name"`
}

// Client wraps asynq.Client to enqueue background jobs
type Client struct {
	client *asynq.Client
}

// NewClient creates a new queue client
func NewClient(cfg config.RedisConfig) *Client {
	redisOpt := asynq.RedisClientOpt{
		Addr:     cfg.Addr(),
		Password: cfg.Password,
		DB:       cfg.QueueDB,
	}

	return &Client{
		client: asynq.NewClient(redisOpt),
	}
}

// Close closes the asynq client
func (c *Client) Close() error {
	return c.client.Close()
}

// Enqueue submits a job with payload to a given queue
func (c *Client) Enqueue(ctx context.Context, taskType string, payload any, opts ...asynq.Option) (*asynq.TaskInfo, error) {
	bytes, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal task payload: %w", err)
	}

	task := asynq.NewTask(taskType, bytes, opts...)
	return c.client.EnqueueContext(ctx, task)
}

// EnqueueSendSMS enqueues an SMS dispatch task with retries in the critical queue
func (c *Client) EnqueueSendSMS(ctx context.Context, to, message string) (*asynq.TaskInfo, error) {
	return c.Enqueue(ctx, TypeSendSMS, SendSMSPayload{
		To:      to,
		Message: message,
	}, asynq.MaxRetry(3), asynq.Queue(QueueCritical))
}

// EnqueueImageProcess enqueues an image processing task
func (c *Client) EnqueueImageProcess(ctx context.Context, photoID, userID uuid.UUID, originalKey string) (*asynq.TaskInfo, error) {
	return c.Enqueue(ctx, TypeImageProcess, ImageProcessPayload{
		PhotoID:     photoID,
		UserID:      userID,
		OriginalKey: originalKey,
	}, asynq.MaxRetry(3), asynq.Queue(QueueDefault))
}

// EnqueueSwipeRecord enqueues an asynchronous swipe persistence task
func (c *Client) EnqueueSwipeRecord(ctx context.Context, swiperID, targetID uuid.UUID, direction string, createdAt string) (*asynq.TaskInfo, error) {
	return c.Enqueue(ctx, TypeSwipeRecord, SwipeRecordPayload{
		SwiperID:  swiperID,
		TargetID:  targetID,
		Direction: direction,
		CreatedAt: createdAt,
	}, asynq.MaxRetry(5), asynq.Queue(QueueDefault))
}

// EnqueueDeckRefill enqueues candidate deck pre-computation
func (c *Client) EnqueueDeckRefill(ctx context.Context, userID uuid.UUID) (*asynq.TaskInfo, error) {
	return c.Enqueue(ctx, TypeDeckRefill, DeckRefillPayload{
		UserID: userID,
	}, asynq.MaxRetry(2), asynq.Queue(QueueLow), asynq.Unique(30*time.Second))
}

// EnqueueMatchNotification enqueues mutual match notifications
func (c *Client) EnqueueMatchNotification(ctx context.Context, matchID, userA, userB uuid.UUID) (*asynq.TaskInfo, error) {
	return c.Enqueue(ctx, TypeMatchNotification, MatchNotificationPayload{
		MatchID: matchID,
		UserA:   userA,
		UserB:   userB,
	}, asynq.MaxRetry(3), asynq.Queue(QueueCritical))
}

// EnqueueChatMessageNotification enqueues push notification for offline message recipient
func (c *Client) EnqueueChatMessageNotification(ctx context.Context, payload ChatMessageNotificationPayload) (*asynq.TaskInfo, error) {
	return c.Enqueue(ctx, TypeChatMessageNotification, payload, asynq.MaxRetry(3), asynq.Queue(QueueCritical))
}

// EnqueueSuperLikeNotification enqueues push notification for super-like recipient
func (c *Client) EnqueueSuperLikeNotification(ctx context.Context, payload SuperLikeNotificationPayload) (*asynq.TaskInfo, error) {
	return c.Enqueue(ctx, TypeSuperLikeNotification, payload, asynq.MaxRetry(3), asynq.Queue(QueueCritical))
}

// NewServer creates a new asynq worker server
func NewServer(cfg config.RedisConfig, concurrency int) *asynq.Server {
	redisOpt := asynq.RedisClientOpt{
		Addr:     cfg.Addr(),
		Password: cfg.Password,
		DB:       cfg.QueueDB,
	}

	return asynq.NewServer(
		redisOpt,
		asynq.Config{
			Concurrency: concurrency,
			Queues: map[string]int{
				QueueCritical: 6,
				QueueDefault:  3,
				QueueLow:      1,
			},
		},
	)
}
