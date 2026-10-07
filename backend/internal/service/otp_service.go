package service

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"errors"
	"fmt"
	"math/big"
	"time"

	"github.com/redis/go-redis/v9"

	"github.com/abshwabu/fikir/backend/internal/config"
)

var (
	ErrCooldownActive        = errors.New("please wait before requesting another OTP")
	ErrDailyPhoneLimitExceed = errors.New("daily OTP request limit reached for this phone number")
	ErrDailyIPLimitExceed    = errors.New("daily OTP request limit reached for this IP address")
	ErrOTPNotFound           = errors.New("OTP expired or not found")
	ErrMaxAttemptsExceeded   = errors.New("maximum OTP verification attempts exceeded")
	ErrInvalidCode           = errors.New("invalid verification code")
)

// OTPService handles generation, verification, and rate limiting of OTPs
type OTPService interface {
	GenerateAndStore(ctx context.Context, phoneE164, clientIP string) (code string, cooldown time.Duration, err error)
	Verify(ctx context.Context, phoneE164, code string) error
	GetRemainingCooldown(ctx context.Context, phoneE164 string) time.Duration
}

type redisOTPService struct {
	rdb redis.UniversalClient
	cfg config.OTPConfig
}

func NewOTPService(rdb redis.UniversalClient, cfg config.OTPConfig) OTPService {
	return &redisOTPService{
		rdb: rdb,
		cfg: cfg,
	}
}

func (s *redisOTPService) keyCode(phone string) string {
	return "otp:code:" + phone
}

func (s *redisOTPService) keyAttempts(phone string) string {
	return "otp:attempts:" + phone
}

func (s *redisOTPService) keyCooldown(phone string) string {
	return "otp:cooldown:" + phone
}

func (s *redisOTPService) keyDailyPhone(phone string) string {
	return "otp:daily:phone:" + phone
}

func (s *redisOTPService) keyDailyIP(ip string) string {
	return "otp:daily:ip:" + ip
}

func (s *redisOTPService) hash(phone, code string) string {
	h := sha256.Sum256([]byte(phone + ":" + code))
	return hex.EncodeToString(h[:])
}

func (s *redisOTPService) GetRemainingCooldown(ctx context.Context, phoneE164 string) time.Duration {
	ttl, err := s.rdb.TTL(ctx, s.keyCooldown(phoneE164)).Result()
	if err != nil || ttl <= 0 {
		return 0
	}
	return ttl
}

func (s *redisOTPService) GenerateAndStore(ctx context.Context, phoneE164, clientIP string) (string, time.Duration, error) {
	// 1. Check resend cooldown
	if rem := s.GetRemainingCooldown(ctx, phoneE164); rem > 0 {
		return "", rem, ErrCooldownActive
	}

	// 2. Check per-phone daily cap
	phoneCount, err := s.rdb.Incr(ctx, s.keyDailyPhone(phoneE164)).Result()
	if err != nil {
		return "", 0, fmt.Errorf("failed to check phone daily limit: %w", err)
	}
	if phoneCount == 1 {
		_ = s.rdb.Expire(ctx, s.keyDailyPhone(phoneE164), 24*time.Hour)
	}
	if int(phoneCount) > s.cfg.DailyPhoneLimit {
		return "", 0, ErrDailyPhoneLimitExceed
	}

	// 3. Check per-IP daily cap (if IP provided)
	if clientIP != "" {
		ipCount, err := s.rdb.Incr(ctx, s.keyDailyIP(clientIP)).Result()
		if err != nil {
			return "", 0, fmt.Errorf("failed to check IP daily limit: %w", err)
		}
		if ipCount == 1 {
			_ = s.rdb.Expire(ctx, s.keyDailyIP(clientIP), 24*time.Hour)
		}
		if int(ipCount) > s.cfg.DailyIPLimit {
			return "", 0, ErrDailyIPLimitExceed
		}
	}

	// 4. Generate cryptographically secure 6-digit code
	n, err := rand.Int(rand.Reader, big.NewInt(1000000))
	if err != nil {
		return "", 0, fmt.Errorf("failed to generate random OTP: %w", err)
	}
	code := fmt.Sprintf("%06d", n.Int64())

	// 5. Store hashed in Redis
	codeHash := s.hash(phoneE164, code)
	pipe := s.rdb.TxPipeline()
	pipe.Set(ctx, s.keyCode(phoneE164), codeHash, s.cfg.Expiry)
	pipe.Del(ctx, s.keyAttempts(phoneE164))
	pipe.Set(ctx, s.keyCooldown(phoneE164), "1", s.cfg.ResendCooldown)
	if _, err := pipe.Exec(ctx); err != nil {
		return "", 0, fmt.Errorf("failed to save OTP in redis: %w", err)
	}

	return code, s.cfg.ResendCooldown, nil
}

func (s *redisOTPService) Verify(ctx context.Context, phoneE164, code string) error {
	// 1. Check max verify attempts
	attempts, err := s.rdb.Get(ctx, s.keyAttempts(phoneE164)).Int()
	if err != nil && !errors.Is(err, redis.Nil) {
		return fmt.Errorf("failed to check attempts: %w", err)
	}
	if attempts >= s.cfg.MaxAttempts {
		_ = s.rdb.Del(ctx, s.keyCode(phoneE164))
		return ErrMaxAttemptsExceeded
	}

	// 2. Fetch stored hashed code
	storedHash, err := s.rdb.Get(ctx, s.keyCode(phoneE164)).Result()
	if err != nil {
		if errors.Is(err, redis.Nil) {
			return ErrOTPNotFound
		}
		return fmt.Errorf("failed to get stored OTP: %w", err)
	}

	// 3. Constant-time compare
	givenHash := s.hash(phoneE164, code)
	if subtle.ConstantTimeCompare([]byte(givenHash), []byte(storedHash)) != 1 {
		newAttempts, incrErr := s.rdb.Incr(ctx, s.keyAttempts(phoneE164)).Result()
		if incrErr == nil {
			if newAttempts == 1 {
				_ = s.rdb.Expire(ctx, s.keyAttempts(phoneE164), s.cfg.Expiry)
			}
			if int(newAttempts) >= s.cfg.MaxAttempts {
				_ = s.rdb.Del(ctx, s.keyCode(phoneE164))
				return ErrMaxAttemptsExceeded
			}
		}
		return ErrInvalidCode
	}

	// 4. Successful verification: clear OTP and attempts
	pipe := s.rdb.TxPipeline()
	pipe.Del(ctx, s.keyCode(phoneE164))
	pipe.Del(ctx, s.keyAttempts(phoneE164))
	_, _ = pipe.Exec(ctx)

	return nil
}
