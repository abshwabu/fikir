package media

import (
	"encoding/hex"
	"fmt"
	"image"
	"image/color"
	_ "image/jpeg"
	_ "image/png"
	"io"
	"math/bits"
	"strconv"
)

// ComputePHash generates a 64-bit difference hash (dHash) from an image.
// Returns a 16-character hexadecimal string representing the 64-bit fingerprint.
func ComputePHash(r io.Reader) (string, error) {
	img, _, err := image.Decode(r)
	if err != nil {
		return "", fmt.Errorf("failed to decode image for phash: %w", err)
	}

	hash := ComputeDHashFromImage(img)
	return fmt.Sprintf("%016x", hash), nil
}

// ComputeDHashFromImage computes 64-bit difference hash by resizing to 9x8 grayscale
func ComputeDHashFromImage(img image.Image) uint64 {
	bounds := img.Bounds()
	width := bounds.Dx()
	height := bounds.Dy()

	if width == 0 || height == 0 {
		return 0
	}

	// Sample a 9x8 grid of grayscale values
	const gridW = 9
	const gridH = 8

	var grid [gridH][gridW]uint8

	for y := 0; y < gridH; y++ {
		srcY := bounds.Min.Y + (y*height)/gridH
		for x := 0; x < gridW; x++ {
			srcX := bounds.Min.X + (x*width)/gridW
			c := img.At(srcX, srcY)
			gray := color.GrayModel.Convert(c).(color.Gray)
			grid[y][x] = gray.Y
		}
	}

	// Compare adjacent pixels on each row to yield 64 bits
	var hash uint64
	bitPos := 0
	for y := 0; y < gridH; y++ {
		for x := 0; x < gridW-1; x++ {
			if grid[y][x] > grid[y][x+1] {
				hash |= 1 << bitPos
			}
			bitPos++
		}
	}

	return hash
}

// HammingDistance calculates the bitwise difference between two 16-hex perceptual hashes
func HammingDistance(hash1Hex, hash2Hex string) (int, error) {
	if len(hash1Hex) != 16 || len(hash2Hex) != 16 {
		return -1, fmt.Errorf("invalid phash length: expected 16 hex chars")
	}

	h1, err := strconv.ParseUint(hash1Hex, 16, 64)
	if err != nil {
		return -1, fmt.Errorf("invalid hex in hash1: %w", err)
	}

	h2, err := strconv.ParseUint(hash2Hex, 16, 64)
	if err != nil {
		return -1, fmt.Errorf("invalid hex in hash2: %w", err)
	}

	diff := h1 ^ h2
	return bits.OnesCount64(diff), nil
}

// IsSimilarPHash returns true if Hamming distance <= threshold (typically 5-10 bits)
func IsSimilarPHash(hash1, hash2 string, threshold int) bool {
	dist, err := HammingDistance(hash1, hash2)
	if err != nil {
		return false
	}
	return dist <= threshold
}

// HashToHex converts uint64 to 16 hex string
func HashToHex(hash uint64) string {
	b := make([]byte, 8)
	for i := 7; i >= 0; i-- {
		b[i] = byte(hash & 0xff)
		hash >>= 8
	}
	return hex.EncodeToString(b)
}
