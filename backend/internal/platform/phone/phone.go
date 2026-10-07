package phone

import (
	"errors"
	"strings"

	"github.com/nyaruka/phonenumbers"
)

var (
	ErrInvalidPhone    = errors.New("invalid phone number")
	ErrNonMobileNumber = errors.New("only Ethiopian mobile phone numbers are allowed")
)

const DefaultRegion = "ET"

// NormalizeEthiopian parses and normalizes an Ethiopian mobile phone number to E.164.
// Accepts: 09xxxxxxxx, 9xxxxxxxx, +2519xxxxxxxx, 07xxxxxxxx, 7xxxxxxxx, +2517xxxxxxxx.
// Rejects: Non-mobile numbers (landlines), numbers from other countries, invalid formats.
func NormalizeEthiopian(raw string) (string, error) {
	cleaned := strings.TrimSpace(raw)
	cleaned = strings.ReplaceAll(cleaned, " ", "")
	cleaned = strings.ReplaceAll(cleaned, "-", "")
	cleaned = strings.ReplaceAll(cleaned, "(", "")
	cleaned = strings.ReplaceAll(cleaned, ")", "")

	if cleaned == "" {
		return "", ErrInvalidPhone
	}

	// Handle 9-digit input starting with 9 (Ethio Telecom) or 7 (Safaricom)
	if len(cleaned) == 9 && (strings.HasPrefix(cleaned, "9") || strings.HasPrefix(cleaned, "7")) {
		cleaned = "0" + cleaned
	}

	num, err := phonenumbers.Parse(cleaned, DefaultRegion)
	if err != nil {
		return "", ErrInvalidPhone
	}

	if !phonenumbers.IsValidNumber(num) {
		return "", ErrInvalidPhone
	}

	// Must be an Ethiopian number (+251)
	if num.GetCountryCode() != 251 {
		return "", ErrNonMobileNumber
	}

	// Verify number type is mobile
	numType := phonenumbers.GetNumberType(num)
	if numType != phonenumbers.MOBILE && numType != phonenumbers.FIXED_LINE_OR_MOBILE {
		return "", ErrNonMobileNumber
	}

	// Double check national number starts with 9 or 7 (mobile prefixes in Ethiopia)
	nationalNumber := phonenumbers.GetNationalSignificantNumber(num)
	if !strings.HasPrefix(nationalNumber, "9") && !strings.HasPrefix(nationalNumber, "7") {
		return "", ErrNonMobileNumber
	}

	return phonenumbers.Format(num, phonenumbers.E164), nil
}
