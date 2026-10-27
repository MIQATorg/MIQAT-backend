package auth

import (
	"context"
	"log/slog"
	"net/http"
	"strings"

	"github.com/MIQATorg/MIQAT-backend/internal/database/db"
	"github.com/gin-gonic/gin"
)

const AuthorizedContextKey = "UserId"
const userRoleContextKey = "UserRole"
const AuthCookie = "auth.session"

func tokenFrom(c *gin.Context) string {
	if h := c.GetHeader("Authorization"); strings.HasPrefix(h, "Bearer ") {
		return strings.TrimPrefix(h, "Bearer ")
	}

	if cookie, err := c.Cookie(AuthCookie); err == nil && cookie != "" {
		return cookie
	}

	return ""
}

func (h *AuthHandler) AuthorizerMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		tokenBase64 := tokenFrom(c)
		slog.Debug("", "tokenBase64", tokenBase64)
		if tokenBase64 == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
			return

		}

		session, err := h.srvc.GetSessionByToken(c, tokenBase64)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
			return
		}
		if session == (db.LoginSession{}) {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
			return

		}
		ctx := context.WithValue(c.Request.Context(), AuthorizedContextKey, session.UserID.String())
		c.Request = c.Request.WithContext(ctx)
		c.Next()
	}
}

func (h *AuthHandler) RoleIdentifierMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		tokenBase64 := tokenFrom(c)
		if tokenBase64 == "" {
			ctx := context.WithValue(c.Request.Context(), userRoleContextKey, nil)
			c.Request = c.Request.WithContext(ctx)
			c.Next()
		}

		user, err := h.srvc.GetUserBySessionToken(c, tokenBase64)
		if user == (db.User{}) || err != nil {
			ctx := context.WithValue(c.Request.Context(), userRoleContextKey, nil)
			c.Request = c.Request.WithContext(ctx)
			c.Next()
		}
		ctx := context.WithValue(c.Request.Context(), userRoleContextKey, user.Role)
		c.Request = c.Request.WithContext(ctx)
		c.Next()
	}
}
