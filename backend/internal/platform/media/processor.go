package media

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"image"
	"image/color"
	"sync"

	"github.com/bbrks/go-blurhash"
	"github.com/davidbyttow/govips/v2/vips"
	"github.com/google/uuid"
	"github.com/rs/zerolog/log"
)

var (
	vipsOnce sync.Once
)

func EnsureVipsStarted() {
	vipsOnce.Do(func() {
		vips.Startup(&vips.Config{
			ConcurrencyLevel: 2,
			MaxCacheFiles:    0,
			MaxCacheMem:      50 * 1024 * 1024, // 50MB
			MaxCacheSize:     100,
		})
	})
}

type VariantInfo struct {
	Name        string `json:"name"`   // "thumb", "card", "full"
	Format      string `json:"format"` // "webp", "avif", "jpeg"
	Path        string `json:"path"`
	Width       int    `json:"width"`
	Height      int    `json:"height"`
	Size        int    `json:"size"`
	Data        []byte `json:"-"`
	ContentType string `json:"content_type"`
}

type ProcessResult struct {
	OriginalWidth  int
	OriginalHeight int
	BlurHash       string
	DominantColor  string
	Variants       []VariantInfo
	VariantsJSON   map[string]any
}

type ImageProcessor interface {
	Process(ctx context.Context, imgBytes []byte, userID uuid.UUID) (*ProcessResult, error)
}

type VipsProcessor struct{}

func NewProcessor() *VipsProcessor {
	EnsureVipsStarted()
	return &VipsProcessor{}
}

func (p *VipsProcessor) Process(ctx context.Context, imgBytes []byte, userID uuid.UUID) (*ProcessResult, error) {
	EnsureVipsStarted()

	// 1. Calculate SHA-256 for content-hash immutable path
	h := sha256.Sum256(imgBytes)
	contentHash := hex.EncodeToString(h[:])

	// 2. Load into libvips
	ref, err := vips.NewImageFromBuffer(imgBytes)
	if err != nil {
		return nil, fmt.Errorf("failed to decode image with libvips: %w", err)
	}
	defer ref.Close()

	// 3. Auto-orient based on EXIF, then strip all EXIF/GPS tags
	if err := ref.AutoRotate(); err != nil {
		log.Warn().Err(err).Msg("Failed to auto-rotate image; proceeding")
	}
	if err := ref.RemoveMetadata(); err != nil {
		log.Warn().Err(err).Msg("Failed to remove EXIF; proceeding")
	}

	origW := ref.Width()
	origH := ref.Height()

	// 4. Compute BlurHash (4x3) and Dominant Color from downsampled image
	stdImg, err := ref.ToImage(nil)
	var blurHashStr string
	var domColor string
	if err == nil && stdImg != nil {
		if bh, bhErr := blurhash.Encode(4, 3, stdImg); bhErr == nil {
			blurHashStr = bh
		}
		domColor = CalculateDominantColor(stdImg)
	}

	// 5. Generate variants:
	// thumb: 160px (WebP q75)
	// card: 480px (WebP q75, AVIF q50, JPEG fallback q75)
	// full: 1080px (WebP q75, AVIF q50)
	type variantConfig struct {
		name    string
		maxEdge int
		formats []string
	}

	configs := []variantConfig{
		{name: "thumb", maxEdge: 160, formats: []string{"webp"}},
		{name: "card", maxEdge: 480, formats: []string{"webp", "avif", "jpeg"}},
		{name: "full", maxEdge: 1080, formats: []string{"webp", "avif"}},
	}

	variants := make([]VariantInfo, 0, 6)
	variantsMap := make(map[string]any)
	variantsMap["dominant_color"] = domColor

	for _, cfg := range configs {
		scaled, err := resizeToLongEdge(ref, cfg.maxEdge)
		if err != nil {
			return nil, fmt.Errorf("failed to resize variant %s: %w", cfg.name, err)
		}

		vWidth := scaled.Width()
		vHeight := scaled.Height()

		cfgMap := make(map[string]any)

		for _, fmtType := range cfg.formats {
			var encodedBytes []byte
			var contentType string
			var ext string

			switch fmtType {
			case "webp":
				ext = "webp"
				contentType = "image/webp"
				params := vips.NewWebpExportParams()
				params.Quality = 75
				params.StripMetadata = true
				b, _, err := scaled.ExportWebp(params)
				if err != nil {
					log.Warn().Err(err).Str("variant", cfg.name).Msg("Failed to export WebP")
					continue
				}
				encodedBytes = b

			case "avif":
				ext = "avif"
				contentType = "image/avif"
				params := vips.NewAvifExportParams()
				params.Quality = 50
				params.StripMetadata = true
				b, _, err := scaled.ExportAvif(params)
				if err != nil {
					log.Warn().Err(err).Str("variant", cfg.name).Msg("Failed to export AVIF; skipping optional AVIF variant")
					continue
				}
				encodedBytes = b

			case "jpeg":
				ext = "jpg"
				contentType = "image/jpeg"
				params := vips.NewJpegExportParams()
				params.Quality = 75
				params.StripMetadata = true
				b, _, err := scaled.ExportJpeg(params)
				if err != nil {
					log.Warn().Err(err).Str("variant", cfg.name).Msg("Failed to export JPEG")
					continue
				}
				encodedBytes = b
			}

			objectPath := fmt.Sprintf("photos/%s/%s/%s.%s", userID.String(), contentHash, cfg.name, ext)

			vInfo := VariantInfo{
				Name:        cfg.name,
				Format:      fmtType,
				Path:        objectPath,
				Width:       vWidth,
				Height:      vHeight,
				Size:        len(encodedBytes),
				Data:        encodedBytes,
				ContentType: contentType,
			}
			variants = append(variants, vInfo)

			cfgMap[fmtType] = map[string]any{
				"path":   objectPath,
				"width":  vWidth,
				"height": vHeight,
				"size":   len(encodedBytes),
			}
		}

		scaled.Close()
		variantsMap[cfg.name] = cfgMap
	}

	return &ProcessResult{
		OriginalWidth:  origW,
		OriginalHeight: origH,
		BlurHash:       blurHashStr,
		DominantColor:  domColor,
		Variants:       variants,
		VariantsJSON:   variantsMap,
	}, nil
}

