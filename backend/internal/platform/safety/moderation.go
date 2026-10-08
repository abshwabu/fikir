package safety

import (
	"regexp"
	"strings"
	"unicode/utf8"

	apperrors "github.com/abshwabu/fikir/backend/internal/platform/errors"
)

const (
	MaxMessageLength = 1000

	FlagHasLink        = "has_link"
	FlagHasPhoneNumber = "has_phone_number"
	FlagProfanity       = "profanity_detected"
)

// Regex patterns for URLs and Ethiopian phone numbers
var (
	urlRegex = regexp.MustCompile(`(?i)\b((https?://|ftp://|www\.)[^\s/$.?#].[^\s]*|t\.me/[a-zA-Z0-9_]+|[a-zA-Z0-9-]+\.(com|org|net|et|io|me|co)\b)`)

	// Ethiopian phone numbers: +251..., 09..., 07..., 9..., 7... with optional spaces/dashes
	phoneRegex = regexp.MustCompile(`(?:\+251[\s.-]?[97]\d{1}[\s.-]?\d{3}[\s.-]?\d{4}|0[97]\d{1}[\s.-]?\d{3}[\s.-]?\d{4}|\b[97]\d{8}\b)`)
)

// Default embedded word lists for English and Amharic profanity
var defaultProfanityWords = map[string]bool{
	// English profanities
	"fuck": true, "shit": true, "bitch": true, "asshole": true, "cunt": true,
	"dick": true, "pussy": true, "bastard": true, "slut": true, "whore": true,

	// Amharic common abusive / explicit terms (transliterated and fidel)
	"ሸርሙጣ": true, "sharmuta": true, "ሸሌ": true, "shele": true,
	"ቂንጥር": true, "qintir": true, "ቁላ": true, "qula": true,
	"በዳ": true, "beda": true, "እምስ": true, "imis": true,
}

type SafetyAnalyzer interface {
	Analyze(body string) (*SafetyResult, error)
	MaskProfanity(text string) string
}

type SafetyResult struct {
	CleanBody    string
	WarningFlags []string
	IsProfane    bool
}

type defaultAnalyzer struct {
	profanityList map[string]bool
}

func NewSafetyAnalyzer(customWords ...[]string) SafetyAnalyzer {
	words := make(map[string]bool)
	for k, v := range defaultProfanityWords {
		words[k] = v
	}
	if len(customWords) > 0 {
		for _, w := range customWords[0] {
			words[strings.ToLower(strings.TrimSpace(w))] = true
		}
	}
	return &defaultAnalyzer{
		profanityList: words,
	}
}

func (a *defaultAnalyzer) Analyze(body string) (*SafetyResult, error) {
	trimmed := strings.TrimSpace(body)
	if utf8.RuneCountInString(trimmed) > MaxMessageLength {
		return nil, apperrors.BadRequest("message exceeds maximum length of 1000 characters")
	}

	var flags []string

	// 1. Link detection
	if urlRegex.MatchString(trimmed) {
		flags = append(flags, FlagHasLink)
	}

	// 2. Phone number detection
	if phoneRegex.MatchString(trimmed) {
		flags = append(flags, FlagHasPhoneNumber)
	}

	// 3. Profanity inspection
	isProfane := false
	lower := strings.ToLower(trimmed)
	words := strings.Fields(lower)
	for _, w := range words {
		// Strip common punctuation
		clean := strings.Trim(w, "!?,.:;\"'()[]{}~`*_-")
		if a.profanityList[clean] {
			isProfane = true
			flags = append(flags, FlagProfanity)
			break
		}
	}

	cleanBody := a.MaskProfanity(trimmed)

	return &SafetyResult{
		CleanBody:    cleanBody,
		WarningFlags: flags,
		IsProfane:    isProfane,
	}, nil
}

func (a *defaultAnalyzer) MaskProfanity(text string) string {
	words := strings.Fields(text)
	for i, w := range words {
		clean := strings.ToLower(strings.Trim(w, "!?,.:;\"'()[]{}~`*_-"))
		if a.profanityList[clean] {
			words[i] = strings.Repeat("*", utf8.RuneCountInString(w))
		}
	}
	return strings.Join(words, " ")
}
