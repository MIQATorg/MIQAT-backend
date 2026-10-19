package auth

import (
	"context"
	"unicode/utf8"

	"github.com/MIQATorg/MIQAT-backend/internal/database/db"
	"github.com/MIQATorg/MIQAT-backend/internal/errs"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"golang.org/x/crypto/bcrypt"
)

func isEnglishNoSpecialChar(s string, is_display bool) bool {
    if s == "" {
        return false
    }
	for _, r := range s {
         if !((r >= 'A' && r <= 'Z') ||
            (r >= 'a' && r <= 'z') ||
            (r >= '0' && r <= '9')  || r == '_' || r==' '){ 
            return false
        }	

        if !is_display{
            if r==' ' {
                return false
                
            }
        }
    }
	return true
}

type AuthService struct {
	repo *db.Queries
}

func NewAuthService(q *db.Queries) AuthService {
	return AuthService{q}
}

func (s *AuthService) Register(ctx context.Context, reginput RegisterInput) (uuid.UUID, error) { 
	if  (utf8.RuneCountInString(reginput.Username) > 30) || !isEnglishNoSpecialChar(reginput.Username,false){
		return uuid.Nil, errs.NewInvalidUsernameFormat()
	}

    if (utf8.RuneCountInString(reginput.DisplayName) > 30) || !isEnglishNoSpecialChar(reginput.DisplayName,true)   {
		return uuid.Nil, errs.NewInvalidDisplayNameFormat()
	}

    exists, err := s.repo.UserExists(ctx, reginput.Username)
	if err != nil {
		return uuid.Nil, err
	}

	if exists {
		return uuid.Nil, errs.NewUserAlreadyExistsError(reginput.Username)
	}


    // bcrypt has a 72 byte limit.
    if len(reginput.Password) > 72 {
        return uuid.Nil,errs.NewPasswordToolong()
    }

    hashedPass,err := bcrypt.GenerateFromPassword([]byte(reginput.Password),12)
    if err != nil{
        return uuid.Nil,err
    }

    // first user is automatically the admin of the instance.
    // no instance should have > 1 admins.
    // TODO: support > 1 admin per instance.
    adminExists,err := s.repo.IsAdminStored(ctx)
    if err != nil {
        return uuid.Nil,err
    }


    var role db.UserRole

    if adminExists {
        role = db.UserRoleUser
    } else {
        role = db.UserRoleAdmin
    }


    user ,err:= s.repo.RegisterUser(ctx,db.RegisterUserParams{Username:reginput.Username,DisplayName:reginput.DisplayName,PasswordHash:pgtype.Text{String:string(hashedPass),Valid:true},Role:role})

    if err != nil {
        return uuid.Nil,err
    }
    
    return user.ID,nil
}
