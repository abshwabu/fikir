package safety

import (
	"context"
	"errors"
	"fmt"
	"net"
	"net/http"
	"time"
)

var (
	ErrPrivateIPBlocked = errors.New("request to private or loopback IP address blocked (SSRF protection)")
	ErrInvalidScheme    = errors.New("only http and https schemes are permitted")
)

var privateIPBlocks []*net.IPNet

func init() {
	for _, cidr := range []string{
		"127.0.0.0/8",    // IPv4 loopback
		"10.0.0.0/8",     // RFC1918
		"172.16.0.0/12",  // RFC1918
		"192.168.0.0/16", // RFC1918
		"169.254.0.0/16", // RFC3927 link-local & cloud metadata (AWS, GCP, DigitalOcean)
		"::1/128",        // IPv6 loopback
		"fc00::/7",       // IPv6 unique local
		"fe80::/10",      // IPv6 link-local
	} {
		_, block, _ := net.ParseCIDR(cidr)
		privateIPBlocks = append(privateIPBlocks, block)
	}
}

// IsPrivateIP checks if a resolved IP address belongs to private or link-local networks
func IsPrivateIP(ip net.IP) bool {
	if ip.IsLoopback() || ip.IsLinkLocalUnicast() || ip.IsLinkLocalMulticast() {
		return true
	}
	for _, block := range privateIPBlocks {
		if block.Contains(ip) {
			return true
		}
	}
	return false
}

// NewSSRFSafeClient creates an http.Client whose dialer rejects connections to private network ranges
func NewSSRFSafeClient(timeout time.Duration) *http.Client {
	dialer := &net.Dialer{
		Timeout:   timeout,
		KeepAlive: 30 * time.Second,
	}

	transport := &http.Transport{
		DialContext: func(ctx context.Context, network, addr string) (net.Conn, error) {
			host, port, err := net.SplitHostPort(addr)
			if err != nil {
				return nil, err
			}

			ips, err := net.DefaultResolver.LookupIP(ctx, "ip", host)
			if err != nil {
				return nil, err
			}

			for _, ip := range ips {
				if IsPrivateIP(ip) {
					return nil, fmt.Errorf("%w: %s (%s)", ErrPrivateIPBlocked, host, ip.String())
				}
			}

			return dialer.DialContext(ctx, network, net.JoinHostPort(ips[0].String(), port))
		},
		MaxIdleConns:        100,
		IdleConnTimeout:     90 * time.Second,
		TLSHandshakeTimeout: 10 * time.Second,
	}

	return &http.Client{
		Transport: transport,
		Timeout:   timeout,
	}
}

// SniffImageType verifies image magic bytes and returns detected MIME type
func SniffImageType(data []byte) (string, error) {
	if len(data) < 12 {
		return "", errors.New("data too short to identify image type")
	}

	// JPEG: FF D8 FF
	if data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF {
		return "image/jpeg", nil
	}

	// PNG: 89 50 4E 47 0D 0A 1A 0A
	if data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47 {
		return "image/png", nil
	}

	// WebP: RIFF .... WEBP
	if string(data[0:4]) == "RIFF" && string(data[8:12]) == "WEBP" {
		return "image/webp", nil
	}

	return "", errors.New("unsupported image format (only JPEG, PNG, and WebP are allowed)")
}
