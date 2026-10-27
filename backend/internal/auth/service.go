package auth

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"log/slog"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/MIQATorg/MIQAT-backend/internal/database/db"
	"github.com/MIQATorg/MIQAT-backend/internal/errs"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
)

func hashToken(raw string) string {
	sum := sha256.Sum256([]byte(raw))
	return hex.EncodeToString(sum[:])
}

func toUserResponse(user db.User) UserResponse {
	return UserResponse{
		ID:          user.ID,
		Username:    user.Username,
		DisplayName: user.DisplayName,
		Role:        user.Role,
		CreatedAt:   user.CreatedAt,
	}
}

func newToken() (raw string, hash string, err error) {
	b := make([]byte, 32)
	if _, err = rand.Read(b); err != nil {
		return "", "", err
	}
	raw = base64.RawURLEncoding.EncodeToString(b)
	return raw, hashToken(raw), nil
}

func (s *AuthService) CreateUserSession(ctx context.Context, user db.User, platform db.Platform, userAgent string) (db.LoginSession, string, error) {
	// user session
	tokenbase64, tokenHash, err := newToken()
	if err != nil {
		// continue normally without session. user created settings created but user has to login again.
		slog.Error("creating token", "error", err)
		return db.LoginSession{}, "", nil
	}
	sess, err := s.repo.CreateSession(ctx, db.CreateSessionParams{UserAgent: userAgent, UserID: user.ID, Kind: db.SessionKindDevice, TokenHash: tokenHash, Platform: platform, ExpiresAt: time.Now().AddDate(0, 1, 0)})
	session := &sess
	if err != nil {

		slog.Error("creating session", "error", err)
		return db.LoginSession{}, "", nil
	}
	return *session, tokenbase64, nil

}

func parseTimezone(tz string) string {
	if tz == "" || tz == "Local" || len(tz) > 64 {
		return "UTC"
	}
	_, err := time.LoadLocation(tz)
	if err != nil {
		return "UTC"
	}
	return tz
}

func isEnglishNoSpecialChar(s string, is_display bool) bool {
	if s == "" {
		return false
	}
	for _, r := range s {
		if !((r >= 'A' && r <= 'Z') ||
			(r >= 'a' && r <= 'z') ||
			(r >= '0' && r <= '9') || r == '_' || r == ' ' || r == '-' || r == '.') {
			return false
		}

		if !is_display {
			if r == ' ' {
				return false
			}
		}
	}
	return true
}

type AuthService struct {
	repo *db.Queries
	pool *pgxpool.Pool
}

func NewAuthService(q *db.Queries, pool *pgxpool.Pool) AuthService {
	return AuthService{q, pool}
}

