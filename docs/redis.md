# Fikir Redis Architecture, Key Conventions & TTL Audit

Fikir utilizes Redis 7 for high-performance sub-millisecond caching, candidate deck queues, rate limiting, and Asynq task scheduling.

---

## 1. Logical Database Separation & Eviction Policies

To prevent volatile caching spikes from evicting mission-critical background jobs or rate-limiting states, Redis uses logical DB separation with dedicated eviction rules:

| Database ID | Function | Eviction Policy | Rationale |
| :--- | :--- | :--- | :--- |
| **DB 0** | **Profile Card & Metadata Cache** | `allkeys-lru` | Cards can be lazily recomputed from PostgreSQL if evicted under memory pressure. |
| **DB 1** | **Candidate Discovery Decks** | `allkeys-lru` | Pre-computed deck candidate lists are refilled on-demand. |
| **DB 2** | **Asynq Task Queue & Delayed Jobs** | `noeviction` | Background tasks (image resizing, push notifications, payment checks) must never be dropped. |
| **DB 3** | **Sliding Window Rate Limiter** | `volatile-ttl` | Rate limit counters expire naturally within their respective 1-minute window. |

---

## 2. Key Naming Conventions & TTL Audit Table

All keys adhere to a strict hierarchical format: `<subsystem>:<entity_type>:<identifier>[:<attribute>]`

| Key Pattern | Redis Type | TTL | Purpose & Eviction Rationale |
| :--- | :--- | :--- | :--- |
| `card:{user_id}` | String (JSON) | 2 hours | Serialized profile card for discovery deck hydration. |
| `deck:{user_id}` | List (UUIDs) | 15 minutes | Ranked queue of candidate IDs waiting to be served to the swipe UI. |
| `swipes:daily:{user_id}:{YYYYMMDD}` | Integer | 24 hours (end of day) | Free-tier daily like counter (50 likes/day limit). |
| `chat:presence:{user_id}` | String | 60 seconds | Realtime user presence and connected WebSocket node ID. |
| `ratelimit:{ip_or_user_id}` | Hash / SortedSet | 60 seconds | Sliding-window request counter. |
| `payment:lock:{reference}` | String | 10 minutes | Distributed mutex lock during webhook execution to prevent double-crediting. |
| `otp:session:{phone}` | String | 5 minutes | Hashed OTP code for SMS verification. |
| `asynq:{queue_name}:*` | Stream / ZSet | No TTL / Managed | Background queues managed by Asynq scheduler. |

---

## 3. Off-Peak Cache Warming Job

To eliminate cold-start discovery latencies for users waking up in Ethiopia's highest-density regions, a cache-warming worker runs at 03:00 EAT (off-peak):

* **Target Regions**:
  * Addis Ababa (`9.010793, 38.761252`)
  * Hawassa (`7.06205, 38.47635`)
  * Bahir Dar (`11.59364, 37.39077`)
  * Dire Dawa (`9.60087, 41.85014`)
  * Adama (`8.54139, 39.26889`)
* **Behavior**:
  Pre-fetches the top active discoverable profiles in each region's 50km radius and primes `card:{user_id}` in Redis DB 0 with 2-hour TTLs.
* **Command**: Triggered via `backend/cmd/worker` or programmatically via `DiscoveryService.WarmCityCaches`.
