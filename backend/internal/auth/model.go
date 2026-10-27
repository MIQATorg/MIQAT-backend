package auth

import (
	"time"

	"github.com/MIQATorg/MIQAT-backend/internal/database/db"
	"github.com/google/uuid"
)

type RegisterInput struct {
	Username    string      `json:"username" binding:"required"`
	DisplayName string      `json:"display_name" binding:"required"`
	Password    string      `json:"password" binding:"required"`
	Platform    db.Platform `json:"platform" binding:"required"`
	WeekStart   int         `json:"week_start"`
	Timezone    string      `json:"timezone" binding:"required"`
	UserAgent   string      // UserAgent is not supplied from json.
	AppVersion  string      `json:"app_version"`
}

type UserResponse struct {
	ID          uuid.UUID   `json:"id"`
	Username    string      `json:"username"`
	DisplayName string      `json:"display_name"`
	Role        db.UserRole `json:"role"`
	CreatedAt   time.Time   `json:"created_at"`
}

type LoginInput struct {
	Username  string      `json:"username" binding:"required"`
	Password  string      `json:"password" binding:"required"`
	Platform  db.Platform `json:"platform" binding:"required"`
	UserAgent string      // UserAgent is not supplied from json.
}

type RegisterResult struct {
	User        UserResponse
	Tokenbase64 *string
	Session     *db.LoginSession
}
type LoginResult struct {
	User        UserResponse
	Tokenbase64 *string
	Session     *db.LoginSession
}
