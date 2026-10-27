package app

import (
	"context"
	"log/slog"
	"net/http"
	"time"

	"github.com/MIQATorg/MIQAT-backend/internal/auth"
	"github.com/MIQATorg/MIQAT-backend/internal/config"
	"github.com/MIQATorg/MIQAT-backend/internal/database"
	"github.com/gin-contrib/requestid"
	"github.com/gin-gonic/gin"
)

type Application struct {
	Config   config.Config
	Database *database.Database
	ctx      *context.Context
}

func (app *Application) Mount() http.Handler {
	r := gin.New()
	r.Use(gin.Logger())
	r.Use(gin.Recovery())

	r.Use(func(c *gin.Context) {
		slog.Info(
			"Incoming request",
			"method", c.Request.Method,
			"path", c.Request.URL.Path,
			"remote_addr", c.Request.RemoteAddr,
		)
		c.Next()
	})
	r.Use(requestid.New())

	authService := auth.NewAuthService(app.Database.Queries, app.Database.Pool)
	authHandler := auth.NewAuthHandler(&authService, &app.Config)
	public := r.Group("/")
	public.POST("/register", authHandler.RegisterUser)

	public.GET("/login", authHandler.LoginUser)
	public.POST("/logout", authHandler.Logout)

	protected := r.Group("/")
	{
		protected.Use(authHandler.AuthorizerMiddleware())
		protected.GET("/hello", func(c *gin.Context) {
			c.String(http.StatusOK, "Hello, World!")
		})
	}

	r.Use(authHandler.RoleIdentifierMiddleware())
	return r
}

func (app *Application) Run(h http.Handler) error {
	srv := &http.Server{
		Addr:         app.Config.Server.GetAddr(),
		Handler:      h,
		WriteTimeout: time.Duration(app.Config.Server.WriteTimeout) * time.Second,
		IdleTimeout:  time.Duration(app.Config.Server.IdleTimeout) * time.Second,
		ReadTimeout:  time.Duration(app.Config.Server.IdleTimeout) * time.Second,
	}

	slog.Info("Server has started", "addr", app.Config.Server.GetAddr())
	return srv.ListenAndServe()
}
