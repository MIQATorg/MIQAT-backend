package main

import (
	"context"
	"log/slog"
	"os"

	"github.com/MIQATorg/MIQAT-backend/internal/app"
	"github.com/MIQATorg/MIQAT-backend/internal/config"
	"github.com/MIQATorg/MIQAT-backend/internal/database"
	"github.com/MIQATorg/MIQAT-backend/internal/database/db"
	"github.com/MIQATorg/MIQAT-backend/internal/logging"
)

func main() {
	ctx := context.Background()
	cfg := config.LoadConfig()

	logging.SetLogger(*cfg)
	api := &app.Application{Config: *cfg}
	api.Database = database.NewDatabase(ctx, cfg)
	api.Database.Queries = db.New(api.Database.Pool)


	if err := api.Run(api.Mount()); err != nil {
		slog.Error("Server has failed to start", "error", err)
		os.Exit(1)
	}
}
