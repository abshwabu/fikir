# Privacy and Personal Data Protection Policy

## Compliance with Ethiopia Personal Data Protection Proclamation No. 1321/2024

"Fikir" dating platform adheres strictly to the **Federal Democratic Republic of Ethiopia Personal Data Protection Proclamation No. 1321/2024** and international privacy best practices. This document details how personal data is collected, processed, secured, retained, and deleted.

---

### 1. Data Controller and Principles of Processing
- **Data Controller**: Fikir Dating App operations and data processing entity.
- **Lawfulness & Transparency**: Data is collected exclusively upon explicit user consent (`terms_accepted_at` and `privacy_accepted_at` recorded during account registration).
- **Purpose Limitation**: Personal identification and profile details are utilized solely for matchmaking, community safety, fraud prevention, and customer support.
- **Data Minimization**: Only information essential for finding romantic partners and ensuring community safety is requested.

---

### 2. Location Privacy & Anti-Triangulation Guarantee
To protect the physical safety and privacy of users in Ethiopia:
1. **No Exact Coordinates Exposed**:
   - The backend API never serializes precise GPS coordinates (`latitude`, `longitude`) in candidate discovery, profile views, or match chats.
2. **PostGIS Distance Rounding**:
   - Physical distance between candidates is calculated server-side using PostGIS `ST_Distance(geography)` and rounded to the nearest integer kilometer (`distance_km`).
3. **Randomized Location Jitter (200m – 800m)**:
   - To defeat coordinate multilateration and triangulation attacks, user locations have an internal randomized jitter offset applied so external observers cannot reverse-engineer true physical locations.
4. **Distance Hiding**:
   - Users subscribed to Fikir Plus or Fikir Gold can elect to completely hide their distance badge.

---

### 3. Data Subject Rights (Proclamation No. 1321/2024)
Under Ethiopian law, users possess enforceable statutory rights regarding their personal data:
1. **Right to Access & Data Portability**:
   - Users can download their complete personal data dossier at any time via `GET /v1/me/export`.
   - The export bundle contains account credentials, profile attributes, photo records, payment receipts, active subscription status, and consent timestamps in open JSON format.
2. **Right to Erasure (Right to Be Forgotten)**:
   - Users can delete their account via `DELETE /v1/me`.
   - Immediate soft deletion marks the account as `deleted` and invalidates all session tokens, removes profile cards from discovery, and terminates discovery visibility immediately.
3. **Right to Rectification**:
   - Users can modify photos, bio, interests, religious beliefs, and relationship goals via `PATCH /v1/me/profile`.

---

### 4. Data Retention and Automated Purge Schedule
- **Active Accounts**: Profile data and chat messages are maintained during active account tenure.
- **Soft-Deleted Accounts**: Retained in quarantine for **30 days** to allow account recovery and fraud investigations, after which an automated queue worker (`TypeAccountPurge`) executes hard cascading deletion from Postgres and MinIO object storage.
- **Banned Identifiers**: To protect community safety and prevent recidivism by scammers, phone numbers and device fingerprints of permanently banned users are retained in `banned_identifiers` with encrypted audit logs (`admin_audit_logs`).
- **Payment Transaction Records**: Transaction ledger records are preserved for **7 years** to satisfy Ethiopian tax and regulatory accounting requirements.

---

### 5. Photo Moderation & Perceptual Hashing (dHash)
- **Photo Integrity**: Photos submitted by users are processed through a 64-bit perceptual difference hash (`dHash`).
- **Duplicate & Scammer Detection**: Near-duplicate images with a Hamming distance $\le 5$ are flagged for human admin review.
- **Moderation Actions**: Photos flagged by the automated safety filter or reported by users enter the admin queue. Once rejected, photos are removed from discovery within 60 seconds and MinIO cache entries are purged.
