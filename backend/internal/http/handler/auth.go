package handler

import (
	"encoding/json"
	"net"
	"net/http"
	"strings"

	"github.com/google/uuid"

	"github.com/abshwabu/fikir/backend/internal/http/middleware"
	"github.com/abshwabu/fikir/backend/internal/http/response"
	apperrors "github.com/abshwabu/fikir/backend/internal/platform/errors"
	"github.com/abshwabu/fikir/backend/internal/service"
)

type AuthHandler struct {
	authService service.AuthService
}

func NewAuthHandler(authService service.AuthService) *AuthHandler {
	return &AuthHandler{
		authService: authService,
	}
}

type RequestOTPPayload struct {
	Phone string `json:"phone"`
}

type RefreshTokenPayload struct {
	RefreshToken string `json:"refresh_token"`
}

type LogoutPayload struct {
	RefreshToken string `json:"refresh_token,omitempty"`
}

// RequestOTP handles POST /v1/auth/otp/request
func (h *AuthHandler) RequestOTP(w http.ResponseWriter, r *http.Request) {
	var body RequestOTPPayload
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		response.Error(w, apperrors.BadRequest("Invalid JSON request body"))
		return
	}

	if strings.TrimSpace(body.Phone) == "" {
		response.Error(w, apperrors.BadRequest("Phone number is required"))
		return
	}

	clientIP := getClientIP(r)
	userAgent := r.UserAgent()
	fingerprint := r.Header.Get("X-Device-Fingerprint")

	cooldown, err := h.authService.RequestOTP(r.Context(), body.Phone, clientIP, userAgent, fingerprint)
	if err != nil {
		response.Error(w, err)
		return
	}

	response.JSON(w, http.StatusOK, map[string]interface{}{
		"status":           "ok",
		"message":          "Verification code sent",
		"cooldown_seconds": int(cooldown.Seconds()),
	})
}

// VerifyOTP handles POST /v1/auth/otp/verify
func (h *AuthHandler) VerifyOTP(w http.ResponseWriter, r *http.Request) {
	var body service.VerifyOTPRequest
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		response.Error(w, apperrors.BadRequest("Invalid JSON request body"))
		return
	}

	if strings.TrimSpace(body.Phone) == "" || strings.TrimSpace(body.Code) == "" {
		response.Error(w, apperrors.BadRequest("Phone number and verification code are required"))
		return
	}

	clientIP := getClientIP(r)
	userAgent := r.UserAgent()
	fingerprint := r.Header.Get("X-Device-Fingerprint")

	res, err := h.authService.VerifyOTP(r.Context(), body, clientIP, userAgent, fingerprint)
	if err != nil {
		response.Error(w, err)
		return
	}

	response.JSON(w, http.StatusOK, res)
}

// Refresh handles POST /v1/auth/refresh
func (h *AuthHandler) Refresh(w http.ResponseWriter, r *http.Request) {
	var body RefreshTokenPayload
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		response.Error(w, apperrors.BadRequest("Invalid JSON request body"))
		return
	}

	if strings.TrimSpace(body.RefreshToken) == "" {
		response.Error(w, apperrors.BadRequest("Refresh token is required"))
		return
	}

	clientIP := getClientIP(r)
	userAgent := r.UserAgent()
	fingerprint := r.Header.Get("X-Device-Fingerprint")

	tokens, err := h.authService.RefreshToken(r.Context(), body.RefreshToken, clientIP, userAgent, fingerprint)
	if err != nil {
		response.Error(w, err)
		return
	}

	response.JSON(w, http.StatusOK, tokens)
}

// Logout handles POST /v1/auth/logout
func (h *AuthHandler) Logout(w http.ResponseWriter, r *http.Request) {
	var body LogoutPayload
	_ = json.NewDecoder(r.Body).Decode(&body)

	var userID *uuid.UUID
	if uid, ok := middleware.GetUserID(r.Context()); ok {
		userID = &uid
	}

	clientIP := getClientIP(r)
	userAgent := r.UserAgent()
	fingerprint := r.Header.Get("X-Device-Fingerprint")

	if err := h.authService.Logout(r.Context(), body.RefreshToken, userID, clientIP, userAgent, fingerprint); err != nil {
		response.Error(w, err)
		return
	}

	response.JSON(w, http.StatusOK, map[string]string{
		"status":  "ok",
		"message": "Successfully logged out",
	})
}

// DeleteAccount handles DELETE /v1/me
func (h *AuthHandler) DeleteAccount(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		response.Error(w, apperrors.Unauthorized("Authentication required"))
		return
	}

	clientIP := getClientIP(r)
	userAgent := r.UserAgent()
	fingerprint := r.Header.Get("X-Device-Fingerprint")

	if err := h.authService.DeleteAccount(r.Context(), userID, clientIP, userAgent, fingerprint); err != nil {
		response.Error(w, err)
		return
	}

	response.JSON(w, http.StatusOK, map[string]string{
		"status":  "ok",
		"message": "Account scheduled for deletion in 30 days",
	})
}

func getClientIP(r *http.Request) string {
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		parts := strings.Split(xff, ",")
		return strings.TrimSpace(parts[0])
	}
	if xrip := r.Header.Get("X-Real-IP"); xrip != "" {
		return strings.TrimSpace(xrip)
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err == nil {
		return host
	}
	return r.RemoteAddr
}
