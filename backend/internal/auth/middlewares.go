package auth

import (
	"context"
	"log/slog"
	"net/http"

	"github.com/MIQATorg/MIQAT-backend/internal/database/db"
	"github.com/MIQATorg/MIQAT-backend/internal/errs"
	"github.com/MIQATorg/MIQAT-backend/internal/helpers"
	"github.com/gin-gonic/gin"
)

const AuthorizedContextKey = "UserId"
const userRoleContextKey = "UserRole"
const AuthCookie = "auth.session"

func (h *AuthHandler) AuthorizerMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		tokenBase64 := TokenFrom(c)
		slog.Debug("", "tokenBase64", tokenBase64)
		if tokenBase64 == "" {
			helpers.WriteError(c.Writer, errs.NewUnAuthorizedToken())
			c.Abort()
			return

		}

		session, err := h.srvc.GetSessionByToken(c, tokenBase64)
		if err != nil {
			helpers.WriteError(c.Writer, errs.NewUnAuthorizedToken())
			c.Abort()
			return
		}
		if session == (db.LoginSession{}) {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
			c.Abort()
			return

		}
		ctx := context.WithValue(c.Request.Context(), AuthorizedContextKey, session.UserID.String())
		c.Request = c.Request.WithContext(ctx)
		c.Next()
		return
	}
}

func (h *AuthHandler) RoleIdentifierMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		tokenBase64 := TokenFrom(c)
		if tokenBase64 == "" {
			ctx := context.WithValue(c.Request.Context(), userRoleContextKey, nil)
			c.Request = c.Request.WithContext(ctx)
			c.Next()
			return
		}

		user, err := h.srvc.GetUserBySessionToken(c, tokenBase64)
		if user == (db.User{}) || err != nil {
			ctx := context.WithValue(c.Request.Context(), userRoleContextKey, nil)
			c.Request = c.Request.WithContext(ctx)
			c.Next()
			return
		}
		ctx := context.WithValue(c.Request.Context(), userRoleContextKey, user.Role)
		c.Request = c.Request.WithContext(ctx)
		c.Next()
		return
	}
}
