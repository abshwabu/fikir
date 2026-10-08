package service_test

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/abshwabu/fikir/backend/internal/domain"
	"github.com/abshwabu/fikir/backend/internal/service"
)

type mockModerationRepo struct {
	photos        map[uuid.UUID]*domain.ProfilePhoto
	verifications map[uuid.UUID]string
	reports       map[uuid.UUID]*domain.ModerationReportItem
	shadowBanned  map[uuid.UUID]bool
	userBanned    map[uuid.UUID]bool
	auditLogs     []*domain.AdminAuditLog
	bannedIDs     map[string]domain.BannedIdentifier
	profileVerif  map[uuid.UUID]bool
	userReports   map[uuid.UUID]int
}

func newMockModerationRepo() *mockModerationRepo {
	return &mockModerationRepo{
		photos:        make(map[uuid.UUID]*domain.ProfilePhoto),
		verifications: make(map[uuid.UUID]string),
		reports:       make(map[uuid.UUID]*domain.ModerationReportItem),
		shadowBanned:  make(map[uuid.UUID]bool),
		userBanned:    make(map[uuid.UUID]bool),
		bannedIDs:     make(map[string]domain.BannedIdentifier),
		profileVerif:  make(map[uuid.UUID]bool),
		userReports:   make(map[uuid.UUID]int),
	}
}

func (m *mockModerationRepo) GetPendingPhotos(ctx context.Context, limit, offset int) ([]domain.PendingPhotoItem, error) {
	return nil, nil
}

func (m *mockModerationRepo) GetPendingVerifications(ctx context.Context, limit, offset int) ([]domain.PendingVerificationItem, error) {
	return nil, nil
}

func (m *mockModerationRepo) GetPendingReports(ctx context.Context, limit, offset int) ([]domain.ModerationReportItem, error) {
	return nil, nil
}

func (m *mockModerationRepo) UpdatePhotoModeration(ctx context.Context, photoID uuid.UUID, status domain.PhotoStatus, reason, reviewedBy string) error {
	p, ok := m.photos[photoID]
	if ok {
		p.Status = status
	}
	return nil
}

func (m *mockModerationRepo) UpdateVerificationStatus(ctx context.Context, verificationID uuid.UUID, status string) error {
	m.verifications[verificationID] = status
	return nil
}

func (m *mockModerationRepo) ResolveReport(ctx context.Context, reportID uuid.UUID, status string) error {
	r, ok := m.reports[reportID]
	if ok {
		r.Status = status
	}
	return nil
}

func (m *mockModerationRepo) CheckDuplicatePHash(ctx context.Context, phash string, excludePhotoID uuid.UUID) (bool, error) {
	return false, nil
}

func (m *mockModerationRepo) AddBannedIdentifier(ctx context.Context, item *domain.BannedIdentifier) error {
	m.bannedIDs[item.Value] = *item
	return nil
}

func (m *mockModerationRepo) IsIdentifierBanned(ctx context.Context, idType domain.BannedIdentifierType, value string) (bool, error) {
	_, ok := m.bannedIDs[value]
	return ok, nil
}

func (m *mockModerationRepo) RecordAuditLog(ctx context.Context, log *domain.AdminAuditLog) error {
	m.auditLogs = append(m.auditLogs, log)
	return nil
}

func (m *mockModerationRepo) GetAuditLogs(ctx context.Context, limit, offset int) ([]domain.AdminAuditLog, error) {
	var list []domain.AdminAuditLog
	for _, l := range m.auditLogs {
		list = append(list, *l)
	}
	return list, nil
}

func (m *mockModerationRepo) CountReportsForUser(ctx context.Context, userID uuid.UUID) (int, error) {
	return m.userReports[userID], nil
}

func (m *mockModerationRepo) SetShadowBan(ctx context.Context, userID uuid.UUID, shadowBanned bool) error {
	m.shadowBanned[userID] = shadowBanned
	return nil
}

func (m *mockModerationRepo) SetUserBanned(ctx context.Context, userID uuid.UUID, reason, adminID string) error {
	m.userBanned[userID] = true
	m.shadowBanned[userID] = true
	return nil
}

type mockModerationCardCache struct {
	invalidated map[uuid.UUID]bool
}

