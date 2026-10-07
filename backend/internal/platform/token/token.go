package token

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"

	"github.com/abshwabu/fikir/backend/internal/config"
	"github.com/abshwabu/fikir/backend/internal/domain"
)

var (
	ErrInvalidToken       = errors.New("invalid or malformed token")
	ErrTokenExpired       = errors.New("token has expired")
	ErrTokenReuseDetected = errors.New("refresh token reuse detected; session family revoked")
)

type Claims struct {
	UserID    string `json:"sub"`
	PhoneE164 string `json:"phone,omitempty"`
	jwt.RegisteredClaims
}

type TokenPair struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	TokenType    string `json:"token_type"`
	ExpiresIn    int    `json:"expires_in"` // in seconds
}

type Manager struct {
	privKey       ed25519.PrivateKey
	pubKey        ed25519.PublicKey
	accessExpiry  time.Duration
	refreshExpiry time.Duration
	authRepo      domain.AuthRepository
}

func NewManager(cfg config.JWTConfig, authRepo domain.AuthRepository) (*Manager, error) {
	var pub ed25519.PublicKey
	var priv ed25519.PrivateKey

	if cfg.PrivateKeyHex != "" {
		seed, err := hex.DecodeString(cfg.PrivateKeyHex)
		if err != nil {
			return nil, fmt.Errorf("invalid ed25519 private key hex: %w", err)
		}
		if len(seed) == ed25519.SeedSize {
			priv = ed25519.NewKeyFromSeed(seed)
			pub = priv.Public().(ed25519.PublicKey)
		} else if len(seed) == ed25519.PrivateKeySize {
			priv = ed25519.PrivateKey(seed)
			pub = priv.Public().(ed25519.PublicKey)
		} else {
			return nil, fmt.Errorf("invalid ed25519 key size %d; expected %d or %d", len(seed), ed25519.SeedSize, ed25519.PrivateKeySize)
		}
	} else {
		// Generate an ephemeral or dev key pair
		var err error
		pub, priv, err = ed25519.GenerateKey(rand.Reader)
		if err != nil {
			return nil, fmt.Errorf("failed to generate ed25519 key pair: %w", err)
		}
	}

	return &Manager{
		privKey:       priv,
		pubKey:        pub,
		accessExpiry:  cfg.AccessExpiry,
		refreshExpiry: cfg.RefreshExpiry,
		authRepo:      authRepo,
	}, nil
}

// GenerateAccessToken signs an EdDSA JWT for a given user ID
func (m *Manager) GenerateAccessToken(userID uuid.UUID, phoneE164 string) (string, error) {
	now := time.Now()
	claims := Claims{
		UserID:    userID.String(),
		PhoneE164: phoneE164,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID.String(),
			Issuer:    "fikir",
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(m.accessExpiry)),
			NotBefore: jwt.NewNumericDate(now),
		},
	}

	t := jwt.NewWithClaims(jwt.SigningMethodEdDSA, claims)
	signed, err := t.SignedString(m.privKey)
	if err != nil {
		return "", fmt.Errorf("failed to sign access token: %w", err)
	}
	return signed, nil
}

// ValidateAccessToken verifies an EdDSA JWT and extracts the user ID
func (m *Manager) ValidateAccessToken(tokenStr string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenStr, &Claims{}, func(t *jwt.Token) (interface{}, error) {
		if t.Method != jwt.SigningMethodEdDSA {
			return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
		}
		return m.pubKey, nil
	})
	if err != nil {
		return nil, ErrInvalidToken
	}

	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, ErrInvalidToken
	}

	return claims, nil
}

// IssueTokenPair issues an access token and a brand new refresh token with a new family ID
func (m *Manager) IssueTokenPair(ctx context.Context, userID uuid.UUID, phoneE164 string) (*TokenPair, error) {
	familyID := uuid.New()
	return m.issueTokensWithFamily(ctx, userID, phoneE164, familyID)
}

func (m *Manager) issueTokensWithFamily(ctx context.Context, userID uuid.UUID, phoneE164 string, familyID uuid.UUID) (*TokenPair, error) {
	// Generate raw random refresh token
	rawBytes := make([]byte, 32)
	if _, err := rand.Read(rawBytes); err != nil {
		return nil, fmt.Errorf("failed to generate random token: %w", err)
	}
	rawRefreshToken := hex.EncodeToString(rawBytes)
	tokenHash := HashToken(rawRefreshToken)

	expiresAt := time.Now().Add(m.refreshExpiry)
	rt := &domain.RefreshToken{
		UserID:    userID,
		TokenHash: tokenHash,
		FamilyID:  familyID,
		IsRevoked: false,
		ExpiresAt: expiresAt,
	}

	if err := m.authRepo.CreateRefreshToken(ctx, rt); err != nil {
		return nil, fmt.Errorf("failed to persist refresh token: %w", err)
	}

	accessToken, err := m.GenerateAccessToken(userID, phoneE164)
	if err != nil {
		return nil, err
	}

	return &TokenPair{
		AccessToken:  accessToken,
		RefreshToken: rawRefreshToken,
		TokenType:    "Bearer",
		ExpiresIn:    int(m.accessExpiry.Seconds()),
	}, nil
}

// RotateRefreshToken implements refresh token rotation and family reuse detection
func (m *Manager) RotateRefreshToken(ctx context.Context, rawRefreshToken string, phoneE164 string) (*TokenPair, error) {
	tokenHash := HashToken(rawRefreshToken)
	stored, err := m.authRepo.GetRefreshTokenByHash(ctx, tokenHash)
	if err != nil {
		return nil, fmt.Errorf("database query error: %w", err)
	}
	if stored == nil {
		return nil, ErrInvalidToken
	}

	// Reuse detection: If token was already revoked, someone is replaying an old refresh token!
	if stored.IsRevoked {
		// Immediately revoke the entire token family
		_ = m.authRepo.RevokeTokenFamily(ctx, stored.FamilyID)
		return nil, ErrTokenReuseDetected
	}

	// Check expiration
	if time.Now().After(stored.ExpiresAt) {
		return nil, ErrTokenExpired
	}

	// Mark old refresh token as revoked/used
	if err := m.authRepo.RevokeRefreshToken(ctx, stored.ID); err != nil {
		return nil, fmt.Errorf("failed to revoke old refresh token: %w", err)
	}

	// Issue new token pair preserving the same family ID
	return m.issueTokensWithFamily(ctx, stored.UserID, phoneE164, stored.FamilyID)
}

// RevokeRefreshToken revokes the specified refresh token and its family on logout
func (m *Manager) RevokeRefreshToken(ctx context.Context, rawRefreshToken string) error {
	tokenHash := HashToken(rawRefreshToken)
	stored, err := m.authRepo.GetRefreshTokenByHash(ctx, tokenHash)
	if err != nil || stored == nil {
		return nil
	}
	return m.authRepo.RevokeTokenFamily(ctx, stored.FamilyID)
}

// RevokeAllUserSessions revokes all refresh tokens for a user
func (m *Manager) RevokeAllUserSessions(ctx context.Context, userID uuid.UUID) error {
	return m.authRepo.RevokeAllUserTokens(ctx, userID)
}

// HashToken calculates the SHA-256 hex string for a raw token
func HashToken(raw string) string {
	h := sha256.Sum256([]byte(raw))
	return hex.EncodeToString(h[:])
}
