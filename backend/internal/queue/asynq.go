package queue

import (
	"context"
	"encoding/json"
	"fmt"

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
