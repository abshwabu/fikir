package safety_test

import (
	"net"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/abshwabu/fikir/backend/internal/platform/safety"
)

func TestIsPrivateIP(t *testing.T) {
	tests := []struct {
		ip       string
		expected bool
	}{
		{"127.0.0.1", true},
		{"10.0.0.5", true},
		{"172.16.1.1", true},
		{"192.168.1.100", true},
		{"169.254.169.254", true}, // AWS metadata IP
		{"::1", true},
		{"8.8.8.8", false},       // Google Public DNS
		{"1.1.1.1", false},       // Cloudflare DNS
		{"196.188.1.1", false},   // Ethio Telecom public IP
	}

	for _, tt := range tests {
		ip := net.ParseIP(tt.ip)
		require.NotNil(t, ip)
		assert.Equal(t, tt.expected, safety.IsPrivateIP(ip), "IP %s check failed", tt.ip)
	}
}

func TestSniffImageType(t *testing.T) {
	jpegBytes := []byte{0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01}
	pngBytes := []byte{0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D}
	webpBytes := []byte{'R', 'I', 'F', 'F', 0x00, 0x00, 0x00, 0x00, 'W', 'E', 'B', 'P'}
	exeBytes := []byte{'M', 'Z', 0x90, 0x00, 0x03, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00}

	mime, err := safety.SniffImageType(jpegBytes)
	require.NoError(t, err)
	assert.Equal(t, "image/jpeg", mime)

	mime, err = safety.SniffImageType(pngBytes)
	require.NoError(t, err)
	assert.Equal(t, "image/png", mime)

	mime, err = safety.SniffImageType(webpBytes)
	require.NoError(t, err)
	assert.Equal(t, "image/webp", mime)

	_, err = safety.SniffImageType(exeBytes)
	require.Error(t, err)
}
