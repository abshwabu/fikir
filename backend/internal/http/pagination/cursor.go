package pagination

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"time"
)

const (
	DefaultLimit = 20
	MaxLimit     = 100
)

var (
	ErrInvalidCursor = errors.New("invalid pagination cursor")
)

// CursorData represents the decoded cursor payload
type CursorData struct {
	Timestamp time.Time `json:"t"`
	ID        string    `json:"id"`
}

// EncodeCursor serializes CursorData to a base64 URL-safe string
func EncodeCursor(t time.Time, id string) string {
	if id == "" {
		return ""
	}
	data := CursorData{
		Timestamp: t.UTC(),
		ID:        id,
	}
	bytes, err := json.Marshal(data)
	if err != nil {
		return ""
	}
	return base64.RawURLEncoding.EncodeToString(bytes)
}

// DecodeCursor deserializes a base64 URL-safe string back to CursorData
func DecodeCursor(cursorStr string) (*CursorData, error) {
	if cursorStr == "" {
		return nil, nil
	}
	bytes, err := base64.RawURLEncoding.DecodeString(cursorStr)
	if err != nil {
		return nil, ErrInvalidCursor
	}

	var data CursorData
	if err := json.Unmarshal(bytes, &data); err != nil || data.ID == "" {
		return nil, ErrInvalidCursor
	}

	return &data, nil
}

// Params holds parsed pagination query parameters
type Params struct {
	Limit  int
	Cursor string
}

// FromRequest extracts limit and cursor query parameters from an HTTP request
func FromRequest(r *http.Request) Params {
	q := r.URL.Query()
	limit := DefaultLimit

	if lStr := q.Get("limit"); lStr != "" {
		if l, err := strconv.Atoi(lStr); err == nil && l > 0 {
			limit = l
			if limit > MaxLimit {
				limit = MaxLimit
			}
		}
	}

	return Params{
		Limit:  limit,
		Cursor: q.Get("cursor"),
	}
}

// Metadata contains metadata about pagination state
type Metadata struct {
	NextCursor string `json:"next_cursor,omitempty"`
	HasMore    bool   `json:"has_more"`
	Count      int    `json:"count"`
}

// Response represents a standard paginated API envelope
type Response[T any] struct {
	Data       []T      `json:"data"`
	Pagination Metadata `json:"pagination"`
}

// NewResponse constructs a new paginated response
func NewResponse[T any](items []T, limit int, getCursor func(item T) (time.Time, string)) Response[T] {
	hasMore := len(items) > limit
	data := items
	if hasMore {
		data = items[:limit]
	}

	var nextCursor string
	if hasMore && len(data) > 0 {
		lastItem := data[len(data)-1]
		t, id := getCursor(lastItem)
		nextCursor = EncodeCursor(t, id)
	}

	return Response[T]{
		Data: data,
		Pagination: Metadata{
			NextCursor: nextCursor,
			HasMore:    hasMore,
			Count:      len(data),
		},
	}
}
