package handler

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/abshwabu/fikir/backend/internal/http/response"
	apperrors "github.com/abshwabu/fikir/backend/internal/platform/errors"
	"github.com/abshwabu/fikir/backend/internal/service"
)

type AdminHandler struct {
	moderationService service.ModerationService
	paymentService    service.PaymentService
	adminUsername     string
	adminPassword     string
}

func NewAdminHandler(
	moderationService service.ModerationService,
	paymentService service.PaymentService,
	adminUsername, adminPassword string,
) *AdminHandler {
	if adminUsername == "" {
		adminUsername = "admin"
	}
	if adminPassword == "" {
		adminPassword = "admin"
	}
	return &AdminHandler{
		moderationService: moderationService,
		paymentService:    paymentService,
		adminUsername:     adminUsername,
		adminPassword:     adminPassword,
	}
}

// BasicAuthMiddleware verifies HTTP basic authentication for admin access
func (h *AdminHandler) BasicAuthMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		user, pass, ok := r.BasicAuth()
		if !ok || user != h.adminUsername || pass != h.adminPassword {
			w.Header().Set("WWW-Authenticate", `Basic realm="Fikir Admin Moderation"`)
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// ServeDashboard renders the single-page HTML/JS admin dashboard
func (h *AdminHandler) ServeDashboard(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(adminDashboardHTML))
}

// GetPendingPhotos handles GET /admin/api/photos
func (h *AdminHandler) GetPendingPhotos(w http.ResponseWriter, r *http.Request) {
	limit := getQueryInt(r, "limit", 50)
	offset := getQueryInt(r, "offset", 0)

	photos, err := h.moderationService.GetPendingPhotos(r.Context(), limit, offset)
	if err != nil {
		response.Error(w, err)
		return
	}
	response.JSON(w, http.StatusOK, map[string]any{"photos": photos})
}

// ApprovePhoto handles POST /admin/api/photos/{id}/approve
func (h *AdminHandler) ApprovePhoto(w http.ResponseWriter, r *http.Request) {
	idStr := chi.URLParam(r, "id")
	photoID, err := uuid.Parse(idStr)
	if err != nil {
		response.Error(w, apperrors.BadRequest("invalid photo id"))
		return
	}

	adminID, _, _ := r.BasicAuth()
	if err := h.moderationService.ApprovePhoto(r.Context(), photoID, adminID); err != nil {
		response.Error(w, err)
		return
	}
	response.JSON(w, http.StatusOK, map[string]string{"status": "approved"})
}

// RejectPhoto handles POST /admin/api/photos/{id}/reject
func (h *AdminHandler) RejectPhoto(w http.ResponseWriter, r *http.Request) {
	idStr := chi.URLParam(r, "id")
	photoID, err := uuid.Parse(idStr)
	if err != nil {
		response.Error(w, apperrors.BadRequest("invalid photo id"))
		return
	}

	var req struct {
		Reason string `json:"reason"`
	}
	_ = json.NewDecoder(r.Body).Decode(&req)
	if req.Reason == "" {
		req.Reason = "violation_guidelines"
	}

	adminID, _, _ := r.BasicAuth()
	if err := h.moderationService.RejectPhoto(r.Context(), photoID, req.Reason, adminID); err != nil {
		response.Error(w, err)
		return
	}
	response.JSON(w, http.StatusOK, map[string]string{"status": "rejected"})
}

// GetPendingVerifications handles GET /admin/api/verifications
func (h *AdminHandler) GetPendingVerifications(w http.ResponseWriter, r *http.Request) {
	limit := getQueryInt(r, "limit", 50)
	offset := getQueryInt(r, "offset", 0)

	verifications, err := h.moderationService.GetPendingVerifications(r.Context(), limit, offset)
	if err != nil {
		response.Error(w, err)
		return
	}
	response.JSON(w, http.StatusOK, map[string]any{"verifications": verifications})
}

// ApproveVerification handles POST /admin/api/verifications/{id}/approve
func (h *AdminHandler) ApproveVerification(w http.ResponseWriter, r *http.Request) {
	idStr := chi.URLParam(r, "id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		response.Error(w, apperrors.BadRequest("invalid verification id"))
		return
	}

	adminID, _, _ := r.BasicAuth()
	if err := h.moderationService.ApproveVerification(r.Context(), id, adminID); err != nil {
		response.Error(w, err)
		return
	}
	response.JSON(w, http.StatusOK, map[string]string{"status": "approved"})
}

