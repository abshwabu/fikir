package media_test

import (
	"bytes"
	"context"
	"fmt"
	"image"
	"image/color"
	"image/jpeg"
	"math/rand"
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/abshwabu/fikir/backend/internal/platform/media"
)

// generateTestJPEGWithGPS creates a realistic ~4MB JPEG image containing GPS EXIF markers
func generateTestJPEGWithGPS(t *testing.T, width, height int) []byte {
	t.Helper()

	img := image.NewRGBA(image.Rect(0, 0, width, height))
	rnd := rand.New(rand.NewSource(42))

	// Fill with gradient and texture to prevent aggressive JPEG deduplication
	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			r := uint8((x*255/width + rnd.Intn(40)) % 256)
			g := uint8((y*255/height + rnd.Intn(40)) % 256)
			b := uint8(((x+y)*255/(width+height) + rnd.Intn(40)) % 256)
			img.Set(x, y, color.RGBA{R: r, G: g, B: b, A: 255})
		}
	}

	var rawBuf bytes.Buffer
	err := jpeg.Encode(&rawBuf, img, &jpeg.Options{Quality: 96})
	require.NoError(t, err)

	rawBytes := rawBuf.Bytes()
	require.True(t, len(rawBytes) > 2, "JPEG must have SOI marker")

	// Inject custom APP1 EXIF segment with GPS metadata right after SOI (\xFF\xD8)
	// Standard TIFF header + GPS IFD tag with coordinates (Addis Ababa: 9.0107 N, 38.7612 E)
	gpsPayload := []byte("Exif\x00\x00II*\x00\x08\x00\x00\x00\x01\x00%i\x04\x00\x01\x00\x00\x00\x1a\x00\x00\x00" +
		"GPSInfo: Addis Ababa Lat 9.0107 Long 38.7612 Alt 2355m")
	app1Len := uint16(len(gpsPayload) + 2)

	var exifJPEG bytes.Buffer
	exifJPEG.Write(rawBytes[:2]) // SOI \xFF\xD8
	exifJPEG.WriteByte(0xFF)
	exifJPEG.WriteByte(0xE1) // APP1 marker
	exifJPEG.WriteByte(byte(app1Len >> 8))
	exifJPEG.WriteByte(byte(app1Len & 0xFF))
	exifJPEG.Write(gpsPayload)
	exifJPEG.Write(rawBytes[2:]) // Rest of image

	finalBytes := exifJPEG.Bytes()
	return finalBytes
}

func TestProcessor_PipelineAndEXIFStripping(t *testing.T) {
	processor := media.NewProcessor()
	userID := uuid.New()

	// 1. Generate ~4MB JPEG fixture with GPS EXIF (2200x2200 at Q96 produces ~3.5MB - 4.5MB)
	imgData := generateTestJPEGWithGPS(t, 2200, 2200)
	origSize := len(imgData)
	t.Logf("Generated test fixture size: %d bytes (%.2f MB)", origSize, float64(origSize)/(1024*1024))
	require.True(t, origSize > 3*1024*1024, "Image fixture should be at least 3MB")

	// Verify original contains the GPS marker before processing
	assert.True(t, bytes.Contains(imgData, []byte("GPSInfo")), "Original image must contain GPS info")
	assert.True(t, bytes.Contains(imgData, []byte("Addis Ababa")), "Original image must contain GPS location")

	// 2. Process image
	ctx := context.Background()
	result, err := processor.Process(ctx, imgData, userID)
	require.NoError(t, err)
	require.NotNil(t, result)

	// 3. Verify original dimensions preserved
	assert.Equal(t, 2200, result.OriginalWidth)
	assert.Equal(t, 2200, result.OriginalHeight)

	// 4. Verify BlurHash (4x3) & Dominant Color
	assert.NotEmpty(t, result.BlurHash, "BlurHash must not be empty")
	assert.True(t, len(result.BlurHash) >= 10, "BlurHash length should be valid")
	assert.True(t, strings.HasPrefix(result.DominantColor, "#"), "Dominant color must be hex string starting with #")
	assert.Equal(t, 7, len(result.DominantColor), "Dominant color must be #RRGGBB")

	// 5. Verify generated variants
	variantMap := make(map[string]media.VariantInfo)
	for _, v := range result.Variants {
		key := fmt.Sprintf("%s_%s", v.Name, v.Format)
		variantMap[key] = v

		// Verify GPS and EXIF are verifiably stripped from ALL output variants
		assert.False(t, bytes.Contains(v.Data, []byte("GPSInfo")), "Variant %s must NOT contain GPS metadata", key)
		assert.False(t, bytes.Contains(v.Data, []byte("Addis Ababa")), "Variant %s must NOT contain GPS coordinates", key)

		// Verify content hash naming convention: photos/{userId}/{sha256}/{variant}.{ext}
		assert.True(t, strings.HasPrefix(v.Path, fmt.Sprintf("photos/%s/", userID.String())),
			"Path %s must follow content-hash naming convention", v.Path)
	}

	// Verify thumb variant
	thumbWebp, ok := variantMap["thumb_webp"]
	require.True(t, ok, "thumb webp variant must exist")
	assert.Equal(t, 160, thumbWebp.Width)
	assert.Equal(t, 160, thumbWebp.Height)

	// Verify card variants
	cardWebp, ok := variantMap["card_webp"]
	require.True(t, ok, "card webp variant must exist")
	assert.Equal(t, 480, cardWebp.Width)
	assert.Equal(t, 480, cardWebp.Height)

	// ACCEPTANCE CRITERIA: A 4 MB phone photo ends up as a card WebP under ~40 KB
	t.Logf("Card WebP size: %d bytes (%.2f KB)", cardWebp.Size, float64(cardWebp.Size)/1024)
	assert.Less(t, cardWebp.Size, 40*1024, "Card WebP size must be under 40 KB")

	// Verify full variants
	fullWebp, ok := variantMap["full_webp"]
	require.True(t, ok, "full webp variant must exist")
	assert.Equal(t, 1080, fullWebp.Width)
	assert.Equal(t, 1080, fullWebp.Height)

	// ACCEPTANCE CRITERIA: A 4 MB phone photo ends up as a full WebP under ~200 KB
	t.Logf("Full WebP size: %d bytes (%.2f KB)", fullWebp.Size, float64(fullWebp.Size)/1024)
	assert.Less(t, fullWebp.Size, 200*1024, "Full WebP size must be under 200 KB")

	// ACCEPTANCE CRITERIA: Output sizes are < 15% of the original for a 4MB jpeg at 1080px
	ratio := float64(fullWebp.Size) / float64(origSize)
	t.Logf("Full WebP compression ratio: %.2f%% of original", ratio*100)
	assert.Less(t, ratio, 0.15, "Full WebP must be under 15% of original size")
}
