package repository

import (
	"context"
	"encoding/json"
	"errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"

	"github.com/abshwabu/fikir/backend/internal/domain"
	"github.com/abshwabu/fikir/backend/internal/platform/media"
)

type pgModerationRepository struct {
	db DBTX
}

func NewModerationRepository(db DBTX) domain.ModerationRepository {
	return &pgModerationRepository{db: db}
}

func (r *pgModerationRepository) GetPendingPhotos(ctx context.Context, limit, offset int) ([]domain.PendingPhotoItem, error) {
	query := `
		SELECT 
			p.id, 
			p.user_id, 
			COALESCE(pr.name, 'User') as user_name,
			p.url, 
			COALESCE(p.blurhash, '') as blurhash,
			p.status, 
			p.created_at, 
			COALESCE(p.phash, '') as phash
		FROM profile_photos p
		LEFT JOIN profiles pr ON pr.user_id = p.user_id
		WHERE p.status = 'pending'
		ORDER BY p.created_at ASC
		LIMIT $1 OFFSET $2
	`
	rows, err := r.db.Query(ctx, query, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []domain.PendingPhotoItem
	for rows.Next() {
		var item domain.PendingPhotoItem
		var phash string
		if err := rows.Scan(
			&item.PhotoID,
			&item.UserID,
			&item.UserName,
			&item.PhotoURL,
			&item.Blurhash,
			&item.Status,
			&item.CreatedAt,
			&phash,
		); err != nil {
			return nil, err
		}
		item.PHash = phash
		list = append(list, item)
	}

	// Check duplicates
	for i := range list {
		if list[i].PHash != "" {
			isDup, _ := r.CheckDuplicatePHash(ctx, list[i].PHash, list[i].PhotoID)
			list[i].IsDuplicate = isDup
		}
	}

	return list, rows.Err()
}

func (r *pgModerationRepository) GetPendingVerifications(ctx context.Context, limit, offset int) ([]domain.PendingVerificationItem, error) {
	query := `
		SELECT 
			v.id, 
			v.user_id, 
			COALESCE(pr.name, 'User') as user_name,
			v.pose, 
			v.photo_url, 
			COALESCE(
				(SELECT url FROM profile_photos WHERE user_id = v.user_id AND status = 'approved' ORDER BY position ASC LIMIT 1),
				(SELECT url FROM profile_photos WHERE user_id = v.user_id ORDER BY position ASC LIMIT 1),
				''
			) as profile_photo,
			v.status, 
			v.created_at
		FROM verifications v
		LEFT JOIN profiles pr ON pr.user_id = v.user_id
		WHERE v.status = 'pending'
		ORDER BY v.created_at ASC
		LIMIT $1 OFFSET $2
	`
	rows, err := r.db.Query(ctx, query, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []domain.PendingVerificationItem
	for rows.Next() {
		var item domain.PendingVerificationItem
		if err := rows.Scan(
			&item.VerificationID,
			&item.UserID,
			&item.UserName,
			&item.Pose,
			&item.SelfieURL,
			&item.ProfilePhoto,
			&item.Status,
			&item.CreatedAt,
		); err != nil {
			return nil, err
		}
		list = append(list, item)
	}
	return list, rows.Err()
}

func (r *pgModerationRepository) GetPendingReports(ctx context.Context, limit, offset int) ([]domain.ModerationReportItem, error) {
	query := `
		SELECT 
			rep.id,
			rep.reporter_id,
			rep.reported_id,
			COALESCE(pr.name, 'User') as reported_name,
			COALESCE(u.phone, '') as reported_phone,
			rep.reason,
			COALESCE(rep.details, '') as details,
			rep.status,
			COUNT(*) OVER (PARTITION BY rep.reported_id) as report_count,
			rep.created_at
		FROM reports rep
		LEFT JOIN profiles pr ON pr.user_id = rep.reported_id
		LEFT JOIN users u ON u.id = rep.reported_id
		WHERE rep.status = 'pending'
		ORDER BY report_count DESC, rep.created_at ASC
		LIMIT $1 OFFSET $2
	`
	rows, err := r.db.Query(ctx, query, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []domain.ModerationReportItem
	for rows.Next() {
		var item domain.ModerationReportItem
		if err := rows.Scan(
			&item.ReportID,
			&item.ReporterID,
			&item.ReportedID,
			&item.ReportedName,
			&item.ReportedPhone,
			&item.Reason,
			&item.Details,
			&item.Status,
			&item.ReportCount,
			&item.CreatedAt,
		); err != nil {
			return nil, err
		}
		list = append(list, item)
	}
	return list, rows.Err()
}

func (r *pgModerationRepository) UpdatePhotoModeration(ctx context.Context, photoID uuid.UUID, status domain.PhotoStatus, reason, reviewedBy string) error {
	query := `
		UPDATE profile_photos
		SET status = $2, moderation_reason = $3, reviewed_by = $4, reviewed_at = NOW()
		WHERE id = $1
	`
	_, err := r.db.Exec(ctx, query, photoID, string(status), reason, reviewedBy)
	return err
}

func (r *pgModerationRepository) UpdateVerificationStatus(ctx context.Context, verificationID uuid.UUID, status string) error {
	query := `
		UPDATE verifications
		SET status = $2, reviewed_at = NOW()
		WHERE id = $1
		RETURNING user_id
	`
	var userID uuid.UUID
	err := r.db.QueryRow(ctx, query, verificationID, status).Scan(&userID)
	if err != nil {
		return err
	}

	if status == "approved" {
		_, err = r.db.Exec(ctx, `UPDATE profiles SET verified = true, updated_at = NOW() WHERE user_id = $1`, userID)
		return err
	}
	return nil
}

func (r *pgModerationRepository) ResolveReport(ctx context.Context, reportID uuid.UUID, status string) error {
	query := `UPDATE reports SET status = $2 WHERE id = $1`
	_, err := r.db.Exec(ctx, query, reportID, status)
	return err
}

func (r *pgModerationRepository) CheckDuplicatePHash(ctx context.Context, phash string, excludePhotoID uuid.UUID) (bool, error) {
	if len(phash) != 16 {
		return false, nil
	}

	query := `
		SELECT phash
		FROM profile_photos
		WHERE phash IS NOT NULL AND id != $1 AND status != 'rejected'
		LIMIT 200
	`
	rows, err := r.db.Query(ctx, query, excludePhotoID)
	if err != nil {
		return false, err
	}
	defer rows.Close()

	for rows.Next() {
		var existingHash string
		if err := rows.Scan(&existingHash); err != nil {
			continue
		}
		if media.IsSimilarPHash(phash, existingHash, 5) {
			return true, nil
		}
	}
	return false, rows.Err()
}

func (r *pgModerationRepository) AddBannedIdentifier(ctx context.Context, item *domain.BannedIdentifier) error {
	query := `
		INSERT INTO banned_identifiers (id, type, value, reason, banned_by, created_at)
		VALUES ($1, $2, $3, $4, $5, $6)
		ON CONFLICT (value) DO UPDATE SET
			reason = EXCLUDED.reason,
			banned_by = EXCLUDED.banned_by
	`
	if item.ID == uuid.Nil {
		item.ID = uuid.New()
	}
	_, err := r.db.Exec(ctx, query, item.ID, string(item.Type), item.Value, item.Reason, item.BannedBy, item.CreatedAt)
	return err
}

func (r *pgModerationRepository) IsIdentifierBanned(ctx context.Context, idType domain.BannedIdentifierType, value string) (bool, error) {
	query := `
		SELECT EXISTS(
			SELECT 1 FROM banned_identifiers
			WHERE type = $1 AND value = $2
		)
	`
	var exists bool
	err := r.db.QueryRow(ctx, query, string(idType), value).Scan(&exists)
	return exists, err
}

func (r *pgModerationRepository) RecordAuditLog(ctx context.Context, log *domain.AdminAuditLog) error {
	query := `
		INSERT INTO admin_audit_logs (id, admin_id, action, target_type, target_id, details, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`
	if log.ID == uuid.Nil {
		log.ID = uuid.New()
	}
	var detailsJSON []byte
	if log.Details != nil {
		detailsJSON, _ = json.Marshal(log.Details)
	}
	_, err := r.db.Exec(ctx, query, log.ID, log.AdminID, log.Action, log.TargetType, log.TargetID, detailsJSON, log.CreatedAt)
	return err
}

func (r *pgModerationRepository) GetAuditLogs(ctx context.Context, limit, offset int) ([]domain.AdminAuditLog, error) {
	query := `
		SELECT id, admin_id, action, target_type, target_id, details, created_at
		FROM admin_audit_logs
		ORDER BY created_at DESC
		LIMIT $1 OFFSET $2
	`
	rows, err := r.db.Query(ctx, query, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []domain.AdminAuditLog
	for rows.Next() {
		var log domain.AdminAuditLog
		var detailsJSON []byte
		if err := rows.Scan(
			&log.ID,
			&log.AdminID,
			&log.Action,
			&log.TargetType,
			&log.TargetID,
			&detailsJSON,
			&log.CreatedAt,
		); err != nil {
			return nil, err
		}
		if len(detailsJSON) > 0 {
			_ = json.Unmarshal(detailsJSON, &log.Details)
		}
		list = append(list, log)
	}
	return list, rows.Err()
}

func (r *pgModerationRepository) CountReportsForUser(ctx context.Context, userID uuid.UUID) (int, error) {
	query := `SELECT COUNT(*) FROM reports WHERE reported_id = $1 AND status != 'dismissed'`
	var count int
	err := r.db.QueryRow(ctx, query, userID).Scan(&count)
	return count, err
}

func (r *pgModerationRepository) SetShadowBan(ctx context.Context, userID uuid.UUID, shadowBanned bool) error {
	query := `UPDATE profiles SET is_shadow_banned = $2, updated_at = NOW() WHERE user_id = $1`
	_, err := r.db.Exec(ctx, query, userID, shadowBanned)
	return err
}

func (r *pgModerationRepository) SetUserBanned(ctx context.Context, userID uuid.UUID, reason, adminID string) error {
	// 1. Mark user banned in users
	queryUser := `UPDATE users SET banned_at = NOW(), ban_reason = $2 WHERE id = $1 RETURNING phone, device_fingerprint`
	var phone string
	var deviceFP pgtype.Text
	err := r.db.QueryRow(ctx, queryUser, userID, reason).Scan(&phone, &deviceFP)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return err
	}

	// 2. Hide profile (shadow ban)
	_, _ = r.db.Exec(ctx, `UPDATE profiles SET is_shadow_banned = true, updated_at = NOW() WHERE user_id = $1`, userID)

	// 3. Reject all photos
	_, _ = r.db.Exec(ctx, `UPDATE profile_photos SET status = 'rejected', moderation_reason = 'user_banned' WHERE user_id = $1`, userID)

	// 4. Add banned phone to banned_identifiers
	if phone != "" {
		_ = r.AddBannedIdentifier(ctx, &domain.BannedIdentifier{
			Type:     domain.BannedIdentifierPhone,
			Value:    phone,
			Reason:   reason,
			BannedBy: adminID,
		})
	}

	// 5. Add banned device fingerprint if present
	if deviceFP.Valid && deviceFP.String != "" {
		_ = r.AddBannedIdentifier(ctx, &domain.BannedIdentifier{
			Type:     domain.BannedIdentifierDeviceFingerprint,
			Value:    deviceFP.String,
			Reason:   reason,
			BannedBy: adminID,
		})
	}

	return nil
}