// RejectVerification handles POST /admin/api/verifications/{id}/reject
func (h *AdminHandler) RejectVerification(w http.ResponseWriter, r *http.Request) {
	idStr := chi.URLParam(r, "id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		response.Error(w, apperrors.BadRequest("invalid verification id"))
		return
	}

	var req struct {
		Reason string `json:"reason"`
	}
	_ = json.NewDecoder(r.Body).Decode(&req)

	adminID, _, _ := r.BasicAuth()
	if err := h.moderationService.RejectVerification(r.Context(), id, req.Reason, adminID); err != nil {
		response.Error(w, err)
		return
	}
	response.JSON(w, http.StatusOK, map[string]string{"status": "rejected"})
}

// GetPendingReports handles GET /admin/api/reports
func (h *AdminHandler) GetPendingReports(w http.ResponseWriter, r *http.Request) {
	limit := getQueryInt(r, "limit", 50)
	offset := getQueryInt(r, "offset", 0)

	reports, err := h.moderationService.GetPendingReports(r.Context(), limit, offset)
	if err != nil {
		response.Error(w, err)
		return
	}
	response.JSON(w, http.StatusOK, map[string]any{"reports": reports})
}

// ResolveReport handles POST /admin/api/reports/{id}/resolve
func (h *AdminHandler) ResolveReport(w http.ResponseWriter, r *http.Request) {
	idStr := chi.URLParam(r, "id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		response.Error(w, apperrors.BadRequest("invalid report id"))
		return
	}

	var req struct {
		Action string `json:"action"` // "resolved", "dismissed"
	}
	_ = json.NewDecoder(r.Body).Decode(&req)
	if req.Action == "" {
		req.Action = "resolved"
	}

	adminID, _, _ := r.BasicAuth()
	if err := h.moderationService.ResolveReport(r.Context(), id, req.Action, adminID); err != nil {
		response.Error(w, err)
		return
	}
	response.JSON(w, http.StatusOK, map[string]string{"status": req.Action})
}

// WarnUser handles POST /admin/api/users/{id}/warn
func (h *AdminHandler) WarnUser(w http.ResponseWriter, r *http.Request) {
	idStr := chi.URLParam(r, "id")
	userID, err := uuid.Parse(idStr)
	if err != nil {
		response.Error(w, apperrors.BadRequest("invalid user id"))
		return
	}

	var req struct {
		Reason string `json:"reason"`
	}
	_ = json.NewDecoder(r.Body).Decode(&req)

	adminID, _, _ := r.BasicAuth()
	if err := h.moderationService.WarnUser(r.Context(), userID, req.Reason, adminID); err != nil {
		response.Error(w, err)
		return
	}
	response.JSON(w, http.StatusOK, map[string]string{"status": "warned"})
}

// BanUser handles POST /admin/api/users/{id}/ban
func (h *AdminHandler) BanUser(w http.ResponseWriter, r *http.Request) {
	idStr := chi.URLParam(r, "id")
	userID, err := uuid.Parse(idStr)
	if err != nil {
		response.Error(w, apperrors.BadRequest("invalid user id"))
		return
	}

	var req struct {
		Reason string `json:"reason"`
	}
	_ = json.NewDecoder(r.Body).Decode(&req)
	if req.Reason == "" {
		req.Reason = "terms_violation"
	}

	adminID, _, _ := r.BasicAuth()
	if err := h.moderationService.BanUser(r.Context(), userID, req.Reason, adminID); err != nil {
		response.Error(w, err)
		return
	}
	response.JSON(w, http.StatusOK, map[string]string{"status": "banned"})
}

// ShadowBanUser handles POST /admin/api/users/{id}/shadow-ban
func (h *AdminHandler) ShadowBanUser(w http.ResponseWriter, r *http.Request) {
	idStr := chi.URLParam(r, "id")
	userID, err := uuid.Parse(idStr)
	if err != nil {
		response.Error(w, apperrors.BadRequest("invalid user id"))
		return
	}

	var req struct {
		ShadowBanned bool `json:"shadow_banned"`
	}
	_ = json.NewDecoder(r.Body).Decode(&req)

	adminID, _, _ := r.BasicAuth()
	if err := h.moderationService.ShadowBanUser(r.Context(), userID, req.ShadowBanned, adminID); err != nil {
		response.Error(w, err)
		return
	}
	response.JSON(w, http.StatusOK, map[string]any{"status": "updated", "shadow_banned": req.ShadowBanned})
}

