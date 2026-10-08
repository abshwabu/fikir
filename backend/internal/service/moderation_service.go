package service

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	"github.com/abshwabu/fikir/backend/internal/cache"
	"github.com/abshwabu/fikir/backend/internal/domain"
	"github.com/abshwabu/fikir/backend/internal/platform/push"
)

type ModerationService interface {
	GetPendingPhotos(ctx context.Context, limit, offset int) ([]domain.PendingPhotoItem, error)
	ApprovePhoto(ctx context.Context, photoID uuid.UUID, adminID string) error
	RejectPhoto(ctx context.Context, photoID uuid.UUID, reason, adminID string) error

	GetPendingVerifications(ctx context.Context, limit, offset int) ([]domain.PendingVerificationItem, error)
	ApproveVerification(ctx context.Context, verificationID uuid.UUID, adminID string) error
	RejectVerification(ctx context.Context, verificationID uuid.UUID, reason, adminID string) error

	GetPendingReports(ctx context.Context, limit, offset int) ([]domain.ModerationReportItem, error)
	ResolveReport(ctx context.Context, reportID uuid.UUID, action, adminID string) error

	WarnUser(ctx context.Context, userID uuid.UUID, reason, adminID string) error
	SuspendUser(ctx context.Context, userID uuid.UUID, duration time.Duration, reason, adminID string) error
	BanUser(ctx context.Context, userID uuid.UUID, reason, adminID string) error
	ShadowBanUser(ctx context.Context, userID uuid.UUID, shadowBanned bool, adminID string) error

	GetAuditLogs(ctx context.Context, limit, offset int) ([]domain.AdminAuditLog, error)
	ExportUserData(ctx context.Context, userID uuid.UUID) (*domain.UserDataExport, error)
	IsBlockedFromRegistering(ctx context.Context, phone, deviceFingerprint string) (bool, string, error)
	CheckReportThresholdAutoAction(ctx context.Context, reportedUserID uuid.UUID) error
}

type moderationService struct {
	repo        domain.ModerationRepository
	userRepo    domain.UserRepository
	profileRepo domain.ProfileRepository
	paymentRepo domain.PaymentRepository
	cardCache   cache.ProfileCardCache
	notifier    push.PushNotifier
}

func NewModerationService(
	repo domain.ModerationRepository,
	userRepo domain.UserRepository,
	profileRepo domain.ProfileRepository,
	paymentRepo domain.PaymentRepository,
	cardCache cache.ProfileCardCache,
	notifier push.PushNotifier,
) ModerationService {
	return &moderationService{
		repo:        repo,
		userRepo:    userRepo,
		profileRepo: profileRepo,
		paymentRepo: paymentRepo,
		cardCache:   cardCache,
		notifier:    notifier,
	}
}

func (s *moderationService) GetPendingPhotos(ctx context.Context, limit, offset int) ([]domain.PendingPhotoItem, error) {
	return s.repo.GetPendingPhotos(ctx, limit, offset)
}

func (s *moderationService) ApprovePhoto(ctx context.Context, photoID uuid.UUID, adminID string) error {
	if err := s.repo.UpdatePhotoModeration(ctx, photoID, domain.PhotoStatusApproved, "", adminID); err != nil {
		return err
	}

	_ = s.repo.RecordAuditLog(ctx, &domain.AdminAuditLog{
		AdminID:    adminID,
		Action:     "approve_photo",
		TargetType: "photo",
		TargetID:   photoID.String(),
		CreatedAt:  time.Now().UTC(),
	})
	return nil
}

func (s *moderationService) RejectPhoto(ctx context.Context, photoID uuid.UUID, reason, adminID string) error {
	if err := s.repo.UpdatePhotoModeration(ctx, photoID, domain.PhotoStatusRejected, reason, adminID); err != nil {
		return err
	}

	_ = s.repo.RecordAuditLog(ctx, &domain.AdminAuditLog{
		AdminID:    adminID,
		Action:     "reject_photo",
		TargetType: "photo",
		TargetID:   photoID.String(),
		Details:    map[string]any{"reason": reason},
		CreatedAt:  time.Now().UTC(),
	})

	return nil
}

