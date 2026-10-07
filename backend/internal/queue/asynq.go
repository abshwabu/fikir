package queue

import (
	"context"
	"encoding/json"
	"fmt"

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
)

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
