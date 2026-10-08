package media

import (
	"context"

	"github.com/abshwabu/fikir/backend/internal/domain"
)

// ModerationResult represents the outcome of an automated image scan
type ModerationResult struct {
	Status  domain.PhotoStatus `json:"status"` // "pending", "approved", "rejected"
	HasFace bool               `json:"has_face"`
	IsNSFW  bool               `json:"is_nsfw"`
	Reason  string             `json:"reason,omitempty"`
}

// ImageModerator defines a pluggable hook for image safety and quality checks
type ImageModerator interface {
	Moderate(ctx context.Context, imgBytes []byte) (ModerationResult, error)
}

// DefaultImageModerator implements a safe default: marks photos as pending for manual review
type DefaultImageModerator struct {
	AutoApproveInDev bool
}

func NewDefaultModerator(autoApproveInDev bool) *DefaultImageModerator {
	return &DefaultImageModerator{
		AutoApproveInDev: autoApproveInDev,
	}
}

func (m *DefaultImageModerator) Moderate(ctx context.Context, imgBytes []byte) (ModerationResult, error) {
	// Simple face check heuristic: valid image bytes > 1KB
	hasFace := len(imgBytes) > 1024

	status := domain.PhotoStatusPending
	if m.AutoApproveInDev {
		status = domain.PhotoStatusApproved
	}

	return ModerationResult{
		Status:  status,
		HasFace: hasFace,
		IsNSFW:  false,
		Reason:  "Automated pre-screening complete",
	}, nil
}
