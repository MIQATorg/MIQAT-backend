package logging 

import (
	"log/slog"
    "os"
	"github.com/MIQATorg/MIQAT-backend/internal/config"
)



func CreateLogger(cfg config.Config) (*slog.Logger){
    level := cfg.GetLogLevel()
    logLevel:= new(slog.LevelVar)
    var logger *slog.Logger
    switch (level){
    case "debug":
        logLevel.Set(slog.LevelDebug)
	case "info":
        logLevel.Set(slog.LevelInfo) 
	case "error":
        logLevel.Set(slog.LevelError)
	default:
        logLevel.Set(slog.LevelInfo) 
	}
    opts := &slog.HandlerOptions{
		Level: logLevel,
	}

    var handler slog.Handler

	if cfg.IsProduction() && cfg.Logging.Format == "json" {
		handler = slog.NewJSONHandler(os.Stdout, opts)
	} else {
		handler = slog.NewTextHandler(os.Stdout, opts)
	}

	logger = slog.New(handler).With("Application","MIQAT")

	return logger
}

