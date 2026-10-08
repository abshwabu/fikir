package config

import (
	"fmt"
	"time"

	"github.com/go-playground/validator/v10"
	"github.com/kelseyhightower/envconfig"
)

// Config represents all application configuration loaded from environment variables
type Config struct {
	AppEnv   string `envconfig:"APP_ENV" default:"development" validate:"oneof=development staging production test"`
	AppPort  string `envconfig:"APP_PORT" default:"8080" validate:"required"`
	LogLevel string `envconfig:"LOG_LEVEL" default:"info" validate:"oneof=debug info warn error fatal"`

	Database DatabaseConfig
	Redis    RedisConfig
	MinIO    MinIOConfig

	CDNBaseURL string `envconfig:"CDN_BASE_URL" default:"http://localhost/media"`

	JWT JWTConfig
	OTP OTPConfig
	SMS SMSConfig

	CORS AllowedOriginsConfig

	RateLimit RateLimitConfig
}

type DatabaseConfig struct {
	Host     string `envconfig:"DB_HOST" default:"postgres" validate:"required"`
	Port     int    `envconfig:"DB_PORT" default:"5432" validate:"required,min=1,max=65535"`
	User     string `envconfig:"DB_USER" default:"postgres" validate:"required"`
	Password string `envconfig:"DB_PASSWORD" default:"postgres"`
	Name     string `envconfig:"DB_NAME" default:"fikir" validate:"required"`
	SSLMode  string `envconfig:"DB_SSLMODE" default:"disable"`
	MaxConns int32  `envconfig:"DB_MAX_CONNS" default:"25" validate:"min=1"`
	MinConns int32  `envconfig:"DB_MIN_CONNS" default:"5" validate:"min=0"`
}

// DSN returns the PostgreSQL connection string
func (d DatabaseConfig) DSN() string {
	return fmt.Sprintf("postgres://%s:%s@%s:%d/%s?sslmode=%s",
		d.User, d.Password, d.Host, d.Port, d.Name, d.SSLMode)
}

type RedisConfig struct {
	Host        string `envconfig:"REDIS_HOST" default:"redis" validate:"required"`
	Port        int    `envconfig:"REDIS_PORT" default:"6379" validate:"required,min=1,max=65535"`
	Password    string `envconfig:"REDIS_PASSWORD" default:""`
	CacheDB     int    `envconfig:"REDIS_CACHE_DB" default:"0" validate:"min=0,max=15"`
	QueueDB     int    `envconfig:"REDIS_QUEUE_DB" default:"1" validate:"min=0,max=15"`
	RateLimitDB int    `envconfig:"REDIS_RATE_LIMIT_DB" default:"2" validate:"min=0,max=15"`
}

func (r RedisConfig) Addr() string {
	return fmt.Sprintf("%s:%d", r.Host, r.Port)
}

type MinIOConfig struct {
	Endpoint       string `envconfig:"MINIO_ENDPOINT" default:"minio:9000" validate:"required"`
	RootUser       string `envconfig:"MINIO_ROOT_USER" default:"minioadmin" validate:"required"`
	RootPassword   string `envconfig:"MINIO_ROOT_PASSWORD" default:"miniopassword" validate:"required"`
	BucketOriginal string `envconfig:"MINIO_BUCKET_ORIGINAL" default:"fikir-media-original" validate:"required"`
	BucketPublic   string `envconfig:"MINIO_BUCKET_PUBLIC" default:"fikir-media-public" validate:"required"`
	Region         string `envconfig:"MINIO_REGION" default:"us-east-1"`
	UseSSL         bool   `envconfig:"MINIO_USE_SSL" default:"false"`
}

type JWTConfig struct {
	Secret        string        `envconfig:"JWT_SECRET" default:"supersecretjwtkeyforfikirapplicationinlocaldevelopmentonly32chars" validate:"required,min=32"`
	PrivateKeyHex string        `envconfig:"JWT_ED25519_PRIVATE_KEY_HEX" default:""`
	AccessExpiry  time.Duration `envconfig:"JWT_ACCESS_EXPIRY" default:"15m" validate:"required"`
	RefreshExpiry time.Duration `envconfig:"JWT_REFRESH_EXPIRY" default:"720h" validate:"required"`
}

type OTPConfig struct {
	Expiry          time.Duration `envconfig:"OTP_EXPIRY" default:"5m"`
	MaxAttempts     int           `envconfig:"OTP_MAX_ATTEMPTS" default:"5" validate:"min=1"`
	ResendCooldown  time.Duration `envconfig:"OTP_COOLDOWN" default:"60s"`
	DailyPhoneLimit int           `envconfig:"OTP_DAILY_PHONE_LIMIT" default:"5" validate:"min=1"`
	DailyIPLimit    int           `envconfig:"OTP_DAILY_IP_LIMIT" default:"20" validate:"min=1"`
}

type SMSConfig struct {
	Provider            string `envconfig:"SMS_PROVIDER" default:"console" validate:"oneof=console afromessage fallback"`
	AfroMessageAPIKey   string `envconfig:"AFROMESSAGE_API_KEY" default:""`
	AfroMessageSenderID string `envconfig:"AFROMESSAGE_SENDER_ID" default:""`
	AfroMessageBaseURL  string `envconfig:"AFROMESSAGE_BASE_URL" default:"https://api.afromessage.com/api/send"`
}

type AllowedOriginsConfig struct {
	Origins []string `envconfig:"CORS_ALLOWED_ORIGINS" default:"*"`
}

type RateLimitConfig struct {
	RequestsPerMinute int `envconfig:"RATE_LIMIT_RPM" default:"100" validate:"min=1"`
	Burst             int `envconfig:"RATE_LIMIT_BURST" default:"20" validate:"min=1"`
}

// Load loads configuration from environment variables and validates it
func Load() (*Config, error) {
	var cfg Config
	if err := envconfig.Process("", &cfg); err != nil {
		return nil, fmt.Errorf("failed to process envconfig: %w", err)
	}

	validate := validator.New()
	if err := validate.Struct(&cfg); err != nil {
		return nil, fmt.Errorf("configuration validation failed: %w", err)
	}

	return &cfg, nil
}
