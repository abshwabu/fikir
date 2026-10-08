package ethiopia

import (
	"errors"
	"strings"
	"time"

	"github.com/abshwabu/fikir/backend/internal/domain"
)

var (
	ErrUnderage = errors.New("you must be at least 18 years old")
)

// CityRegionMap maps Ethiopian cities and Addis Ababa sub-cities to their respective regions
var CityRegionMap = map[string]string{
	// Addis Ababa sub-cities
	"addis ababa":        "Addis Ababa",
	"bole":               "Addis Ababa",
	"yeka":               "Addis Ababa",
	"kirkos":             "Addis Ababa",
	"arada":              "Addis Ababa",
	"gullele":            "Addis Ababa",
	"lideta":             "Addis Ababa",
	"kolfe keranio":      "Addis Ababa",
	"nefas silk-lafto":   "Addis Ababa",
	"akaky kaliti":       "Addis Ababa",
	"addis ketema":       "Addis Ababa",
	"lemi kura":          "Addis Ababa",

	// Major Ethiopian regional cities
	"adama":              "Oromia",
	"nazret":             "Oromia",
	"bishoftu":           "Oromia",
	"debre zeit":         "Oromia",
	"hawassa":            "Sidama",
	"bahir dar":          "Amhara",
	"dire dawa":          "Dire Dawa",
	"mekelle":            "Tigray",
	"gondar":             "Amhara",
	"jimma":              "Oromia",
	"dessie":             "Amhara",
	"harar":              "Harari",
	"shashemene":         "Oromia",
	"jigjiga":            "Somali",
	"asosa":              "Benishangul-Gumuz",
	"gambela":            "Gambela",
	"semera":             "Afar",
	"dilla":              "South Ethiopia",
	"hosanna":            "Central Ethiopia",
	"wolaita sodo":       "South Ethiopia",
	"arba minch":         "South Ethiopia",
	"debre birhan":       "Amhara",
	"kombolcha":          "Amhara",
	"nekemte":            "Oromia",
	"axum":               "Tigray",
	"adwa":               "Tigray",
	"amaye":              "Oromia",
}

// ResolveRegion returns the matching Ethiopian region for a given city or sub-city
func ResolveRegion(city string) (string, string) {
	cleanCity := strings.TrimSpace(city)
	if cleanCity == "" {
		return "", ""
	}

	key := strings.ToLower(cleanCity)
	if region, ok := CityRegionMap[key]; ok {
		// Capitalize standard name
		return cleanCity, region
	}

	// Default fallback to provided city and general region
	return cleanCity, "Ethiopia"
}

// IsValidCity checks if city is recognized in the Ethiopian seed list
func IsValidCity(city string) bool {
	key := strings.ToLower(strings.TrimSpace(city))
	_, ok := CityRegionMap[key]
	return ok
}

// ValidateAge18 strictly validates that birthdate corresponds to an age >= 18
func ValidateAge18(birthdate time.Time) error {
	now := time.Now()
	age := now.Year() - birthdate.Year()

	// Adjust if birthday hasn't occurred yet this calendar year
	if now.Month() < birthdate.Month() || (now.Month() == birthdate.Month() && now.Day() < birthdate.Day()) {
		age--
	}

	if age < 18 {
		return ErrUnderage
	}
	return nil
}

// CalculateCompletenessScore computes a 0-100 completeness score for a user profile
func CalculateCompletenessScore(p *domain.Profile, photoCount int) int {
	if p == nil {
		return 0
	}

	score := 0

	// Core mandatory fields
	if strings.TrimSpace(p.DisplayName) != "" {
		score += 10
	}
	if !p.Birthdate.IsZero() && ValidateAge18(p.Birthdate) == nil {
		score += 10
	}
	if strings.TrimSpace(p.Gender) != "" {
		score += 10
	}
	if len(p.InterestedIn) > 0 {
		score += 10
	}

	// Bio
	if len(strings.TrimSpace(p.Bio)) >= 10 {
		score += 15
	}

	// Location
	if strings.TrimSpace(p.City) != "" || p.Location != nil {
		score += 15
	}

	// Professional / Education details
	if strings.TrimSpace(p.JobTitle) != "" || strings.TrimSpace(p.Education) != "" {
		score += 10
	}

	// Languages or interests
	if len(p.Languages) > 0 {
		score += 5
	}

	// Photos (minimum 1 photo for discovery + bonus for additional photos)
	if photoCount >= 2 {
		score += 15
	} else if photoCount >= 1 {
		score += 10
	}

	if score > 100 {
		score = 100
	}

	return score
}
