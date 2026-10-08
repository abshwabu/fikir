package handler

import (
	"encoding/json"
	"io"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/abshwabu/fikir/backend/internal/domain"
	"github.com/abshwabu/fikir/backend/internal/http/middleware"
	"github.com/abshwabu/fikir/backend/internal/http/response"
	apperrors "github.com/abshwabu/fikir/backend/internal/platform/errors"
	"github.com/abshwabu/fikir/backend/internal/service"
)

type PaymentHandler struct {
	paymentService    service.PaymentService
	moderationService service.ModerationService
}

func NewPaymentHandler(paymentService service.PaymentService, moderationService service.ModerationService) *PaymentHandler {
	return &PaymentHandler{
		paymentService:    paymentService,
		moderationService: moderationService,
	}
}

type CheckoutRequestBody struct {
	PlanID        string `json:"plan_id"`
	Provider      string `json:"provider,omitempty"`       // "chapa", "telebirr"
	PaymentMethod string `json:"payment_method,omitempty"` // "telebirr", "cbe_birr", "card"
	ReturnURL     string `json:"return_url,omitempty"`
	CallbackURL   string `json:"callback_url,omitempty"`
}

type CheckoutResponseBody struct {
	PaymentID   uuid.UUID `json:"payment_id"`
	Reference   string    `json:"reference"`
	CheckoutURL string    `json:"checkout_url"`
	Amount      float64   `json:"amount"`
	Currency    string    `json:"currency"`
	Status      string    `json:"status"`
}

type SubscriptionResponse struct {
	Active    bool                     `json:"active"`
	Tier      domain.SubscriptionTier  `json:"tier,omitempty"`
	PlanID    *string                  `json:"plan_id,omitempty"`
	StartsAt  *string                  `json:"starts_at,omitempty"`
	ExpiresAt *string                  `json:"expires_at,omitempty"`
	AutoRenew bool                     `json:"auto_renew"`
}

// GetPlans handles GET /v1/plans
func (h *PaymentHandler) GetPlans(w http.ResponseWriter, r *http.Request) {
	plans, err := h.paymentService.GetPlans(r.Context())
	if err != nil {
		response.Error(w, err)
		return
	}
	response.JSON(w, http.StatusOK, map[string]any{"plans": plans})
}

// InitiateCheckout handles POST /v1/payments/checkout
func (h *PaymentHandler) InitiateCheckout(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		response.Error(w, apperrors.Unauthorized("Authentication required"))
		return
	}

	var req CheckoutRequestBody
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, apperrors.BadRequest("Invalid request body"))
		return
	}

	if req.PlanID == "" {
		response.Error(w, apperrors.BadRequest("plan_id is required"))
		return
	}

	pay, err := h.paymentService.InitiateCheckout(
		r.Context(),
		userID,
		req.PlanID,
		req.Provider,
		req.PaymentMethod,
		req.ReturnURL,
		req.CallbackURL,
	)
	if err != nil {
		response.Error(w, err)
		return
	}

	response.JSON(w, http.StatusOK, CheckoutResponseBody{
		PaymentID:   pay.ID,
		Reference:   pay.Reference,
		CheckoutURL: pay.CheckoutURL,
		Amount:      pay.Amount,
		Currency:    pay.Currency,
		Status:      string(pay.Status),
	})
}

// HandleWebhook handles POST /v1/webhooks/{provider}
func (h *PaymentHandler) HandleWebhook(w http.ResponseWriter, r *http.Request) {
	provider := chi.URLParam(r, "provider")
	if provider == "" {
		provider = "chapa"
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		response.Error(w, apperrors.BadRequest("Failed to read body"))
		return
	}

	sig := r.Header.Get("x-chapa-signature")
	if sig == "" {
		sig = r.Header.Get("X-Chapa-Signature")
	}
	if sig == "" {
		sig = r.Header.Get("X-Signature")
	}

	if err := h.paymentService.HandleWebhook(r.Context(), provider, body, sig); err != nil {
		response.Error(w, err)
		return
	}

	response.JSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// GetPaymentStatus handles GET /v1/payments/{reference}
func (h *PaymentHandler) GetPaymentStatus(w http.ResponseWriter, r *http.Request) {
	ref := chi.URLParam(r, "reference")
	if ref == "" {
		response.Error(w, apperrors.BadRequest("reference is required"))
		return
	}

	pay, err := h.paymentService.GetPaymentStatus(r.Context(), ref)
	if err != nil {
		response.Error(w, err)
		return
	}
	if pay == nil {
		response.Error(w, apperrors.NotFound("Payment not found"))
		return
	}

	response.JSON(w, http.StatusOK, pay)
}

// GetUserSubscription handles GET /v1/me/subscription
func (h *PaymentHandler) GetUserSubscription(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		response.Error(w, apperrors.Unauthorized("Authentication required"))
		return
	}

	sub, err := h.paymentService.GetUserSubscription(r.Context(), userID)
	if err != nil {
		response.Error(w, err)
		return
	}

	if sub == nil || !sub.IsActive() {
		response.JSON(w, http.StatusOK, SubscriptionResponse{
			Active: false,
		})
		return
	}

	startsAt := sub.StartsAt.Format("2006-01-02T15:04:05Z07:00")
	expiresAt := sub.ExpiresAt.Format("2006-01-02T15:04:05Z07:00")

	response.JSON(w, http.StatusOK, SubscriptionResponse{
		Active:    true,
		Tier:      sub.Tier,
		PlanID:    sub.PlanID,
		StartsAt:  &startsAt,
		ExpiresAt: &expiresAt,
		AutoRenew: sub.AutoRenew,
	})
}

// ExportUserData handles GET /v1/me/export for Ethiopia Data Protection Proclamation No. 1321/2024 compliance
func (h *PaymentHandler) ExportUserData(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.GetUserID(r.Context())
	if !ok {
		response.Error(w, apperrors.Unauthorized("Authentication required"))
		return
	}

	if h.moderationService == nil {
		response.Error(w, apperrors.ServiceUnavailable("Moderation service unavailable"))
		return
	}

	export, err := h.moderationService.ExportUserData(r.Context(), userID)
	if err != nil {
		response.Error(w, err)
		return
	}

	w.Header().Set("Content-Disposition", "attachment; filename=\"fikir_user_data_export.json\"")
	response.JSON(w, http.StatusOK, export)
}
