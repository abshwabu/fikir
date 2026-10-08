# Fikir Security Architecture, Threat Model & Hardening Guide

This document describes the security posture, threat model (STRIDE), secrets management, key rotation procedures, and defensive mechanisms implemented across the Fikir dating platform.

---

## 1. STRIDE Threat Model

| Threat Category | Target Asset / Workflow | Risk Description | Implemented Mitigation |
| :--- | :--- | :--- | :--- |
| **Spoofing** | Phone OTP Authentication | An attacker attempts to guess 6-digit OTP codes or impersonate Ethiopian phone numbers (`+2519...`, `+2517...`). | • Strict rate limiting: 3 requests/10 min per phone number.<br>• Max 5 invalid verification attempts before invalidating the session.<br>• 60s cooldown timer between SMS resends.<br>• Telebirr / Ethio Telecom SMS gateway HMAC authentication. |
| **Tampering** | Payments & Subscriptions | Replaying or modifying payment webhooks to falsely activate Fikir Plus or Fikir Gold. | • Webhook HMAC-SHA256 signature verification (`x-chapa-signature`).<br>• Distributed lock and idempotency on `tx_ref`. Replayed webhooks are acknowledged but never double-extend entitlements.<br>• SQL parameterized queries only (zero dynamic string concatenation). |
| **Repudiation** | Moderation & Admin Actions | Bad actors disputing bans or admin moderation abuse. | • Immutable `admin_audit_logs` table tracking admin user, target entity, action, reason, and IP.<br>• Permanent ban registry hashing device fingerprints and phone numbers (`banned_identifiers`). |
| **Information Disclosure** | Location Triangulation & User Data | Attackers querying user locations to calculate exact coordinates via trilateration. | • Precise GPS coordinates (lat/lng) are **never** exposed in discovery payloads.<br>• Distance is rounded to integer km server-side.<br>• Randomized jitter (200m–800m) is injected to destroy trilateration math.<br>• Strict adherence to Ethiopia Personal Data Protection Proclamation No. 1321/2024. |
| **Denial of Service** | Swiping & Media Upload APIs | Flooding the API to exhaust PostgreSQL connection pools or disk storage. | • Redis sliding-window rate limiters per IP (100 req/min) and authenticated user (300 req/min).<br>• PgBouncer transaction pooling absorbing burst traffic.<br>• Nginx `client_max_body_size 25M;` preventing memory exhaustion.<br>• Singleflight deduplication on profile card hydration. |
| **Elevation of Privilege** | Admin Dashboard (`/admin`) | Unauthorized users attempting to access photo queues or user dossiers. | • HTTP Basic Auth with strong passwords and separate administrative credential isolation.<br>• Role-checked claims on all internal routes. |

---

## 2. JWT Key Rotation Procedure

Fikir utilizes asymmetric Ed25519 (or HMAC-SHA256 fallback) JWT tokens with short-lived access tokens (15 minutes) and rotating refresh tokens (30 days with single-use family revocation).

### Key Rotation Steps (Zero Downtime)
1. **Generate New Keypair**:
   ```bash
   openssl genpkey -algorithm ed25519 -outform PEM -out jwt_ed25519_new.pem
   ```
2. **Deploy Phase 1 (Accept Both Keys)**:
   Set `JWT_SECRET_PREVIOUS` to the old key and `JWT_SECRET` to the new key in `.env` / Docker secrets.
   * New tokens are signed exclusively with the **new** key.
   * Incoming verification accepts either the new key or the previous key.
3. **Grace Period (15 Minutes)**:
   Wait 15 minutes until all existing 15-minute access tokens signed by the old key have naturally expired.
4. **Deploy Phase 2 (Decommission Old Key)**:
   Remove `JWT_SECRET_PREVIOUS`. All subsequent requests authenticate with the new key. Refresh tokens will silently rotate into new access tokens.

---

## 3. Secrets Management & Environment Isolation

* **Rule**: Zero secrets are committed to Git. All configuration is parsed via [`backend/internal/config/config.go`](file:///home/abshewabu/Documents/projects/go/fikir/backend/internal/config/config.go) using environment variables.
* **Production Deployment**: Production secrets (`DB_PASSWORD`, `JWT_SECRET`, `CHAPA_SECRET_KEY`, `MINIO_ROOT_PASSWORD`) are mounted via Docker Secrets or an encrypted `.env.prod` file with `chmod 600`.

---

## 4. SSRF & Content-Type Sniffing Protection

* **SSRF Prevention**:
  All outbound HTTP requests (e.g., payment verification webhooks, SMS gateways) utilize the custom [`safety.NewSSRFSafeClient`](file:///home/abshewabu/Documents/projects/go/fikir/backend/internal/platform/safety/ssrf.go#L44), which inspects DNS resolution at dial-time and rejects private IPv4/IPv6 CIDRs (`127.0.0.0/8`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `169.254.169.254` cloud metadata, and IPv6 unique locals).
* **MIME Magic Byte Sniffing**:
  Before processing, images are checked via [`safety.SniffImageType`](file:///home/abshewabu/Documents/projects/go/fikir/backend/internal/platform/safety/ssrf.go#L81) to verify real file signatures (`FF D8 FF` for JPEG, `89 50 4E 47` for PNG, `RIFF...WEBP` for WebP), preventing polyglot executable uploads.

---

## 5. Automated Vulnerability Scanning

* **Go Vulnerability Scanner**:
  ```bash
  govulncheck ./...
  ```
  Integrated in CI to detect vulnerabilities in Go dependencies.
* **Container Image Scanning (Trivy)**:
  ```bash
  trivy image --severity HIGH,CRITICAL fikir-api:latest
  ```
  Automated in GitHub Actions to detect OS package vulnerabilities in alpine/debian base images.