func (m *mockModerationCardCache) Get(ctx context.Context, userID uuid.UUID, acceptHeader string, fetchFn func() (*domain.ProfileCard, error)) (*domain.ProfileCard, error) {
	return nil, nil
}
func (m *mockModerationCardCache) GetMany(ctx context.Context, userIDs []uuid.UUID, acceptHeader string, fetchBatchFn func([]uuid.UUID) (map[uuid.UUID]*domain.ProfileCard, error)) (map[uuid.UUID]*domain.ProfileCard, error) {
	return nil, nil
}
func (m *mockModerationCardCache) Set(ctx context.Context, card *domain.ProfileCard) error {
	return nil
}
func (m *mockModerationCardCache) Invalidate(ctx context.Context, userID uuid.UUID) error {
	if m.invalidated == nil {
		m.invalidated = make(map[uuid.UUID]bool)
	}
	m.invalidated[userID] = true
	return nil
}

func TestModerationService_PhotoRejectionAndAudit(t *testing.T) {
	repo := newMockModerationRepo()
	cardCache := &mockModerationCardCache{}
	svc := service.NewModerationService(repo, nil, nil, nil, cardCache, nil)
	ctx := context.Background()

	photoID := uuid.New()
	repo.photos[photoID] = &domain.ProfilePhoto{
		ID:     photoID,
		Status: domain.PhotoStatusPending,
	}

	err := svc.RejectPhoto(ctx, photoID, "inappropriate_content", "admin_1")
	require.NoError(t, err)

	assert.Equal(t, domain.PhotoStatusRejected, repo.photos[photoID].Status)
	assert.Len(t, repo.auditLogs, 1)
	assert.Equal(t, "reject_photo", repo.auditLogs[0].Action)
	assert.Equal(t, photoID.String(), repo.auditLogs[0].TargetID)
}

func TestModerationService_ReportThresholdAutoShadowBan(t *testing.T) {
	repo := newMockModerationRepo()
	cardCache := &mockModerationCardCache{}
	svc := service.NewModerationService(repo, nil, nil, nil, cardCache, nil)
	ctx := context.Background()

	reportedUser := uuid.New()

	// 2 reports: no auto-action
	repo.userReports[reportedUser] = 2
	err := svc.CheckReportThresholdAutoAction(ctx, reportedUser)
	require.NoError(t, err)
	assert.False(t, repo.shadowBanned[reportedUser])

	// 3 reports: triggers automatic shadow-ban & cache invalidation
	repo.userReports[reportedUser] = 3
	err = svc.CheckReportThresholdAutoAction(ctx, reportedUser)
	require.NoError(t, err)
	assert.True(t, repo.shadowBanned[reportedUser], "user with >= 3 reports must be shadow-banned")
	assert.True(t, cardCache.invalidated[reportedUser], "candidate cache must be invalidated")
	assert.Len(t, repo.auditLogs, 1)
	assert.Equal(t, "auto_shadow_ban_threshold", repo.auditLogs[0].Action)
}

func TestModerationService_BanUserAndIdentifierBlacklist(t *testing.T) {
	repo := newMockModerationRepo()
	cardCache := &mockModerationCardCache{}
	svc := service.NewModerationService(repo, nil, nil, nil, cardCache, nil)
	ctx := context.Background()

	targetUser := uuid.New()
	err := svc.BanUser(ctx, targetUser, "scamming_and_harassment", "admin_senior")
	require.NoError(t, err)

	assert.True(t, repo.userBanned[targetUser])
	assert.True(t, repo.shadowBanned[targetUser])
	assert.True(t, cardCache.invalidated[targetUser])

	// Identifier checks
	repo.bannedIDs["+251911223344"] = domain.BannedIdentifier{
		Type:  domain.BannedIdentifierPhone,
		Value: "+251911223344",
	}

	blocked, reason, err := svc.IsBlockedFromRegistering(ctx, "+251911223344", "")
	require.NoError(t, err)
	assert.True(t, blocked)
	assert.NotEmpty(t, reason)

	blockedClean, _, err := svc.IsBlockedFromRegistering(ctx, "+251922334455", "")
	require.NoError(t, err)
	assert.False(t, blockedClean)
}
