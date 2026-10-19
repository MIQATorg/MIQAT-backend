package helpers

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/MIQATorg/MIQAT-backend/internal/errs"
)

func WriteError(w http .ResponseWriter, err error) {
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

