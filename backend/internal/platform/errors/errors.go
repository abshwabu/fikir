package errors

import (
	"fmt"
	"net/http"
)

// Standard error codes
const (
	CodeInternalServer  = "INTERNAL_SERVER_ERROR"
	CodeNotFound        = "NOT_FOUND"
	CodeBadRequest      = "BAD_REQUEST"
	CodeUnauthorized    = "UNAUTHORIZED"
	CodeForbidden       = "FORBIDDEN"
	CodeConflict        = "CONFLICT"
	CodeTooManyRequests = "TOO_MANY_REQUESTS"
	CodeValidation      = "VALIDATION_ERROR"
	CodeServiceUnavail  = "SERVICE_UNAVAILABLE"
)

// ErrorDetail represents field-level validation errors
type ErrorDetail struct {
	Field   string `json:"field,omitempty"`
	Message string `json:"message"`
}

// ErrorResponse represents the top-level error envelope:
// { "error": { "code": "...", "message": "...", "details": [...] } }
type ErrorResponse struct {
	Error ErrorBody `json:"error"`
}

// ErrorBody represents the error content
type ErrorBody struct {
	Code    string        `json:"code"`
	Message string        `json:"message"`
	Details []ErrorDetail `json:"details,omitempty"`
}

// AppError represents an application error with HTTP status and code
type AppError struct {
	StatusCode int
	Code       string
	Message    string
	Details    []ErrorDetail
	Err        error
}

func (e *AppError) Error() string {
	if e.Err != nil {
		return fmt.Sprintf("[%s] %s: %v", e.Code, e.Message, e.Err)
	}
	return fmt.Sprintf("[%s] %s", e.Code, e.Message)
}

func (e *AppError) Unwrap() error {
	return e.Err
}

// New creates a new AppError
func New(status int, code string, message string) *AppError {
	return &AppError{
		StatusCode: status,
		Code:       code,
		Message:    message,
	}
}

// Wrap creates an AppError wrapping an underlying error
func Wrap(status int, code string, message string, err error) *AppError {
	return &AppError{
		StatusCode: status,
		Code:       code,
		Message:    message,
		Err:        err,
	}
}

// Common error constructors
func BadRequest(msg string) *AppError {
	return New(http.StatusBadRequest, CodeBadRequest, msg)
}

func NotFound(msg string) *AppError {
	return New(http.StatusNotFound, CodeNotFound, msg)
}

func Unauthorized(msg string) *AppError {
	return New(http.StatusUnauthorized, CodeUnauthorized, msg)
}

func Forbidden(msg string) *AppError {
	return New(http.StatusForbidden, CodeForbidden, msg)
}

func Conflict(msg string) *AppError {
	return New(http.StatusConflict, CodeConflict, msg)
}

func TooManyRequests(msg string) *AppError {
	return New(http.StatusTooManyRequests, CodeTooManyRequests, msg)
}

func Internal(err error) *AppError {
	return Wrap(http.StatusInternalServerError, CodeInternalServer, "An internal server error occurred", err)
}

func ServiceUnavailable(msg string) *AppError {
	return New(http.StatusServiceUnavailable, CodeServiceUnavail, msg)
}

func ValidationError(details []ErrorDetail) *AppError {
	return &AppError{
		StatusCode: http.StatusBadRequest,
		Code:       CodeValidation,
		Message:    "Request validation failed",
		Details:    details,
	}
}
