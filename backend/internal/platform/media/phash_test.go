package media

import (
	"image"
	"image/color"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestComputeDHashFromImage_AndHammingDistance(t *testing.T) {
	// Create a synthetic 100x100 gradient image
	img1 := image.NewRGBA(image.Rect(0, 0, 100, 100))
	for y := 0; y < 100; y++ {
		for x := 0; x < 100; x++ {
			img1.Set(x, y, color.RGBA{R: uint8(x * 2), G: uint8(y * 2), B: 100, A: 255})
		}
	}

	hash1 := ComputeDHashFromImage(img1)
	hex1 := HashToHex(hash1)
	assert.Len(t, hex1, 16)

	// Create nearly identical image with slight noise
	img2 := image.NewRGBA(image.Rect(0, 0, 100, 100))
	for y := 0; y < 100; y++ {
		for x := 0; x < 100; x++ {
			img2.Set(x, y, color.RGBA{R: uint8(x*2 + 1), G: uint8(y*2 + 1), B: 100, A: 255})
		}
	}
	hash2 := ComputeDHashFromImage(img2)
	hex2 := HashToHex(hash2)

	dist, err := HammingDistance(hex1, hex2)
	require.NoError(t, err)
	assert.LessOrEqual(t, dist, 2, "Near identical images should have very low Hamming distance")
	assert.True(t, IsSimilarPHash(hex1, hex2, 5))

	// Completely inverted image
	img3 := image.NewRGBA(image.Rect(0, 0, 100, 100))
	for y := 0; y < 100; y++ {
		for x := 0; x < 100; x++ {
			img3.Set(x, y, color.RGBA{R: uint8((100 - x) * 2), G: uint8(y * 2), B: 0, A: 255})
		}
	}
	hash3 := ComputeDHashFromImage(img3)
	hex3 := HashToHex(hash3)

	distInverted, err := HammingDistance(hex1, hex3)
	require.NoError(t, err)
	assert.Greater(t, distInverted, 20, "Different images should have high Hamming distance")
}
