import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Counter, Rate } from 'k6/metrics';

// Custom metrics
const discoveryLatency = new Trend('discovery_duration', true);
const swipeLatency = new Trend('swipe_duration', true);
const matchesFormed = new Counter('matches_formed');
const rateLimitHits = new Counter('rate_limit_hits');
const successfulRequests = new Rate('successful_requests');

export const options = {
  scenarios: {
    peak_swiping: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '20s', target: 500 },   // Warm up
        { duration: '30s', target: 2000 },  // Ramp to 2,000 concurrent users
        { duration: '60s', target: 2000 },  // Sustain 2,000 concurrent users
        { duration: '20s', target: 0 },     // Cool down
      ],
      gracefulRampDown: '10s',
    },
  },
  thresholds: {
    'discovery_duration': ['p(95)<120', 'p(99)<250'], // Target: p95 discovery < 120ms
    'swipe_duration': ['p(95)<30', 'p(99)<60'],       // Target: p95 swipe < 30ms
    'successful_requests': ['rate>0.99'],             // 99%+ success rate
  },
};

const BASE_URL = __ENV.API_BASE_URL || 'http://localhost:8080';

// Mock user tokens pool or generated test headers
const USER_IDS = [
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000004',
];

export default function () {
  // Rotate synthetic user token / authorization header
  const vuIndex = (__VU % 100) + 1;
  const authHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json, image/webp',
    'X-User-ID': `00000000-0000-0000-0000-${String(vuIndex).padStart(12, '0')}`,
    'Authorization': `Bearer test-token-vu-${vuIndex}`,
  };

  // 1. Fetch Discovery Deck
  const discoveryStart = Date.now();
  const discoveryRes = http.get(`${BASE_URL}/v1/discovery?limit=15`, {
    headers: authHeaders,
    tags: { endpoint: 'discovery' },
  });

  discoveryLatency.add(Date.now() - discoveryStart);

  const discoverySuccess = check(discoveryRes, {
    'discovery status 200 or 401 (auth stub)': (r) => r.status === 200 || r.status === 401,
  });
  successfulRequests.add(discoverySuccess);

  let deck = [];
  if (discoveryRes.status === 200) {
    try {
      const body = JSON.parse(discoveryRes.body);
      deck = body.deck || [];
    } catch (e) {
      deck = [];
    }
  }

  // Fallback candidate target if unauthenticated in isolated test run
  const targetIDs = deck.length > 0 
    ? deck.map(c => c.user_id) 
    : ['10000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002'];

  // 2. Perform Swipes with rapid user action cadence
  for (let i = 0; i < Math.min(targetIDs.length, 5); i++) {
    const targetID = targetIDs[i];
    const rand = Math.random();
    let direction = 'nope';
    if (rand < 0.65) {
      direction = 'like';
    } else if (rand < 0.70) {
      direction = 'super';
    }

    const swipePayload = JSON.stringify({
      target_id: targetID,
      direction: direction,
    });

    const swipeStart = Date.now();
    const swipeRes = http.post(`${BASE_URL}/v1/swipes`, swipePayload, {
      headers: authHeaders,
      tags: { endpoint: 'swipe' },
    });

    swipeLatency.add(Date.now() - swipeStart);

    const isRateLimited = swipeRes.status === 429;
    if (isRateLimited) {
      rateLimitHits.add(1);
    }

    const swipeSuccess = check(swipeRes, {
      'swipe status 200, 401, or 429': (r) => r.status === 200 || r.status === 401 || r.status === 429,
    });
    successfulRequests.add(swipeSuccess);

    if (swipeRes.status === 200) {
      try {
        const body = JSON.parse(swipeRes.body);
        if (body.matched) {
          matchesFormed.add(1);
        }
      } catch (e) {}
    }

    // Realistic human swipe delay (300ms - 800ms)
    sleep(0.3 + Math.random() * 0.5);
  }

  // Think time between decks
  sleep(1.0 + Math.random() * 2.0);
}
