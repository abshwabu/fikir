package repository

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/abshwabu/fikir/backend/internal/domain"
)

type pgSwipeRepository struct {
	q *Queries
}

func NewSwipeRepository(q *Queries) domain.SwipeRepository {
	return &pgSwipeRepository{q: q}
}

func (r *pgSwipeRepository) UpsertSwipe(ctx context.Context, swipe *domain.Swipe) error {
	var createdAt pgtype.Timestamptz
	if !swipe.CreatedAt.IsZero() {
		createdAt = pgtype.Timestamptz{Time: swipe.CreatedAt, Valid: true}
	} else {
		createdAt = pgtype.Timestamptz{Time: time.Now().UTC(), Valid: true}
	}

	return r.q.UpsertSwipe(ctx, UpsertSwipeParams{
		SwiperID:  swipe.SwiperID,
		TargetID:  swipe.TargetID,
		Direction: string(swipe.Direction),
		CreatedAt: createdAt,
	})
}

func (r *pgSwipeRepository) DeleteSwipe(ctx context.Context, swiperID, targetID uuid.UUID) error {
	return r.q.DeleteSwipe(ctx, DeleteSwipeParams{
		SwiperID: swiperID,
		TargetID: targetID,
	})
}

func (r *pgSwipeRepository) GetSwipe(ctx context.Context, swiperID, targetID uuid.UUID) (*domain.Swipe, error) {
	row, err := r.q.GetSwipe(ctx, GetSwipeParams{
		SwiperID: swiperID,
		TargetID: targetID,
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return &domain.Swipe{
		SwiperID:  row.SwiperID,
		TargetID:  row.TargetID,
		Direction: domain.SwipeDirection(row.Direction),
		CreatedAt: row.CreatedAt.Time,
	}, nil
}

func (r *pgSwipeRepository) CheckMutualLike(ctx context.Context, swiperID, targetID uuid.UUID) (bool, error) {
	return r.q.CheckMutualLike(ctx, CheckMutualLikeParams{
		SwiperID: swiperID,
		TargetID: targetID,
	})
}

func (r *pgSwipeRepository) GetLikesYouList(ctx context.Context, userID uuid.UUID, limit int) ([]domain.LikesYouItem, error) {
	rows, err := r.q.GetLikesYouList(ctx, GetLikesYouListParams{
		UserID:      userID,
		ResultLimit: int32(limit),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to query likes you list: %w", err)
	}

	items := make([]domain.LikesYouItem, len(rows))
	for i, row := range rows {
		items[i] = domain.LikesYouItem{
			UserID:    row.SwiperID,
			Direction: row.Direction,
			CreatedAt: row.CreatedAt.Time,
		}
	}
	return items, nil
}

func (r *pgSwipeRepository) CountLikesYou(ctx context.Context, userID uuid.UUID) (int64, error) {
	return r.q.CountLikesYou(ctx, userID)
}

// -------------------------------------------------------------
// Match Repository
// -------------------------------------------------------------

type pgMatchRepository struct {
	q             *Queries
	db            *pgxpool.Pool
	discoveryRepo domain.DiscoveryRepository
}

func NewMatchRepository(q *Queries, db *pgxpool.Pool, discoveryRepo domain.DiscoveryRepository) domain.MatchRepository {
	return &pgMatchRepository{
		q:             q,
		db:            db,
		discoveryRepo: discoveryRepo,
	}
}

func (r *pgMatchRepository) CreateMatch(ctx context.Context, userA, userB uuid.UUID) (*domain.Match, error) {
	// Ensure constraint: user_a < user_b
	first, second := userA, userB
	if second.String() < first.String() {
		first, second = second, first
	}

	row, err := r.q.CreateMatch(ctx, CreateMatchParams{
		ID:    uuid.New(),
		UserA: first,
		UserB: second,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to create match: %w", err)
	}

	var unmatchedAt *time.Time
	if row.UnmatchedAt.Valid {
		unmatchedAt = &row.UnmatchedAt.Time
	}

	return &domain.Match{
		ID:          row.ID,
		UserA:       row.UserA,
		UserB:       row.UserB,
		CreatedAt:   row.CreatedAt.Time,
		UnmatchedAt: unmatchedAt,
	}, nil
}

func (r *pgMatchRepository) GetByID(ctx context.Context, id uuid.UUID) (*domain.Match, error) {
	row, err := r.q.GetMatchByID(ctx, id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}

	var unmatchedAt *time.Time
	if row.UnmatchedAt.Valid {
		unmatchedAt = &row.UnmatchedAt.Time
	}

	return &domain.Match{
		ID:          row.ID,
		UserA:       row.UserA,
		UserB:       row.UserB,
		CreatedAt:   row.CreatedAt.Time,
		UnmatchedAt: unmatchedAt,
	}, nil
}

func (r *pgMatchRepository) GetBetweenUsers(ctx context.Context, userA, userB uuid.UUID) (*domain.Match, error) {
	first, second := userA, userB
	if second.String() < first.String() {
		first, second = second, first
	}

	row, err := r.q.GetMatchBetweenUsers(ctx, GetMatchBetweenUsersParams{
		UserA: first,
		UserB: second,
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}

	var unmatchedAt *time.Time
	if row.UnmatchedAt.Valid {
		unmatchedAt = &row.UnmatchedAt.Time
	}

	return &domain.Match{
		ID:          row.ID,
		UserA:       row.UserA,
		UserB:       row.UserB,
		CreatedAt:   row.CreatedAt.Time,
		UnmatchedAt: unmatchedAt,
	}, nil
}

func (r *pgMatchRepository) Unmatch(ctx context.Context, matchID, userID uuid.UUID) error {
	return r.q.Unmatch(ctx, UnmatchParams{
		ID:    matchID,
		UserA: userID,
	})
}

func (r *pgMatchRepository) ListForUser(ctx context.Context, userID uuid.UUID, limit int, cursorCreatedAt *time.Time) ([]domain.MatchWithPreview, *time.Time, error) {
	var cursor pgtype.Timestamptz
	if cursorCreatedAt != nil && !cursorCreatedAt.IsZero() {
		cursor = pgtype.Timestamptz{Time: *cursorCreatedAt, Valid: true}
	}

	rows, err := r.q.ListUserMatches(ctx, ListUserMatchesParams{
		UserID:          userID,
		CursorCreatedAt: cursor,
		ResultLimit:     int32(limit),
	})
	if err != nil {
		return nil, nil, fmt.Errorf("failed to list matches: %w", err)
	}

	matches := make([]domain.MatchWithPreview, len(rows))
	for i, row := range rows {
		var lastMsg *domain.LastMessagePreview
		if row.LastMessageID > 0 {
			var createdAt time.Time
			if row.LastMessageCreatedAt.Valid {
				createdAt = row.LastMessageCreatedAt.Time
			}
			lastMsg = &domain.LastMessagePreview{
				ID:        row.LastMessageID,
				SenderID:  row.LastMessageSenderID,
				Body:      row.LastMessageBody,
				Type:      row.LastMessageType,
				CreatedAt: createdAt,
			}
		}

		card, _ := r.discoveryRepo.GetProfileCard(ctx, row.OtherUserID, "")

		matches[i] = domain.MatchWithPreview{
			ID:          row.ID,
			UserA:       row.UserA,
			UserB:       row.UserB,
			CreatedAt:   row.CreatedAt.Time,
			OtherUser:   card,
			LastMessage: lastMsg,
		}
	}

	var nextCursor *time.Time
	if len(rows) == limit {
		lastTime := rows[len(rows)-1].CreatedAt.Time
		nextCursor = &lastTime
	}

	return matches, nextCursor, nil
}

// -------------------------------------------------------------
// Block Repository
// -------------------------------------------------------------

type pgBlockRepository struct {
	q *Queries
}

func NewBlockRepository(q *Queries) domain.BlockRepository {
	return &pgBlockRepository{q: q}
}

func (r *pgBlockRepository) CreateBlock(ctx context.Context, blockerID, blockedID uuid.UUID) error {
	return r.q.CreateBlock(ctx, CreateBlockParams{
		BlockerID: blockerID,
		BlockedID: blockedID,
	})
}

func (r *pgBlockRepository) IsBlocked(ctx context.Context, userA, userB uuid.UUID) (bool, error) {
	return r.q.IsBlocked(ctx, IsBlockedParams{
		BlockerID: userA,
		BlockedID: userB,
	})
}

// -------------------------------------------------------------
// Report Repository
// -------------------------------------------------------------

type pgReportRepository struct {
	q *Queries
}

func NewReportRepository(q *Queries) domain.ReportRepository {
	return &pgReportRepository{q: q}
}

func (r *pgReportRepository) CreateReport(ctx context.Context, report *domain.Report) error {
	var details pgtype.Text
	if report.Details != "" {
		details = pgtype.Text{String: report.Details, Valid: true}
	}

	row, err := r.q.CreateReport(ctx, CreateReportParams{
		ID:         report.ID,
		ReporterID: report.ReporterID,
		ReportedID: report.ReportedID,
		Reason:     report.Reason,
		Details:    details,
		Status:     report.Status,
	})
	if err != nil {
		return fmt.Errorf("failed to save report: %w", err)
	}

	report.CreatedAt = row.CreatedAt.Time
	return nil
}
