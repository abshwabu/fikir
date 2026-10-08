package push

import (
	"fmt"
	"strings"
)

const (
	CategoryNewMatch   = "new_match"
	CategoryNewMessage = "new_message"
	CategorySuperLike  = "super_like"

	LocaleEN = "en"
	LocaleAM = "am"
	LocaleOM = "om"
	LocaleTI = "ti"
)

type localizedTemplate struct {
	Title string
	Body  string
}

// Templates mapped by [category][locale]
var templates = map[string]map[string]localizedTemplate{
	CategoryNewMatch: {
		LocaleEN: {
			Title: "It's a Match! 🎉",
			Body:  "You and %s liked each other! Start the conversation.",
		},
		LocaleAM: {
			Title: "ተዛምደዋል! 🎉",
			Body:  "እርስዎ እና %s ተወዳድዳችኋል! ውይይት ይጀምሩ።",
		},
		LocaleOM: {
			Title: "Wal-simattaniittu! 🎉",
			Body:  "Atii fi %s wal jaallattaniittu! Dubbii jalqabaa.",
		},
		LocaleTI: {
			Title: "ተሰማሚዕኩም! 🎉",
			Body:  "ንስኻን %sን ተፋቒርኩም! ዕላል ጀምሩ።",
		},
	},
	CategoryNewMessage: {
		LocaleEN: {
			Title: "New message from %s",
			Body:  "%s",
		},
		LocaleAM: {
			Title: "ከ%s አዲስ መልእክት",
			Body:  "%s",
		},
		LocaleOM: {
			Title: "Ergaa haaraa %s irraa",
			Body:  "%s",
		},
		LocaleTI: {
			Title: "ካብ %s ሓድሽ መልእኽቲ",
			Body:  "%s",
		},
	},
	CategorySuperLike: {
		LocaleEN: {
			Title: "Someone Super Liked you! ⭐",
			Body:  "%s sent you a Super Like!",
		},
		LocaleAM: {
			Title: "ሱፐር ላይክ አግኝተዋል! ⭐",
			Body:  "%s ሱፐር ላይክ ልኮልዎታል!",
		},
		LocaleOM: {
			Title: "Super Like argatteetta! ⭐",
			Body:  "%s Super Like siif ergeera!",
		},
		LocaleTI: {
			Title: "ሱፐር ላይክ ረኺብካ! ⭐",
			Body:  "%s ሱፐር ላይክ ሰዲዱልካ!",
		},
	},
}

// NormalizeLocale cleans the locale string and picks the closest supported one (defaults to "en")
func NormalizeLocale(rawLocale string) string {
	l := strings.ToLower(strings.TrimSpace(rawLocale))
	if strings.HasPrefix(l, "am") {
		return LocaleAM
	}
	if strings.HasPrefix(l, "om") {
		return LocaleOM
	}
	if strings.HasPrefix(l, "ti") {
		return LocaleTI
	}
	return LocaleEN
}

// FormatPush renders localized title and body given category, locale, sender name, and message snippet
func FormatPush(category, rawLocale, senderName, snippet string) (string, string) {
	loc := NormalizeLocale(rawLocale)
	catTemplates, ok := templates[category]
	if !ok {
		catTemplates = templates[CategoryNewMessage]
	}

	tmpl, ok := catTemplates[loc]
	if !ok {
		tmpl = catTemplates[LocaleEN]
	}

	if senderName == "" {
		senderName = "Someone"
	}

	switch category {
	case CategoryNewMatch:
		return tmpl.Title, fmt.Sprintf(tmpl.Body, senderName)
	case CategorySuperLike:
		return tmpl.Title, fmt.Sprintf(tmpl.Body, senderName)
	case CategoryNewMessage:
		if snippet == "" {
			snippet = "Sent you a message"
		}
		// Truncate snippet if too long
		if len([]rune(snippet)) > 100 {
			snippet = string([]rune(snippet)[:97]) + "..."
		}
		return fmt.Sprintf(tmpl.Title, senderName), snippet
	default:
		return tmpl.Title, fmt.Sprintf(tmpl.Body, senderName)
	}
}
