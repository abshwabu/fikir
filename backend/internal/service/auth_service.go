package service

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	"github.com/abshwabu/fikir/backend/internal/domain"
	apperrors "github.com/abshwabu/fikir/backend/internal/platform/errors"
	"github.com/abshwabu/fikir/backend/internal/platform/phone"
	"github.com/abshwabu/fikir/backend/internal/platform/token"
	"github.com/abshwabu/fikir/backend/internal/queue"
)

var (
	ErrAccountSuspended = apperrors.Forbidden("account is suspended or banned")
	ErrAccountDeleted   = apperrors.Forbidden("account is scheduled for deletion")
)

type DeviceInfo struct {
	FCMToken string `json:"fcm_token"`
	Platform string `json:"platform"`
}

type VerifyOTPRequest struct {
	Phone  string      `json:"phone"`
	Code   string      `json:"code"`
	Device *DeviceInfo `json:"device,omitempty"`
}

type UserSummary struct {
	ID        uuid.UUID `json:"id"`
	PhoneE164 string    `json:"phone_e164"`
	Status    string    `json:"status"`
	Locale    string    `json:"locale"`
	IsNewUser bool      `json:"is_new_user"`
}

type VerifyOTPResponse struct {
	AccessToken  string      `json:"access_token"`
	RefreshToken string      `json:"refresh_token"`
	TokenType    string      `json:"token_type"`
	ExpiresIn    int         `json:"expires_in"`
	User         UserSummary `json:"user"`
}

type AuthService interface {
	RequestOTP(ctx context.Context, phoneRaw, clientIP, userAgent, deviceFingerprint string) (time.Duration, error)
	VerifyOTP(ctx context.Context, req VerifyOTPRequest, clientIP, userAgent, deviceFingerprint string) (*VerifyOTPResponse, error)
	RefreshToken(ctx context.Context, rawRefreshToken, clientIP, userAgent, deviceFingerprint string) (*token.TokenPair, error)
	Logout(ctx context.Context, rawRefreshToken string, userID *uuid.UUID, clientIP, userAgent, deviceFingerprint string) error
	DeleteAccount(ctx context.Context, userID uuid.UUID, clientIP, userAgent, deviceFingerprint string) error
}

type authService struct {
	userRepo    domain.UserRepository
	authRepo    domain.AuthRepository
	otpService  OTPService
	tokenMgr    *token.Manager
	smsSender   domain.SMSSender
	queueClient *queue.Client
}

func NewAuthService(
	userRepo domain.UserRepository,
	authRepo domain.AuthRepository,
	otpService OTPService,
	tokenMgr *token.Manager,
	smsSender domain.SMSSender,
	queueClient *queue.Client,
) AuthService {
	return &authService{
		userRepo:    userRepo,
		authRepo:    authRepo,
		otpService:  otpService,
		tokenMgr:    tokenMgr,
		smsSender:   smsSender,
		queueClient: queueClient,
	}
}

func (s *authService) RequestOTP(ctx context.Context, phoneRaw, clientIP, userAgent, deviceFingerprint string) (time.Duration, error) {
	phoneE164, err := phone.NormalizeEthiopian(phoneRaw)
	if err != nil {
		return 0, apperrors.BadRequest(err.Error())
	}

	code, cooldown, err := s.otpService.GenerateAndStore(ctx, phoneE164, clientIP)
	if err != nil {
		if errors.Is(err, ErrCooldownActive) {
			return cooldown, apperrors.RateLimited(fmt.Sprintf("Please wait %d seconds before requesting another code", int(cooldown.Seconds())))
		}
		if errors.Is(err, ErrDailyPhoneLimitExceed) || errors.Is(err, ErrDailyIPLimitExceed) {
			return 0, apperrors.RateLimited(err.Error())
		}
		return 0, err
	}

	smsMsg := fmt.Sprintf("Your Fikir verification code is %s. Valid for 5 minutes.", code)

	// Send through asynq task with retries; fallback to direct dispatch if queue client is nil
	if s.queueClient != nil {
		if _, queueErr := s.queueClient.EnqueueSendSMS(ctx, phoneE164, smsMsg); queueErr != nil {
			log.Warn().Err(queueErr).Msg("Failed to enqueue SMS task; attempting direct dispatch")
			_ = s.smsSender.SendSMS(ctx, phoneE164, smsMsg)
		}
	} else if s.smsSender != nil {
		_ = s.smsSender.SendSMS(ctx, phoneE164, smsMsg)
	}

	// Record audit log
	_ = s.authRepo.CreateAuditLog(ctx, &domain.AuthAuditLog{
		PhoneE164:         phoneE164,
		Event:             "otp_requested",
		IPAddress:         clientIP,
		UserAgent:         userAgent,
		DeviceFingerprint: deviceFingerprint,
		Metadata: map[string]interface{}{
			"cooldown_seconds": int(cooldown.Seconds()),
		},
	})

	return cooldown, nil
}