func resizeToLongEdge(img *vips.ImageRef, maxEdge int) (*vips.ImageRef, error) {
	w := img.Width()
	h := img.Height()
	longEdge := w
	if h > longEdge {
		longEdge = h
	}

	if longEdge <= maxEdge {
		return img.Copy()
	}

	scale := float64(maxEdge) / float64(longEdge)
	cloned, err := img.Copy()
	if err != nil {
		return nil, err
	}

	if err := cloned.Resize(scale, vips.KernelLanczos3); err != nil {
		cloned.Close()
		return nil, err
	}

	return cloned, nil
}

// CalculateDominantColor averages RGB pixels across the image
func CalculateDominantColor(img image.Image) string {
	if img == nil {
		return "#808080"
	}

	bounds := img.Bounds()
	stepX := (bounds.Dx() / 20) + 1
	stepY := (bounds.Dy() / 20) + 1

	var totalR, totalG, totalB, count int64
	for y := bounds.Min.Y; y < bounds.Max.Y; y += stepY {
		for x := bounds.Min.X; x < bounds.Max.X; x += stepX {
			c := color.RGBAModel.Convert(img.At(x, y)).(color.RGBA)
			totalR += int64(c.R)
			totalG += int64(c.G)
			totalB += int64(c.B)
			count++
		}
	}

	if count == 0 {
		return "#808080"
	}

	avgR := uint8(totalR / count)
	avgG := uint8(totalG / count)
	avgB := uint8(totalB / count)

	return fmt.Sprintf("#%02x%02x%02x", avgR, avgG, avgB)
}
