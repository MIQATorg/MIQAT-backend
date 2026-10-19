package errs

import (
	"fmt"
	"net/http"
)


func NewUserAlreadyExistsError(username string) *HTTPError{
    return &HTTPError{
        Code: MakeUpperCaseWithUnderscores(http.StatusText(http.StatusConflict)),
        Message: fmt.Sprintf("User %s already exists",username),
        Status:  http.StatusConflict,
    }

}


func NewInvalidUsernameFormat() *HTTPError{
    return &HTTPError{
        Code: MakeUpperCaseWithUnderscores(http.StatusText(http.StatusBadRequest)),
        Message: fmt.Sprintf("Username contains invalid characters or is too long"),
        Status:  http.StatusBadRequest,
    }

}

func NewInvalidDisplayNameFormat() *HTTPError{
    return &HTTPError{
        Code: MakeUpperCaseWithUnderscores(http.StatusText(http.StatusBadRequest)),
        Message: fmt.Sprintf("display name contains invalid characters or is too long"),
        Status:  http.StatusBadRequest,
    }

}

func NewPasswordToolong() *HTTPError{
    return &HTTPError{
        Code: MakeUpperCaseWithUnderscores(http.StatusText(http.StatusBadRequest)),
        Message: fmt.Sprintf("Password exceeds maximum length allowed"),
        Status:  http.StatusBadRequest,
    }

}

func NewInternalServerError() *HTTPError {
	return &HTTPError{
		Code:     MakeUpperCaseWithUnderscores(http.StatusText(http.StatusInternalServerError)),
		Message:  "An unexpected error occurred",
		Status:   http.StatusInternalServerError,
		Override: false,
	}
}