// GetAuditLogs handles GET /admin/api/audit-logs
func (h *AdminHandler) GetAuditLogs(w http.ResponseWriter, r *http.Request) {
	limit := getQueryInt(r, "limit", 50)
	offset := getQueryInt(r, "offset", 0)

	logs, err := h.moderationService.GetAuditLogs(r.Context(), limit, offset)
	if err != nil {
		response.Error(w, err)
		return
	}
	response.JSON(w, http.StatusOK, map[string]any{"audit_logs": logs})
}

// GetPaymentsLedger handles GET /admin/api/payments
func (h *AdminHandler) GetPaymentsLedger(w http.ResponseWriter, r *http.Request) {
	limit := getQueryInt(r, "limit", 50)
	offset := getQueryInt(r, "offset", 0)

	ledger, total, err := h.paymentService.GetPaymentsLedger(r.Context(), limit, offset)
	if err != nil {
		response.Error(w, err)
		return
	}
	response.JSON(w, http.StatusOK, map[string]any{
		"payments": ledger,
		"total":    total,
		"limit":    limit,
		"offset":   offset,
	})
}

func getQueryInt(r *http.Request, key string, fallback int) int {
	valStr := r.URL.Query().Get(key)
	if valStr == "" {
		return fallback
	}
	val, err := strconv.Atoi(valStr)
	if err != nil {
		return fallback
	}
	return val
}