func (s *AuthService) Register(ctx context.Context, input RegisterInput) (RegisterResult, error) {
	input.DisplayName = strings.TrimSpace(input.DisplayName)
	input.Username = strings.TrimSpace(input.Username)
	if (utf8.RuneCountInString(input.Username) > 32) || !isEnglishNoSpecialChar(input.Username, false) {
		return RegisterResult{UserResponse{}, nil, nil}, errs.NewInvalidUsernameFormat()
	}

	if (utf8.RuneCountInString(input.DisplayName) > 32) || !isEnglishNoSpecialChar(input.DisplayName, true) {
		return RegisterResult{UserResponse{}, nil, nil}, errs.NewInvalidDisplayNameFormat()
	}

	input.Timezone = parseTimezone(input.Timezone)

	// FOLLOWING: NIST 800-63B
	// TODO: breached-password check
	if utf8.RuneCountInString(input.Password) < 8 {
		return RegisterResult{UserResponse{}, nil, nil}, errs.NewWeakPasswordError()
	}
	// bcrypt has a 72 byte limit.
	if len(input.Password) > 72 {
		return RegisterResult{UserResponse{}, nil, nil}, errs.NewPasswordToolong()
	}

	exists, err := s.isUserExistsByUsername(ctx, input.Username)
	slog.Debug("", "exists", exists)
	if err != nil {
		return RegisterResult{UserResponse{}, nil, nil}, err
	}

	if exists {
		return RegisterResult{UserResponse{}, nil, nil}, errs.NewUserAlreadyExistsError(input.Username)
	}

	hashedPass, err := bcrypt.GenerateFromPassword([]byte(input.Password), 12)
	if err != nil {
		return RegisterResult{UserResponse{}, nil, nil}, err
	}

	// first user is automatically the admin of the instance.
	// no instance should have > 1 admins.
	// TODO: support > 1 admin per instance.
	adminExists, err := s.repo.IsAdminStored(ctx)
	if err != nil {
		return RegisterResult{UserResponse{}, nil, nil}, err
	}

	var role db.UserRole

	if adminExists {
		role = db.UserRoleUser
	} else {
		role = db.UserRoleAdmin
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {

		slog.Error("creating transaction", "error", err)
		return RegisterResult{UserResponse{}, nil, nil}, errs.NewInternalServerError()
	}
	defer tx.Rollback(ctx)
	qtx := s.repo.WithTx(tx)
	user, err := qtx.RegisterUser(ctx, db.RegisterUserParams{Username: input.Username, DisplayName: input.DisplayName, PasswordHash: pgtype.Text{String: string(hashedPass), Valid: true}, Role: role})
	if err != nil {

		slog.Error("creating user", "error", err)
		return RegisterResult{UserResponse{}, nil, nil}, err
	}

	// insert default settings
	err = qtx.CreateUserSettings(ctx, db.CreateUserSettingsParams{UserID: user.ID, Timezone: input.Timezone})
	if err != nil {

		slog.Error("creating user settings", "error", err)
		return RegisterResult{UserResponse{}, nil, nil}, errs.NewInternalServerError()
	}

	err = tx.Commit(ctx)
	if err != nil {
		slog.Error("creating user", "error", err)
		return RegisterResult{UserResponse{}, nil, nil}, errs.NewInternalServerError()
	}

	session, tokenbase64, err := s.CreateUserSession(ctx, user, input.Platform, input.UserAgent)
	if err != nil {
		return RegisterResult{toUserResponse(user), &tokenbase64, nil}, nil
	}
	return RegisterResult{toUserResponse(user), &tokenbase64, &session}, nil
}

func (s *AuthService) Login(ctx context.Context, input LoginInput) (LoginResult, error) {
	if len(input.Password) > 72 {
		return LoginResult{UserResponse{}, nil, nil}, errs.NewPasswordToolong()
	}
	user, err := s.repo.GetUserForLogin(ctx, input.Username)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			// return generic IncorrectCredintalsError do not inform the user wether the Username exists or not.
			var dummyHash, _ = bcrypt.GenerateFromPassword([]byte("timing-equalizer"), 12)
			bcrypt.CompareHashAndPassword(dummyHash, []byte(input.Password))
			return LoginResult{UserResponse{}, nil, nil}, errs.NewIncorrectCredintalsError()
		}
		// db error
		return LoginResult{UserResponse{}, nil, nil}, errs.NewInternalServerError()
	}

	err = bcrypt.CompareHashAndPassword([]byte(user.PasswordHash.String), []byte(input.Password))
	if err != nil {
		return LoginResult{UserResponse{}, nil, nil}, errs.NewIncorrectCredintalsError()
	}
	session, tokenbase64, err := s.CreateUserSession(ctx, user, input.Platform, input.UserAgent)

	return LoginResult{UserResponse{}, &tokenbase64, &session}, nil
}

func (s *AuthService) isUserExistsById(ctx context.Context, user_id uuid.UUID) (bool, error) {
	if user_id == uuid.Nil {
		return false, nil
	}
	_, err := s.repo.IsUserExistsById(ctx, user_id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return false, nil
		}
		return false, err
	}
	return true, nil
}

func (s *AuthService) isUserExistsByUsername(ctx context.Context, username string) (bool, error) {
	if username == "" {
		return false, errors.New("incorrect username format")
	}

	exists, err := s.repo.IsUserExistsByUsername(ctx, username)

	if err != nil {
		return true, err
	}
	return exists, nil
}

func (s *AuthService) GetUserBySessionToken(ctx context.Context, tokenbase64 string) (db.User, error) {
	if tokenbase64 == "" {
		return db.User{}, nil
	}
	TokenHash := hashToken(tokenbase64)

	user, err := s.repo.GetUserBySessionTokenHash(ctx, TokenHash)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return db.User{}, nil
		}
		return db.User{}, err
	}

	return user, err
}

func (s *AuthService) GetSessionByToken(ctx context.Context, tokenbase64 string) (db.LoginSession, error) {
	if tokenbase64 == "" {
		return db.LoginSession{}, nil
	}
	TokenHash := hashToken(tokenbase64)
	slog.Debug("", "tokenhash", TokenHash)
	session, err := s.repo.GetSessionByTokenHash(ctx, TokenHash)
	slog.Debug("", "session", session.UserID, "err", err)
	if err != nil {
		slog.Error("getting session", "error", err)
		return db.LoginSession{}, err
	}

	return session, nil
}

func (s *AuthService) Logout(ctx context.Context, TokenBase64 string) error {
	if TokenBase64 == "" {
		return errs.NewUnAuthorizedToken()
	}

	_, err := s.repo.RevokeSessionByToken(ctx, hashToken(TokenBase64))
	if err != nil {
		return errs.NewUnAuthorizedToken()
	}

	return nil

}
func (s *AuthService) GetUserRoleById(ctx context.Context, user_id uuid.UUID) (db.UserRole, error) {
	if user_id == uuid.Nil {
		return "", nil
	}
	role, err := s.repo.GetUserRoleById(ctx, user_id)
	if err != nil {
		return "", err
	}
	return role, nil
}
