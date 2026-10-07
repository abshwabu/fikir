package phone_test

import (
	"testing"

	"github.com/abshwabu/fikir/backend/internal/platform/phone"
	"github.com/stretchr/testify/assert"
)

func TestNormalizeEthiopian(t *testing.T) {
	tests := []struct {
		name        string
		input       string
		expected    string
		expectError bool
	}{
		// Valid Ethio Telecom mobile numbers
		{
			name:        "Ethio Telecom with leading 0",
			input:       "0911223344",
			expected:    "+251911223344",
			expectError: false,
		},
		{
			name:        "Ethio Telecom 9 digits without leading 0",
			input:       "911223344",
			expected:    "+251911223344",
			expectError: false,
		},
		{
			name:        "Ethio Telecom with E.164 prefix",
			input:       "+251911223344",
			expected:    "+251911223344",
			expectError: false,
		},
		{
			name:        "Ethio Telecom formatted with spaces",
			input:       "09 11 22 33 44",
			expected:    "+251911223344",
			expectError: false,
		},
		{
			name:        "Ethio Telecom formatted with hyphens",
			input:       "091-122-3344",
			expected:    "+251911223344",
			expectError: false,
		},
		// Valid Safaricom Ethiopia mobile numbers
		{
			name:        "Safaricom with leading 0",
			input:       "0712345678",
			expected:    "+251712345678",
			expectError: false,
		},
		{
			name:        "Safaricom 9 digits without leading 0",
			input:       "712345678",
			expected:    "+251712345678",
			expectError: false,
		},
		{
			name:        "Safaricom with E.164 prefix",
			input:       "+251712345678",
			expected:    "+251712345678",
			expectError: false,
		},
		// Rejected numbers
		{
			name:        "Ethiopian landline (Addis Ababa 011)",
			input:       "0115512345",
			expected:    "",
			expectError: true,
		},
		{
			name:        "Ethiopian landline with country code (+25111)",
			input:       "+251115512345",
			expected:    "",
			expectError: true,
		},
		{
			name:        "US phone number",
			input:       "+14155552671",
			expected:    "",
			expectError: true,
		},
		{
			name:        "Kenya phone number",
			input:       "+254712345678",
			expected:    "",
			expectError: true,
		},
		{
			name:        "Too short",
			input:       "091122",
			expected:    "",
			expectError: true,
		},
		{
			name:        "Too long",
			input:       "091122334455",
			expected:    "",
			expectError: true,
		},
		{
			name:        "Non-numeric characters",
			input:       "abcdefghij",
			expected:    "",
			expectError: true,
		},
		{
			name:        "Empty string",
			input:       "",
			expected:    "",
			expectError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := phone.NormalizeEthiopian(tt.input)
			if tt.expectError {
				assert.Error(t, err)
				assert.Empty(t, result)
			} else {
				assert.NoError(t, err)
				assert.Equal(t, tt.expected, result)
			}
		})
	}
}
