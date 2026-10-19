package database

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"time"

	"github.com/MIQATorg/MIQAT-backend/internal/config"
	"github.com/MIQATorg/MIQAT-backend/internal/database/db"
	"github.com/jackc/pgx/v5/pgxpool"
)


type Database struct{
    databaseConfig config.DatabaseConfig
    Pool *pgxpool.Pool
    Queries *db.Queries
        

}

func NewDatabase(ctx context.Context, cfg *config.Config) *Database{
    d := Database{databaseConfig: cfg.Database}
    _,err := d.Connect(ctx,cfg)
    if err != nil{
        slog.Error(err.Error())
        os.Exit(1)
    }
    db.New(d.Pool)
    return &d
    
}

func (d *Database) Connect(ctx context.Context, cfg *config.Config) (*pgxpool.Pool, error) {
	pool, err := pgxpool.New(ctx, cfg.Database.GetConnString()) 
	if err != nil {
		return nil, fmt.Errorf("create pool: %w", err)
	}

	pingCtx, cancel := context.WithTimeout(ctx,time.Second * 5)
	defer cancel()
	if err := pool.Ping(pingCtx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("ping database: %w", err)
	}

    d.Pool = pool
	return pool, nil
}


func (d *Database) Close(pool *pgxpool.Pool){
    pool.Close()
}


// TODO: acquire function
