package logger

import (
	"io"
	"os"
	"time"

	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
)

// New initializes and returns a configured zerolog.Logger.
func New(env string, level string) zerolog.Logger {
	var output io.Writer = os.Stdout

	if env == "development" || env == "dev" || env == "local" {
		output = zerolog.ConsoleWriter{
			Out:        os.Stdout,
			TimeFormat: time.RFC3339,
		}
	}

	lvl, err := zerolog.ParseLevel(level)
	if err != nil {
		lvl = zerolog.InfoLevel
	}

	logger := zerolog.New(output).
		Level(lvl).
		With().
		Timestamp().
		Caller().
		Logger()

	// Set as global logger
	log.Logger = logger

	return logger
}
