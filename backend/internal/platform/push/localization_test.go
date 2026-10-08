package push

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestPushLocalization(t *testing.T) {
	t.Run("New match localized in all 4 languages", func(t *testing.T) {
		titleEn, bodyEn := FormatPush(CategoryNewMatch, "en", "Sara", "")
		assert.Contains(t, titleEn, "Match")
		assert.Contains(t, bodyEn, "Sara")

		titleAm, bodyAm := FormatPush(CategoryNewMatch, "am", "ሳራ", "")
		assert.Contains(t, titleAm, "ተዛምደዋል")
		assert.Contains(t, bodyAm, "ሳራ")

		titleOm, bodyOm := FormatPush(CategoryNewMatch, "om", "Caaltuu", "")
		assert.Contains(t, titleOm, "Wal-simattaniittu")
		assert.Contains(t, bodyOm, "Caaltuu")

		titleTi, bodyTi := FormatPush(CategoryNewMatch, "ti", "ሳባ", "")
		assert.Contains(t, titleTi, "ተሰማሚዕኩም")
		assert.Contains(t, bodyTi, "ሳባ")
	})

	t.Run("New message localized with snippet", func(t *testing.T) {
		titleAm, bodyAm := FormatPush(CategoryNewMessage, "am", "አበበ", "ሰላም እንደምን ነህ?")
		assert.Contains(t, titleAm, "ከአበበ አዲስ መልእክት")
		assert.Equal(t, "ሰላም እንደምን ነህ?", bodyAm)
	})

	t.Run("Super like localized in Afaan Oromoo", func(t *testing.T) {
		titleOm, bodyOm := FormatPush(CategorySuperLike, "om", "Tolasa", "")
		assert.Contains(t, titleOm, "Super Like")
		assert.Contains(t, bodyOm, "Tolasa")
	})

	t.Run("Unknown locale defaults gracefully to English", func(t *testing.T) {
		title, body := FormatPush(CategoryNewMatch, "fr", "Amina", "")
		assert.Contains(t, title, "Match")
		assert.Contains(t, body, "Amina")
	})
}
