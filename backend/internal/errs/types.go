package errs

import (
	"fmt"
	"net/http"
)

func NewUserAlreadyExistsError(username string) *HTTPError {
	return &HTTPError{
		Code:    MakeUpperCaseWithUnderscores(http.StatusText(http.StatusConflict)),
		Message: fmt.Sprintf("User %s already exists", username),
		Status:  http.StatusConflict,
		Errors: []FieldError{
			{Field: "field", Error: "username"},
		}}
}

func NewInvalidUsernameFormat() *HTTPError {
	return &HTTPError{
		Code:    MakeUpperCaseWithUnderscores(http.StatusText(http.StatusBadRequest)),
		Message: fmt.Sprintf("Username contains invalid characters or is too long"),
		Status:  http.StatusBadRequest,
	}

}

func NewInvalidDisplayNameFormat() *HTTPError {
	return &HTTPError{
		Code:    MakeUpperCaseWithUnderscores(http.StatusText(http.StatusBadRequest)),
		Message: fmt.Sprintf("display name contains invalid characters or is too long"),
		Status:  http.StatusBadRequest,
	}

}

func NewPasswordToolong() *HTTPError {
	return &HTTPError{
		Code:    MakeUpperCaseWithUnderscores(http.StatusText(http.StatusBadRequest)),
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
func NewWeakPasswordError() *HTTPError {
	return &HTTPError{
		Code:    MakeUpperCaseWithUnderscores(http.StatusText(http.StatusBadRequest)),
		Message: fmt.Sprintf("Passwords must be more than 8 characters"),
		Status:  http.StatusUnauthorized,
	}

}
func NewUnAuthorizedToken() *HTTPError {
	return &HTTPError{
		Code:    MakeUpperCaseWithUnderscores(http.StatusText(http.StatusBadRequest)),
		Message: fmt.Sprintf("Missing, expired or revoked token."),
		Status:  http.StatusUnauthorized,
	}

}

func NewBadFormatError() *HTTPError {
	return &HTTPError{
		Code:    MakeUpperCaseWithUnderscores(http.StatusText(http.StatusBadRequest)),
		Message: fmt.Sprintf(" received incorrect format"),
		Status:  http.StatusBadRequest,
	}

}

func NewIncorrectCredintalsError() *HTTPError {
	return &HTTPError{
		Code:    MakeUpperCaseWithUnderscores(http.StatusText(http.StatusUnauthorized)),
		Message: fmt.Sprintf("Incorrect username or password"),
		Status:  http.StatusUnauthorized,
	}

}