func (s *authService) VerifyOTP(ctx context.Context, req VerifyOTPRequest, clientIP, userAgent, deviceFingerprint string) (*VerifyOTPResponse, error) {
	phoneE164, err := phone.NormalizeEthiopian(req.Phone)
	if err != nil {
		return nil, apperrors.BadRequest(err.Error())
	}

	if err := s.otpService.Verify(ctx, phoneE164, req.Code); err != nil {
		_ = s.authRepo.CreateAuditLog(ctx, &domain.AuthAuditLog{
			PhoneE164:         phoneE164,
			Event:             "otp_verify_failed",
			IPAddress:         clientIP,
			UserAgent:         userAgent,
			DeviceFingerprint: deviceFingerprint,
			Metadata: map[string]interface{}{
				"reason": err.Error(),
			},
		})

		if errors.Is(err, ErrInvalidCode) {
			return nil, apperrors.Unauthorized("Invalid verification code")
		}
		if errors.Is(err, ErrMaxAttemptsExceeded) {
			return nil, apperrors.Forbidden("Too many incorrect attempts; OTP invalidated")
		}
		if errors.Is(err, ErrOTPNotFound) {
			return nil, apperrors.Unauthorized("Verification code expired or not requested")
		}
		return nil, apperrors.Unauthorized(err.Error())
	}

	// OTP is verified; lookup or create user
	isNewUser := false
	user, err := s.userRepo.GetByPhone(ctx, phoneE164)
	if err != nil {
		return nil, fmt.Errorf("failed to lookup user: %w", err)
	}

	if user == nil {
		newUser := &domain.User{
			PhoneE164: phoneE164,
			Status:    domain.UserStatusActive,
			Locale:    "am",
		}
		if err := s.userRepo.Create(ctx, newUser); err != nil {
			return nil, fmt.Errorf("failed to create user: %w", err)
		}
		user = newUser
		isNewUser = true
	} else {
		if user.Status == domain.UserStatusSuspended || user.Status == domain.UserStatusBanned {
			return nil, ErrAccountSuspended
		}
		if user.Status == domain.UserStatusDeleted {
			return nil, ErrAccountDeleted
		}
	}

	// Upsert device if provided
	if req.Device != nil && req.Device.FCMToken != "" {
		platform := req.Device.Platform
		if platform != "ios" && platform != "android" && platform != "web" {
			platform = "android"
		}
		_ = s.authRepo.UpsertDevice(ctx, &domain.Device{
			UserID:   user.ID,
			FCMToken: req.Device.FCMToken,
			Platform: platform,
		})
	}

	// Issue token pair
	tokens, err := s.tokenMgr.IssueTokenPair(ctx, user.ID, user.PhoneE164)
	if err != nil {
		return nil, fmt.Errorf("failed to issue tokens: %w", err)
	}

	// Record audit log
	_ = s.authRepo.CreateAuditLog(ctx, &domain.AuthAuditLog{
		UserID:            &user.ID,
		PhoneE164:         user.PhoneE164,
		Event:             "otp_verified",
		IPAddress:         clientIP,
		UserAgent:         userAgent,
		DeviceFingerprint: deviceFingerprint,
		Metadata: map[string]interface{}{
			"is_new_user": isNewUser,
		},
	})

	return &VerifyOTPResponse{
		AccessToken:  tokens.AccessToken,
		RefreshToken: tokens.RefreshToken,
		TokenType:    tokens.TokenType,
		ExpiresIn:    tokens.ExpiresIn,
		User: UserSummary{
			ID:        user.ID,
			PhoneE164: user.PhoneE164,
			Status:    string(user.Status),
			Locale:    user.Locale,
			IsNewUser: isNewUser,
		},
	}, nil
}

func (s *authService) RefreshToken(ctx context.Context, rawRefreshToken, clientIP, userAgent, deviceFingerprint string) (*token.TokenPair, error) {
	if rawRefreshToken == "" {
		return nil, apperrors.BadRequest("refresh token is required")
	}

	tokens, err := s.tokenMgr.RotateRefreshToken(ctx, rawRefreshToken, "")
	if err != nil {
		if errors.Is(err, token.ErrTokenReuseDetected) {
			_ = s.authRepo.CreateAuditLog(ctx, &domain.AuthAuditLog{
				Event:             "token_reuse_detected",
				IPAddress:         clientIP,
				UserAgent:         userAgent,
				DeviceFingerprint: deviceFingerprint,
			})
			return nil, apperrors.Unauthorized("Refresh token reuse detected; all sessions terminated")
		}
		if errors.Is(err, token.ErrTokenExpired) {
			return nil, apperrors.Unauthorized("Refresh token has expired")
		}
		return nil, apperrors.Unauthorized("Invalid refresh token")
	}

	_ = s.authRepo.CreateAuditLog(ctx, &domain.AuthAuditLog{
		Event:             "token_refreshed",
		IPAddress:         clientIP,
		UserAgent:         userAgent,
		DeviceFingerprint: deviceFingerprint,
	})

	return tokens, nil
}

func (s *authService) Logout(ctx context.Context, rawRefreshToken string, userID *uuid.UUID, clientIP, userAgent, deviceFingerprint string) error {
	if rawRefreshToken != "" {
		_ = s.tokenMgr.RevokeRefreshToken(ctx, rawRefreshToken)
	}
	if userID != nil {
		_ = s.tokenMgr.RevokeAllUserSessions(ctx, *userID)
	}

	_ = s.authRepo.CreateAuditLog(ctx, &domain.AuthAuditLog{
		UserID:            userID,
		Event:             "logout",
		IPAddress:         clientIP,
		UserAgent:         userAgent,
		DeviceFingerprint: deviceFingerprint,
	})

	return nil
}

func (s *authService) DeleteAccount(ctx context.Context, userID uuid.UUID, clientIP, userAgent, deviceFingerprint string) error {
	// Soft delete user: sets status='deleted', deleted_at=NOW()
	if err := s.userRepo.SoftDelete(ctx, userID); err != nil {
		return fmt.Errorf("failed to soft delete account: %w", err)
	}

	// Revoke all refresh tokens
	_ = s.tokenMgr.RevokeAllUserSessions(ctx, userID)

	_ = s.authRepo.CreateAuditLog(ctx, &domain.AuthAuditLog{
		UserID:            &userID,
		Event:             "account_deleted",
		IPAddress:         clientIP,
		UserAgent:         userAgent,
		DeviceFingerprint: deviceFingerprint,
		Metadata: map[string]interface{}{
			"purge_period_days": 30,
		},
	})

	return nil
}