func (s *moderationService) GetPendingVerifications(ctx context.Context, limit, offset int) ([]domain.PendingVerificationItem, error) {
	return s.repo.GetPendingVerifications(ctx, limit, offset)
}

func (s *moderationService) ApproveVerification(ctx context.Context, verificationID uuid.UUID, adminID string) error {
	if err := s.repo.UpdateVerificationStatus(ctx, verificationID, "approved"); err != nil {
		return err
	}

	_ = s.repo.RecordAuditLog(ctx, &domain.AdminAuditLog{
		AdminID:    adminID,
		Action:     "approve_verification",
		TargetType: "verification",
		TargetID:   verificationID.String(),
		CreatedAt:  time.Now().UTC(),
	})
	return nil
}

func (s *moderationService) RejectVerification(ctx context.Context, verificationID uuid.UUID, reason, adminID string) error {
	if err := s.repo.UpdateVerificationStatus(ctx, verificationID, "rejected"); err != nil {
		return err
	}

	_ = s.repo.RecordAuditLog(ctx, &domain.AdminAuditLog{
		AdminID:    adminID,
		Action:     "reject_verification",
		TargetType: "verification",
		TargetID:   verificationID.String(),
		Details:    map[string]any{"reason": reason},
		CreatedAt:  time.Now().UTC(),
	})
	return nil
}

func (s *moderationService) GetPendingReports(ctx context.Context, limit, offset int) ([]domain.ModerationReportItem, error) {
	return s.repo.GetPendingReports(ctx, limit, offset)
}

func (s *moderationService) ResolveReport(ctx context.Context, reportID uuid.UUID, action, adminID string) error {
	if err := s.repo.ResolveReport(ctx, reportID, action); err != nil {
		return err
	}

	_ = s.repo.RecordAuditLog(ctx, &domain.AdminAuditLog{
		AdminID:    adminID,
		Action:     "resolve_report",
		TargetType: "report",
		TargetID:   reportID.String(),
		Details:    map[string]any{"action": action},
		CreatedAt:  time.Now().UTC(),
	})
	return nil
}

func (s *moderationService) WarnUser(ctx context.Context, userID uuid.UUID, reason, adminID string) error {
	_ = s.repo.RecordAuditLog(ctx, &domain.AdminAuditLog{
		AdminID:    adminID,
		Action:     "warn_user",
		TargetType: "user",
		TargetID:   userID.String(),
		Details:    map[string]any{"reason": reason},
		CreatedAt:  time.Now().UTC(),
	})
	return nil
}

func (s *moderationService) SuspendUser(ctx context.Context, userID uuid.UUID, duration time.Duration, reason, adminID string) error {
	// Shadow ban during suspension
	_ = s.repo.SetShadowBan(ctx, userID, true)
	if s.cardCache != nil {
		_ = s.cardCache.Invalidate(ctx, userID)
	}

	_ = s.repo.RecordAuditLog(ctx, &domain.AdminAuditLog{
		AdminID:    adminID,
		Action:     "suspend_user",
		TargetType: "user",
		TargetID:   userID.String(),
		Details:    map[string]any{"duration": duration.String(), "reason": reason},
		CreatedAt:  time.Now().UTC(),
	})
	return nil
}

func (s *moderationService) BanUser(ctx context.Context, userID uuid.UUID, reason, adminID string) error {
	if err := s.repo.SetUserBanned(ctx, userID, reason, adminID); err != nil {
		return err
	}

	if s.cardCache != nil {
		_ = s.cardCache.Invalidate(ctx, userID)
	}

	_ = s.repo.RecordAuditLog(ctx, &domain.AdminAuditLog{
		AdminID:    adminID,
		Action:     "ban_user",
		TargetType: "user",
		TargetID:   userID.String(),
		Details:    map[string]any{"reason": reason},
		CreatedAt:  time.Now().UTC(),
	})
	return nil
}

