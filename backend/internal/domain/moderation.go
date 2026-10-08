package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

type BannedIdentifierType string

const (
	BannedIdentifierPhone             BannedIdentifierType = "phone"
	BannedIdentifierDeviceFingerprint BannedIdentifierType = "device_fingerprint"
	BannedIdentifierFCMToken          BannedIdentifierType = "fcm_token"
)

type BannedIdentifier struct {
	ID        uuid.UUID            `json:"id"`
	Type      BannedIdentifierType `json:"type"`
	Value     string               `json:"value"`
	Reason    string               `json:"reason,omitempty"`
	BannedBy  string               `json:"banned_by"`
	CreatedAt time.Time            `json:"created_at"`
}

type AdminAuditLog struct {
	ID         uuid.UUID      `json:"id"`
	AdminID    string         `json:"admin_id"`
	Action     string         `json:"action"` // "approve_photo", "reject_photo", "ban_user", "warn_user", "suspend_user"
	TargetType string         `json:"target_type"` // "photo", "user", "report", "verification"
	TargetID   string         `json:"target_id"`
	Details    map[string]any `json:"details,omitempty"`
	CreatedAt  time.Time      `json:"created_at"`
}

type ModerationReportItem struct {
	ReportID      uuid.UUID `json:"report_id"`
	ReporterID    uuid.UUID `json:"reporter_id"`
	ReportedID    uuid.UUID `json:"reported_id"`
	ReportedName  string    `json:"reported_name"`
	ReportedPhone string    `json:"reported_phone"`
	Reason        string    `json:"reason"`
	Details       string    `json:"details,omitempty"`
	Status        string    `json:"status"`
	ReportCount   int       `json:"report_count"`
	CreatedAt     time.Time `json:"created_at"`
}

type PendingPhotoItem struct {
	PhotoID     uuid.UUID `json:"photo_id"`
	UserID      uuid.UUID `json:"user_id"`
	UserName    string    `json:"user_name"`
	PhotoURL    string    `json:"photo_url"`
	Blurhash    string    `json:"blurhash,omitempty"`
	Status      string    `json:"status"`
	CreatedAt   time.Time `json:"created_at"`
	PHash       string    `json:"phash,omitempty"`
	IsDuplicate bool      `json:"is_duplicate"`
}

type PendingVerificationItem struct {
	VerificationID uuid.UUID `json:"verification_id"`
	UserID         uuid.UUID `json:"user_id"`
	UserName       string    `json:"user_name"`
	Pose           string    `json:"pose"`
	SelfieURL      string    `json:"selfie_url"`
	ProfilePhoto   string    `json:"profile_photo"`
	Status         string    `json:"status"`
	CreatedAt      time.Time `json:"created_at"`
}

// UserDataExport represents full user data bundle for Ethiopia Proclamation No. 1321/2024 compliance
type UserDataExport struct {
	User           *User          `json:"account"`
	Profile        *Profile       `json:"profile"`
	Photos         []ProfilePhoto `json:"photos"`
	MatchesCount   int            `json:"matches_count"`
	SwipesCount    int            `json:"swipes_count"`
	Payments       []Payment      `json:"payments"`
	Subscription   *Subscription  `json:"subscription,omitempty"`
	TermsAccepted  time.Time      `json:"terms_accepted_at"`
	ExportedAt     time.Time      `json:"exported_at"`
}

// ModerationRepository defines storage operations for moderation queues and audit logging
type ModerationRepository interface {
	GetPendingPhotos(ctx context.Context, limit, offset int) ([]PendingPhotoItem, error)
	GetPendingVerifications(ctx context.Context, limit, offset int) ([]PendingVerificationItem, error)
	GetPendingReports(ctx context.Context, limit, offset int) ([]ModerationReportItem, error)
	UpdatePhotoModeration(ctx context.Context, photoID uuid.UUID, status PhotoStatus, reason, reviewedBy string) error
	UpdateVerificationStatus(ctx context.Context, verificationID uuid.UUID, status string) error
	ResolveReport(ctx context.Context, reportID uuid.UUID, status string) error
	CheckDuplicatePHash(ctx context.Context, phash string, excludePhotoID uuid.UUID) (bool, error)
	AddBannedIdentifier(ctx context.Context, item *BannedIdentifier) error
	IsIdentifierBanned(ctx context.Context, idType BannedIdentifierType, value string) (bool, error)
	RecordAuditLog(ctx context.Context, log *AdminAuditLog) error
	GetAuditLogs(ctx context.Context, limit, offset int) ([]AdminAuditLog, error)
	CountReportsForUser(ctx context.Context, userID uuid.UUID) (int, error)
	SetShadowBan(ctx context.Context, userID uuid.UUID, shadowBanned bool) error
	SetUserBanned(ctx context.Context, userID uuid.UUID, reason, adminID string) error
}
