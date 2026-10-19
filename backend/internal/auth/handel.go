package auth

import (
	"log/slog"
	"net/http"

	"github.com/MIQATorg/MIQAT-backend/internal/helpers"
	"github.com/gin-gonic/gin"
)


type AuthHandler struct{
    srvc *AuthService
}

func NewAuthHandler(service *AuthService) *AuthHandler{
    return &AuthHandler{srvc: service}
}

func (h *AuthHandler) RegisterUser(c *gin.Context){
    slog.Info("register: request received")
    var regin RegisterInput
    if err := c.ShouldBindJSON(&regin); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }

    uid,err := h.srvc.Register(c.Request.Context(),regin)

    if err != nil{
        helpers.WriteError(c.Writer,err)
        return
    }

    c.JSON(http.StatusCreated,gin.H{"uuid":uid})

}