const adminDashboardHTML = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Fikir - Trust & Safety Admin</title>
    <style>
        :root {
            --primary: #FF4458;
            --secondary: #FF6036;
            --bg: #0F172A;
            --card-bg: #1E293B;
            --text: #F8FAFC;
            --text-muted: #94A3B8;
            --border: #334155;
            --success: #10B981;
            --danger: #EF4444;
            --warning: #F59E0B;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
        body { background: var(--bg); color: var(--text); padding: 24px; }
        header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px; border-bottom: 1px solid var(--border); padding-bottom: 16px; }
        .logo { font-size: 24px; font-weight: bold; background: linear-gradient(45deg, var(--primary), var(--secondary)); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
        .nav-tabs { display: flex; gap: 12px; margin-bottom: 24px; }
        .tab-btn { background: var(--card-bg); color: var(--text-muted); border: 1px solid var(--border); padding: 10px 20px; border-radius: 8px; cursor: pointer; font-weight: 600; }
        .tab-btn.active { background: var(--primary); color: white; border-color: var(--primary); }
        .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 20px; }
        .card { background: var(--card-bg); border: 1px solid var(--border); border-radius: 12px; overflow: hidden; padding: 16px; display: flex; flex-direction: column; gap: 12px; }
        .card img { width: 100%; height: 260px; object-fit: cover; border-radius: 8px; background: #000; }
        .badge { padding: 4px 8px; border-radius: 4px; font-size: 12px; font-weight: 600; width: fit-content; }
        .badge-warning { background: #78350F; color: #FDE68A; }
        .badge-danger { background: #7F1D1D; color: #FECACA; }
        .btn-row { display: flex; gap: 8px; margin-top: auto; }
        button { flex: 1; padding: 8px; border: none; border-radius: 6px; font-weight: 600; cursor: pointer; transition: opacity 0.2s; }
        button:hover { opacity: 0.85; }
        .btn-approve { background: var(--success); color: white; }
        .btn-reject { background: var(--danger); color: white; }
        .btn-action { background: #3B82F6; color: white; }
        table { width: 100%; border-collapse: collapse; margin-top: 12px; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid var(--border); }
        th { color: var(--text-muted); font-size: 14px; text-transform: uppercase; }
    </style>
</head>
<body>
    <header>
        <div class="logo">❤️ Fikir Moderation & Trust Desk</div>
        <div style="color: var(--text-muted);">Ethiopia Rail & Identity Guard</div>
    </header>

    <div class="nav-tabs">
        <button class="tab-btn active" onclick="showTab('photos')">Pending Photos (<span id="photo-count">0</span>)</button>
        <button class="tab-btn" onclick="showTab('verifications')">Selfie Verifications (<span id="verif-count">0</span>)</button>
        <button class="tab-btn" onclick="showTab('reports')">User Reports (<span id="report-count">0</span>)</button>
        <button class="tab-btn" onclick="showTab('payments')">Payments Ledger</button>
        <button class="tab-btn" onclick="showTab('audit')">Audit Logs</button>
    </div>

    <div id="content-area"></div>

    <script>
        let currentTab = 'photos';

        async function showTab(tab) {
            currentTab = tab;
            document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
            event.target.classList.add('active');
            const area = document.getElementById('content-area');
            area.innerHTML = '<p>Loading...</p>';

            if (tab === 'photos') loadPhotos();
            else if (tab === 'verifications') loadVerifications();
            else if (tab === 'reports') loadReports();
            else if (tab === 'payments') loadPayments();
            else if (tab === 'audit') loadAuditLogs();
        }

        async function loadPhotos() {
            const res = await fetch('/admin/api/photos');
            const data = await res.json();
            const list = data.photos || [];
            document.getElementById('photo-count').innerText = list.length;
            const area = document.getElementById('content-area');
            if (list.length === 0) {
                area.innerHTML = '<p style="color: var(--text-muted)">No pending photos in queue 🎉</p>';
                return;
            }
            var cards = '';
            for (var i = 0; i < list.length; i++) {
                var p = list[i];
                var dupBadge = p.is_duplicate ? '<span class="badge badge-warning">Potential Duplicate (pHash Match)</span>' : '';
                cards += '<div class="card">' +
                    '<img src="' + p.photo_url + '" onerror="this.src=\'https://placehold.co/400x400?text=No+Preview\'"/>' +
                    '<div><strong>' + p.user_name + '</strong>' +
                    '<div style="font-size:12px;color:var(--text-muted);">' + p.photo_id + '</div></div>' +
                    dupBadge +
                    '<div class="btn-row">' +
                    '<button class="btn-approve" onclick="approvePhoto(\'' + p.photo_id + '\')">Approve</button>' +
                    '<button class="btn-reject" onclick="rejectPhoto(\'' + p.photo_id + '\')">Reject</button>' +
                    '</div></div>';
            }
            area.innerHTML = '<div class="grid">' + cards + '</div>';
        }

        async function approvePhoto(id) {
            await fetch('/admin/api/photos/' + id + '/approve', { method: 'POST' });
            loadPhotos();
        }

        async function rejectPhoto(id) {
            var reason = prompt("Rejection reason (e.g., inappropriate, fake, poor_quality):", "inappropriate");
            if (!reason) return;
            await fetch('/admin/api/photos/' + id + '/reject', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ reason: reason })
            });
            loadPhotos();
        }

        async function loadVerifications() {
            const res = await fetch('/admin/api/verifications');
            const data = await res.json();
            const list = data.verifications || [];
            document.getElementById('verif-count').innerText = list.length;
            const area = document.getElementById('content-area');
            if (list.length === 0) {
                area.innerHTML = '<p style="color: var(--text-muted)">No pending verifications</p>';
                return;
            }
            var cards = '';
            for (var i = 0; i < list.length; i++) {
                var v = list[i];
                cards += '<div class="card">' +
                    '<div style="display:flex;gap:8px;">' +
                    '<img style="width:50%;height:180px;" src="' + v.selfie_url + '" title="Submitted Selfie"/>' +
                    '<img style="width:50%;height:180px;" src="' + v.profile_photo + '" title="Profile Photo"/>' +
                    '</div>' +
                    '<div><strong>' + v.user_name + '</strong> (Pose: ' + v.pose + ')' +
                    '<div style="font-size:12px;color:var(--text-muted);">' + v.user_id + '</div></div>' +
                    '<div class="btn-row">' +
                    '<button class="btn-approve" onclick="approveVerif(\'' + v.verification_id + '\')">Approve</button>' +
                    '<button class="btn-reject" onclick="rejectVerif(\'' + v.verification_id + '\')">Reject</button>' +
                    '</div></div>';
            }
            area.innerHTML = '<div class="grid">' + cards + '</div>';
        }

        async function approveVerif(id) {
            await fetch('/admin/api/verifications/' + id + '/approve', { method: 'POST' });
            loadVerifications();
        }

        async function rejectVerif(id) {
            var reason = prompt("Rejection reason:", "Face mismatch");
            if (!reason) return;
            await fetch('/admin/api/verifications/' + id + '/reject', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ reason: reason })
            });
            loadVerifications();
        }

        async function loadReports() {
            const res = await fetch('/admin/api/reports');
            const data = await res.json();
            const list = data.reports || [];
            document.getElementById('report-count').innerText = list.length;
            const area = document.getElementById('content-area');
            if (list.length === 0) {
                area.innerHTML = '<p style="color: var(--text-muted)">No pending reports</p>';
                return;
            }
            var rows = '';
            for (var i = 0; i < list.length; i++) {
                var r = list[i];
                var badgeClass = r.report_count >= 3 ? 'badge-danger' : 'badge-warning';
                rows += '<tr>' +
                    '<td><strong>' + r.reported_name + '</strong><br><small>' + (r.reported_phone || r.reported_id) + '</small></td>' +
                    '<td><span class="badge ' + badgeClass + '">' + r.report_count + ' reports</span></td>' +
                    '<td>' + r.reason + '</td>' +
                    '<td>' + (r.details || '-') + '</td>' +
                    '<td>' +
                    '<button class="btn-action" onclick="warnUser(\'' + r.reported_id + '\')">Warn</button> ' +
                    '<button class="btn-reject" onclick="banUser(\'' + r.reported_id + '\')">Ban</button> ' +
                    '<button class="btn-approve" onclick="resolveReport(\'' + r.report_id + '\', \'dismissed\')">Dismiss</button>' +
                    '</td></tr>';
            }
            area.innerHTML = '<table><thead><tr><th>Reported User</th><th>Count</th><th>Reason</th><th>Details</th><th>Actions</th></tr></thead><tbody>' + rows + '</tbody></table>';
        }

        async function banUser(id) {
            if (!confirm("Permanently ban user phone and device?")) return;
            await fetch('/admin/api/users/' + id + '/ban', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ reason: "severe_conduct_violation" })
            });
            loadReports();
        }

        async function warnUser(id) {
            var reason = prompt("Warning reason:", "Inappropriate chat behavior");
            if (!reason) return;
            await fetch('/admin/api/users/' + id + '/warn', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ reason: reason })
            });
            alert("Warning issued");
        }

        async function resolveReport(id, action) {
            await fetch('/admin/api/reports/' + id + '/resolve', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ action: action })
            });
            loadReports();
        }

        async function loadPayments() {
            const res = await fetch('/admin/api/payments');
            const data = await res.json();
            const list = data.payments || [];
            const area = document.getElementById('content-area');
            var rows = '';
            for (var i = 0; i < list.length; i++) {
                var p = list[i];
                var badge = p.status === 'success' ? 'badge-approve' : 'badge-warning';
                rows += '<tr>' +
                    '<td>' + new Date(p.created_at).toLocaleString() + '</td>' +
                    '<td><code>' + p.reference + '</code></td>' +
                    '<td>' + p.user_id + '</td>' +
                    '<td><strong>' + p.amount + ' ' + p.currency + '</strong></td>' +
                    '<td>' + (p.payment_method || p.provider) + '</td>' +
                    '<td><span class="badge ' + badge + '">' + p.status + '</span></td>' +
                    '</tr>';
            }
            area.innerHTML = '<table><thead><tr><th>Date</th><th>Ref</th><th>User</th><th>Amount</th><th>Method</th><th>Status</th></tr></thead><tbody>' + rows + '</tbody></table>';
        }

        async function loadAuditLogs() {
            const res = await fetch('/admin/api/audit-logs');
            const data = await res.json();
            const list = data.audit_logs || [];
            const area = document.getElementById('content-area');
            var rows = '';
            for (var i = 0; i < list.length; i++) {
                var l = list[i];
                rows += '<tr>' +
                    '<td>' + new Date(l.created_at).toLocaleString() + '</td>' +
                    '<td>' + l.admin_id + '</td>' +
                    '<td><strong>' + l.action + '</strong></td>' +
                    '<td>' + l.target_type + ' / ' + l.target_id + '</td>' +
                    '<td><pre style="font-size:11px;">' + JSON.stringify(l.details || {}) + '</pre></td>' +
                    '</tr>';
            }
            area.innerHTML = '<table><thead><tr><th>Time</th><th>Admin</th><th>Action</th><th>Target</th><th>Details</th></tr></thead><tbody>' + rows + '</tbody></table>';
        }

        loadPhotos();
    </script>
</body>
</html>`
