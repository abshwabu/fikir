package safety

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestSafetyAnalyzer_LimitsAndDetection(t *testing.T) {
	analyzer := NewSafetyAnalyzer()

	t.Run("Message exceeding 1000 characters is rejected", func(t *testing.T) {
		longText := strings.Repeat("A", 1001)
		_, err := analyzer.Analyze(longText)
		require.Error(t, err)
		assert.Contains(t, err.Error(), "exceeds maximum length")
	})

	t.Run("Clean message has no warning flags", func(t *testing.T) {
		res, err := analyzer.Analyze("Selam! Dehna neh?")
		require.NoError(t, err)
		assert.Empty(t, res.WarningFlags)
		assert.False(t, res.IsProfane)
		assert.Equal(t, "Selam! Dehna neh?", res.CleanBody)
	})

	t.Run("Detects Ethiopian phone numbers", func(t *testing.T) {
		testCases := []string{
			"Call me at +251911234567 please",
			"Here is my number 0912345678",
			"Safaricom: 0712345678",
			"Direct format: 911234567",
		}

		for _, tc := range testCases {
			res, err := analyzer.Analyze(tc)
			require.NoError(t, err)
			assert.Contains(t, res.WarningFlags, FlagHasPhoneNumber, "Expected phone number flag for: %s", tc)
		}
	})

	t.Run("Detects URLs and telegram links", func(t *testing.T) {
		testCases := []string{
			"Check my instagram https://instagram.com/myprofile",
			"Add me on telegram t.me/my_username",
			"Visit www.datingethiopia.et today",
		}

		for _, tc := range testCases {
			res, err := analyzer.Analyze(tc)
			require.NoError(t, err)
			assert.Contains(t, res.WarningFlags, FlagHasLink, "Expected link flag for: %s", tc)
		}
	})

	t.Run("Masks English and Amharic profanity", func(t *testing.T) {
		res, err := analyzer.Analyze("You are a bitch and bastard")
		require.NoError(t, err)
		assert.True(t, res.IsProfane)
		assert.Contains(t, res.WarningFlags, FlagProfanity)
		assert.Contains(t, res.CleanBody, "*****")

		resAm, err := analyzer.Analyze("አንተ ሸሌ ነህ")
		require.NoError(t, err)
		assert.True(t, resAm.IsProfane)
		assert.Contains(t, resAm.WarningFlags, FlagProfanity)
		assert.Contains(t, resAm.CleanBody, "**")
	})
}
