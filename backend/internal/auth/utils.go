package auth

import (
	"github.com/gin-gonic/gin"
	"strings"
)

func TokenFrom(c *gin.Context) string {
	if h := c.GetHeader("Authorization"); strings.HasPrefix(h, "Bearer ") {
		return strings.TrimPrefix(h, "Bearer ")
	}

	if cookie, err := c.Cookie(AuthCookie); err == nil && cookie != "" {
		return cookie
	}

	return ""
}
