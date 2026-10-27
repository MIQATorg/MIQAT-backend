package helpers

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"strings"

	"github.com/MIQATorg/MIQAT-backend/internal/errs"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/gorilla/sessions"
)

func WriteError(w http.ResponseWriter, err error) {
	var httpErr *errs.HTTPError

	if errors.As(err, &httpErr) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(httpErr.Status)
		json.NewEncoder(w).Encode(httpErr)
		return
	}
	// Unexpected internal error
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusInternalServerError)
	json.NewEncoder(w).Encode(errs.NewInternalServerError().WithMessage(err.Error()))
}

func SaveAuthSession(c *gin.Context, uid uuid.UUID, store *sessions.CookieStore) {
	session, err := store.Get(c.Request, "auth.session")
	if err != nil {
		slog.Error("error creating session: ", "error", err)
	}
	session.Values["user_id"] = uid.String()
	session.Save(c.Request, c.Writer)
	if err != nil {
		slog.Error("error saving session: ", "error", err)
	}
}

func newToken() (raw string, hash []byte, err error) {
	b := make([]byte, 32)
	if _, err = rand.Read(b); err != nil {
		return "", nil, err
	}
	raw = base64.RawURLEncoding.EncodeToString(b)
	sum := sha256.Sum256([]byte(raw))
	return raw, sum[:], nil
}

func tokenFrom(c *gin.Context) string {
	if h := c.GetHeader("Authorization"); strings.HasPrefix(h, "Bearer ") {
		return strings.TrimPrefix(h, "Bearer ")
	}
	return ""
}
