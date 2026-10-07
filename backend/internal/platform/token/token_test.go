package token_test

import (
	"context"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/abshwabu/fikir/backend/internal/config"
	"github.com/abshwabu/fikir/backend/internal/domain"
	"github.com/abshwabu/fikir/backend/internal/platform/token"
)

type memoryAuthRepo struct {
	mu     sync.Mutex
	tokens map[string]*domain.RefreshToken
	logs   []*domain.AuthAuditLog
}

func newMemoryAuthRepo() *memoryAuthRepo {
	return &memoryAuthRepo{
		tokens: make(map[string]*domain.RefreshToken),
	}
}

func (m *memoryAuthRepo) CreateRefreshToken(ctx context.Context, t *domain.RefreshToken) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	t.ID = uuid.New()
	t.CreatedAt = time.Now()
	m.tokens[t.TokenHash] = t
	return nil
}

func (m *memoryAuthRepo) GetRefreshTokenByHash(ctx context.Context, tokenHash string) (*domain.RefreshToken, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if t, ok := m.tokens[tokenHash]; ok {
		cp := *t
		return &cp, nil
	}
	return nil, nil
}

func (m *memoryAuthRepo) RevokeRefreshToken(ctx context.Context, id uuid.UUID) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	for _, t := range m.tokens {
		if t.ID == id {
			t.IsRevoked = true
		}
	}
	return nil
}

func (m *memoryAuthRepo) RevokeTokenFamily(ctx context.Context, familyID uuid.UUID) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	for _, t := range m.tokens {
		if t.FamilyID == familyID {
			t.IsRevoked = true
		}
	}
	return nil
}

func (m *memoryAuthRepo) RevokeAllUserTokens(ctx context.Context, userID uuid.UUID) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	for _, t := range m.tokens {
		if t.UserID == userID {
			t.IsRevoked = true
		}
	}
	return nil
}

func (m *memoryAuthRepo) CreateAuditLog(ctx context.Context, log *domain.AuthAuditLog) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.logs = append(m.logs, log)
	return nil
}

func (m *memoryAuthRepo) UpsertDevice(ctx context.Context, device *domain.Device) error {
	return nil
}

func TestTokenManager_LifecycleAndReuseDetection(t *testing.T) {
	ctx := context.Background()
	repo := newMemoryAuthRepo()

	cfg := config.JWTConfig{
		AccessExpiry:  15 * time.Minute,
		RefreshExpiry: 30 * 24 * time.Hour,
	}

	tm, err := token.NewManager(cfg, repo)
	require.NoError(t, err)

	userID := uuid.New()
	phone := "+251911223344"

	// 1. Issue initial token pair
	pair1, err := tm.IssueTokenPair(ctx, userID, phone)
	require.NoError(t, err)
	assert.NotEmpty(t, pair1.AccessToken)
	assert.NotEmpty(t, pair1.RefreshToken)

	// Validate access token
	claims, err := tm.ValidateAccessToken(pair1.AccessToken)
	require.NoError(t, err)
	assert.Equal(t, userID.String(), claims.UserID)
	assert.Equal(t, phone, claims.PhoneE164)

	// 2. Rotate refresh token once
	pair2, err := tm.RotateRefreshToken(ctx, pair1.RefreshToken, phone)
	require.NoError(t, err)
	assert.NotEmpty(t, pair2.AccessToken)
	assert.NotEmpty(t, pair2.RefreshToken)
	assert.NotEqual(t, pair1.RefreshToken, pair2.RefreshToken)

	// 3. REUSE DETECTION: Replay old refresh token (pair1.RefreshToken)
	replayedPair, err := tm.RotateRefreshToken(ctx, pair1.RefreshToken, phone)
	assert.ErrorIs(t, err, token.ErrTokenReuseDetected)
	assert.Nil(t, replayedPair)

	// 4. Verify that pair2's refresh token is now ALSO revoked because the family was revoked!
	pair3, err := tm.RotateRefreshToken(ctx, pair2.RefreshToken, phone)
	assert.ErrorIs(t, err, token.ErrTokenReuseDetected)
	assert.Nil(t, pair3)
}
