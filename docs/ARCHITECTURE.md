# Fikir System Architecture & Infrastructure

This document describes the end-to-end technical architecture of **Fikir**, an Ethiopian dating platform engineered for high performance, low-bandwidth resilience, and rock-solid trust & safety.

---

## 1. High-Level System Architecture

```mermaid
flowchart TD
    subgraph Client["Mobile Layer (Flutter)"]
        FlutterApp["Flutter Mobile Client<br/>(Android / iOS)"]
        DriftDB[("Local Drift SQLite<br/>Offline Cache")]
        FlutterApp <--> DriftDB
    end

    subgraph Edge["Edge & Ingress (Nginx)"]
        Nginx["Nginx Reverse Proxy & HTTP/2<br/>(Gzip, Security Headers, SSL)"]
        NginxCache[("Nginx 10GB<br/>Media Cache")]
        Nginx <--> NginxCache
    end

    subgraph CoreBackend["Application Layer (Go)"]
        GoAPI["Fikir REST & WS API<br/>(Chi, OTel, Prometheus)"]
        WSHub["WebSocket Hub<br/>(Presence & Messaging)"]
        GoAPI --- WSHub
    end

    subgraph Workers["Asynchronous Worker (Asynq)"]
        GoWorker["Background Worker<br/>(Govips, Push, Payment Sync)"]
    end

    subgraph Pooling["Database Pooling"]
        PgBouncer["PgBouncer<br/>(Transaction Mode :6432)"]
    end

    subgraph Storage["Data & Storage Tier"]
        Postgres[("PostgreSQL 16 + PostGIS<br/>(Spatial, B-Tree, pg_stat)")]
        Redis[("Redis 7 (Multi-DB)<br/>DB 0: Cards | DB 1: Decks<br/>DB 2: Queue | DB 3: Limits")]
        MinIO[("MinIO Object Storage<br/>Public WebP / Original Raw")]
    end

    subgraph Observability["Observability Tier"]
        Prometheus["Prometheus :9090"]
        Grafana["Grafana :3000"]
        Loki["Loki :3100"]
    end

    subgraph External["External Rails"]
        Chapa["Chapa / Telebirr / CBE"]
        FCM["Firebase Cloud Messaging"]
        SMS["Ethio Telecom / Safaricom SMS"]
    end

    %% Client traffic
    FlutterApp -->|"HTTPS / REST"| Nginx
    FlutterApp -->|"WSS / Realtime"| Nginx
    FlutterApp -->|"GET /media/*"| Nginx

    %% Edge routing
    Nginx -->|"Proxy :8080"| GoAPI
    Nginx -->|"Proxy :9000 (Media)"| MinIO

    %% API Data Flow
    GoAPI -->|"Transactions"| PgBouncer
    PgBouncer --> Postgres
    GoAPI --> Redis
    GoAPI --> MinIO
    GoAPI -.->|"Enqueue Tasks"| Redis

    %% Worker Data Flow
    GoWorker --> Redis
    GoWorker --> Postgres
    GoWorker --> MinIO
    GoWorker --> FCM
    GoWorker --> SMS

    %% Observability
    GoAPI -->|"Scrape /metrics"| Prometheus
    Prometheus --> Grafana
    Loki --> Grafana

    %% External
    Chapa -->|"Webhooks"| Nginx
```

---

## 2. Core Workflows

### A. Swiping & Instant Mutual Match Sequence
```mermaid
sequenceDiagram
    autonumber
    actor UserA as Swiper (User A)
    participant API as Go API (:8080)
    participant Redis as Redis (DB 0 & DB 1)
    participant Postgres as PostgreSQL 16
    participant Hub as WS Hub
    actor UserB as Target (User B)

    UserA->>API: POST /v1/swipes (target_id, direction: 'like')
    API->>Redis: SADD swipes:swiped:UserA (target_id)
    API->>Redis: SISMEMBER swipes:likes_received:UserA (target_id)
    alt Reciprocal Like Detected (Match!)
        API->>Postgres: INSERT INTO matches (user_a, user_b) ON CONFLICT DO NOTHING
        API->>Redis: SREM swipes:likes_received:UserA (target_id)
        API->>Hub: Broadcast 'match.new' frame
        Hub-->>UserA: HTTP 200 {matched: true, match: {...}}
        Hub-->>UserB: WebSocket Frame {type: 'match.new', partner: UserA}
    else Standard Like
        API->>Redis: SADD swipes:likes_received:target_id (UserA)
        API-->>UserA: HTTP 200 {matched: false}
    end
    API-)Redis: Enqueue 'swipe:persist' to Asynq (Async batch insert)
```

### B. Ethiopian Payment & Subscription Activation Flow
```mermaid
sequenceDiagram
    autonumber
    actor User as Mobile App
    participant API as Go API
    participant Chapa as Chapa / Telebirr Gateways
    participant Worker as Asynq Worker
    participant DB as PostgreSQL

    User->>API: POST /v1/payments/checkout (plan: 'gold_monthly', method: 'telebirr')
    API->>DB: INSERT INTO payments (status: 'pending', reference: 'tx_xyz')
    API->>Chapa: Initiate Hosted Checkout
    Chapa-->>API: {checkout_url: 'https://checkout.chapa.co/...'}
    API-->>User: Return checkout URL
    User->>Chapa: Complete Telebirr PIN / OTP authorization
    Chapa->>API: POST /v1/webhooks/chapa (HMAC Signature Header)
    API->>API: Verify HMAC-SHA256 signature
    API->>DB: UPDATE payments SET status = 'success' WHERE tx_ref = 'tx_xyz'
    API->>DB: UPSERT subscriptions (tier: 'gold', expires_at = now() + 30d)
    API-)Worker: Enqueue Push Notification ('Fikir Gold Activated!')
    API-->>Chapa: 200 OK (Idempotent acknowledge)
    User->>API: GET /v1/me/subscription
    API-->>User: {active: true, tier: 'gold', expires_at: '...'}
```

---

## 3. Ethiopian Infrastructure & Mobile Constraints Optimization

1. **Not-Modified Caching & ETags**:
   `GET /v1/me/profile` and candidate discovery decks support HTTP `ETag` and `If-None-Match`, returning lightweight `304 Not Modified` to conserve expensive 3G mobile data.
2. **Anti-Triangulation Guarantees**:
   Raw GPS coordinates are never sent to clients. Distances are computed via PostGIS `ST_Distance` on geography points, rounded to integer kilometers, and obscured with 200m–800m randomized jitter.
3. **Low-End Android Optimization**:
   * Pre-fetches only 10–15 cards into memory.
   * Compresses images on-device before uploading (`flutter_image_compress`).
   * Renders with hardware acceleration using BlurHash placeholders.
4. **Resilient Offline Architecture**:
   Drift SQLite stores matches and unread conversations locally. App cold starts instantaneously in offline mode and reconciles automatically upon reconnecting.

---

## 4. Multi-Node Scale-Out Roadmap

When scaling beyond a single VPS (e.g. > 250,000 DAU):
* **Database**: Migrate from containerized Postgres to AWS RDS for PostgreSQL with Read Replicas and automated PITR (Point-in-Time Recovery).
* **Media Storage & CDN**: Switch MinIO to Amazon S3 (or Cloudflare R2) fronted by Cloudflare CDN for edge caching in East Africa (Nairobi PoP).
* **API Scaling**: Run multiple stateless Go API replicas behind an AWS Application Load Balancer (ALB) or Hetzner Load Balancer.