func (s *moderationService) ShadowBanUser(ctx context.Context, userID uuid.UUID, shadowBanned bool, adminID string) error {
	if err := s.repo.SetShadowBan(ctx, userID, shadowBanned); err != nil {
		return err
	}

	if s.cardCache != nil {
		_ = s.cardCache.Invalidate(ctx, userID)
	}

	_ = s.repo.RecordAuditLog(ctx, &domain.AdminAuditLog{
		AdminID:    adminID,
		Action:     "shadow_ban_user",
		TargetType: "user",
		TargetID:   userID.String(),
		Details:    map[string]any{"shadow_banned": shadowBanned},
		CreatedAt:  time.Now().UTC(),
	})
	return nil
}

func (s *moderationService) GetAuditLogs(ctx context.Context, limit, offset int) ([]domain.AdminAuditLog, error) {
	return s.repo.GetAuditLogs(ctx, limit, offset)
}

func (s *moderationService) ExportUserData(ctx context.Context, userID uuid.UUID) (*domain.UserDataExport, error) {
	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch user: %w", err)
	}

	profile, err := s.profileRepo.GetByUserID(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch profile: %w", err)
	}

	photos, err := s.profileRepo.GetPhotos(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch photos: %w", err)
	}

	var payments []domain.Payment
	if s.paymentRepo != nil {
		payments, _ = s.paymentRepo.GetUserPayments(ctx, userID)
	}

	var sub *domain.Subscription
	if s.paymentRepo != nil {
		sub, _ = s.paymentRepo.GetActiveSubscription(ctx, userID)
	}

	now := time.Now().UTC()
	termsAccepted := now
	if user != nil {
		termsAccepted = user.CreatedAt
	}

	return &domain.UserDataExport{
		User:          user,
		Profile:       profile,
		Photos:        photos,
		Payments:      payments,
		Subscription:  sub,
		TermsAccepted: termsAccepted,
		ExportedAt:    now,
	}, nil
}

func (s *moderationService) IsBlockedFromRegistering(ctx context.Context, phone, deviceFingerprint string) (bool, string, error) {
	if phone != "" {
		banned, err := s.repo.IsIdentifierBanned(ctx, domain.BannedIdentifierPhone, phone)
		if err != nil {
			return false, "", err
		}
		if banned {
			return true, "Phone number is suspended or banned", nil
		}
	}

	if deviceFingerprint != "" {
		banned, err := s.repo.IsIdentifierBanned(ctx, domain.BannedIdentifierDeviceFingerprint, deviceFingerprint)
		if err != nil {
			return false, "", err
		}
		if banned {
			return true, "Device is suspended or banned", nil
		}
	}

	return false, "", nil
}

// CheckReportThresholdAutoAction automatically applies shadow-ban if user has >= 3 unresolved reports
func (s *moderationService) CheckReportThresholdAutoAction(ctx context.Context, reportedUserID uuid.UUID) error {
	count, err := s.repo.CountReportsForUser(ctx, reportedUserID)
	if err != nil {
		return err
	}

	if count >= 3 {
		log.Warn().Str("user_id", reportedUserID.String()).Int("report_count", count).Msg("User exceeded report threshold; auto shadow-banning")
		_ = s.repo.SetShadowBan(ctx, reportedUserID, true)
		if s.cardCache != nil {
			_ = s.cardCache.Invalidate(ctx, reportedUserID)
		}
		_ = s.repo.RecordAuditLog(ctx, &domain.AdminAuditLog{
			AdminID:    "system_automated_rules",
			Action:     "auto_shadow_ban_threshold",
			TargetType: "user",
			TargetID:   reportedUserID.String(),
			Details:    map[string]any{"report_count": count},
			CreatedAt:  time.Now().UTC(),
		})
	}
	return nil
}
