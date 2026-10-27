package auth

import (
	"log/slog"
	"net/http"

	"github.com/MIQATorg/MIQAT-backend/internal/config"
	"github.com/MIQATorg/MIQAT-backend/internal/errs"
	"github.com/MIQATorg/MIQAT-backend/internal/helpers"
	"github.com/gin-gonic/gin"
)

type AuthHandler struct {
	srvc *AuthService
	cfg  *config.Config
}

func NewAuthHandler(service *AuthService, cfg *config.Config) *AuthHandler {
	return &AuthHandler{srvc: service, cfg: cfg}
}

func (h *AuthHandler) RegisterUser(c *gin.Context) {
	var regin RegisterInput
	if err := c.ShouldBindJSON(&regin); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	regin.UserAgent = c.Request.UserAgent()

	ret, err := h.srvc.Register(c, regin)

	if err != nil {
		helpers.WriteError(c.Writer, err)
		return
	}
	if ret.Session != nil {
		c.SetCookieData(&http.Cookie{Name: AuthCookie, Value: *ret.Tokenbase64, Expires: ret.Session.ExpiresAt, Path: "/", Secure: h.cfg.IsProduction(), SameSite: http.SameSiteLaxMode})
	}
	c.JSON(http.StatusCreated, gin.H{"access_token": *ret.Tokenbase64, "token_type": ret.Session.Kind, "login_session_id": ret.Session.ID.String(), "user": ret.User})
}

func (h *AuthHandler) Logout(c *gin.Context) {

	TokenBase64 := tokenFrom(c)
	if TokenBase64 == "" {
		helpers.WriteError(c.Writer, errs.NewBadFormatError())
		return
	}

	err := h.srvc.Logout(c.Request.Context(), TokenBase64)
	slog.Debug("", "err", err)
	if err != nil {
		helpers.WriteError(c.Writer, err)
		return
	}

	c.Status(http.StatusNoContent)
}

func (h *AuthHandler) LoginUser(c *gin.Context) {
	var input LoginInput

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	input.UserAgent = c.Request.UserAgent()
	ret, err := h.srvc.Login(c, input)
	if err != nil {
		helpers.WriteError(c.Writer, err)
		return
	}
	if ret.Session != nil {
		c.SetCookieData(&http.Cookie{Name: AuthCookie, Value: *ret.Tokenbase64, Expires: ret.Session.ExpiresAt, Path: "/", Secure: h.cfg.IsProduction(), SameSite: http.SameSiteLaxMode})
	}

	c.Status(http.StatusOK)
}
