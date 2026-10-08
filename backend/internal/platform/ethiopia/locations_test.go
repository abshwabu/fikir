package ethiopia_test

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"

	"github.com/abshwabu/fikir/backend/internal/domain"
	"github.com/abshwabu/fikir/backend/internal/platform/ethiopia"
)

func TestValidateAge18(t *testing.T) {
	now := time.Now()

	// Exactly 18 years ago today
	birthday18 := now.AddDate(-18, 0, 0)
	assert.NoError(t, ethiopia.ValidateAge18(birthday18))

	// 25 years ago
	birthday25 := now.AddDate(-25, 0, 0)
	assert.NoError(t, ethiopia.ValidateAge18(birthday25))

	// 17 years and 364 days (underage)
	underage := now.AddDate(-18, 0, 1)
	assert.ErrorIs(t, ethiopia.ValidateAge18(underage), ethiopia.ErrUnderage)

	// 15 years old
	birthday15 := now.AddDate(-15, 0, 0)
	assert.ErrorIs(t, ethiopia.ValidateAge18(birthday15), ethiopia.ErrUnderage)
}

func TestResolveRegion(t *testing.T) {
	tests := []struct {
		city           string
		expectedRegion string
	}{
		{"Bole", "Addis Ababa"},
		{"bole", "Addis Ababa"},
		{"Kirkos", "Addis Ababa"},
		{"Adama", "Oromia"},
		{"Nazret", "Oromia"},
		{"Hawassa", "Sidama"},
		{"Bahir Dar", "Amhara"},
		{"Dire Dawa", "Dire Dawa"},
		{"Mekelle", "Tigray"},
		{"Gondar", "Amhara"},
		{"Jimma", "Oromia"},
		{"Harar", "Harari"},
		{"Dessie", "Amhara"},
	}

	for _, tt := range tests {
		_, region := ethiopia.ResolveRegion(tt.city)
		assert.Equal(t, tt.expectedRegion, region, "city: %s", tt.city)
	}
}

func TestCalculateCompletenessScore(t *testing.T) {
	p := &domain.Profile{
		DisplayName:  "Abebe",
		Birthdate:    time.Now().AddDate(-22, 0, 0),
		Gender:       "man",
		InterestedIn: []string{"woman"},
		Bio:          "Hello from Addis Ababa! Coffee lover.",
		City:         "Bole",
		JobTitle:     "Software Engineer",
		Languages:    []string{"am", "en"},
	}

	score0Photos := ethiopia.CalculateCompletenessScore(p, 0)
	assert.Equal(t, 85, score0Photos)

	score1Photo := ethiopia.CalculateCompletenessScore(p, 1)
	assert.Equal(t, 95, score1Photo)

	score2Photos := ethiopia.CalculateCompletenessScore(p, 2)
	assert.Equal(t, 100, score2Photos)
}
