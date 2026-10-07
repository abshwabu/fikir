package pagination_test

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/abshwabu/fikir/backend/internal/http/pagination"
)

type TestItem struct {
	ID        string
	CreatedAt time.Time
}

func TestPagination_EncodeDecode(t *testing.T) {
	now := time.Now().UTC().Truncate(time.Millisecond)
	id := "550e8400-e29b-41d4-a716-446655440000"

	cursor := pagination.EncodeCursor(now, id)
	require.NotEmpty(t, cursor)

	data, err := pagination.DecodeCursor(cursor)
	require.NoError(t, err)
	require.NotNil(t, data)

	assert.Equal(t, id, data.ID)
	assert.True(t, now.Equal(data.Timestamp))
}

func TestPagination_DecodeEmpty(t *testing.T) {
	data, err := pagination.DecodeCursor("")
	require.NoError(t, err)
	assert.Nil(t, data)
}

func TestPagination_DecodeInvalid(t *testing.T) {
	_, err := pagination.DecodeCursor("not-a-valid-base64-string!!")
	assert.ErrorIs(t, err, pagination.ErrInvalidCursor)

	_, err = pagination.DecodeCursor("e30") // invalid JSON "{}"
	assert.ErrorIs(t, err, pagination.ErrInvalidCursor)
}

func TestPagination_FromRequest(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/users?limit=35&cursor=abc123xyz", nil)
	params := pagination.FromRequest(req)

	assert.Equal(t, 35, params.Limit)
	assert.Equal(t, "abc123xyz", params.Cursor)

	// Default limit
	reqDefault := httptest.NewRequest(http.MethodGet, "/users", nil)
	paramsDefault := pagination.FromRequest(reqDefault)
	assert.Equal(t, pagination.DefaultLimit, paramsDefault.Limit)
	assert.Empty(t, paramsDefault.Cursor)

	// Exceeding max limit
	reqMax := httptest.NewRequest(http.MethodGet, "/users?limit=500", nil)
	paramsMax := pagination.FromRequest(reqMax)
	assert.Equal(t, pagination.MaxLimit, paramsMax.Limit)
}

func TestPagination_NewResponse(t *testing.T) {
	now := time.Now().UTC()
	items := []TestItem{
		{ID: "1", CreatedAt: now.Add(-1 * time.Minute)},
		{ID: "2", CreatedAt: now.Add(-2 * time.Minute)},
		{ID: "3", CreatedAt: now.Add(-3 * time.Minute)},
	}

	// Case 1: items <= limit (hasMore = false)
	resp := pagination.NewResponse(items, 3, func(item TestItem) (time.Time, string) {
		return item.CreatedAt, item.ID
	})
	assert.False(t, resp.Pagination.HasMore)
	assert.Empty(t, resp.Pagination.NextCursor)
	assert.Len(t, resp.Data, 3)

	// Case 2: items > limit (hasMore = true)
	respMore := pagination.NewResponse(items, 2, func(item TestItem) (time.Time, string) {
		return item.CreatedAt, item.ID
	})
	assert.True(t, respMore.Pagination.HasMore)
	assert.NotEmpty(t, respMore.Pagination.NextCursor)
	assert.Len(t, respMore.Data, 2)
	assert.Equal(t, "2", respMore.Data[1].ID)

	// Verify next cursor decodes to item 2
	decoded, err := pagination.DecodeCursor(respMore.Pagination.NextCursor)
	require.NoError(t, err)
	assert.Equal(t, "2", decoded.ID)
}
