import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// Custom Metrics
const errorRate = new Rate('error_rate');
const discoveryDuration = new Trend('discovery_duration');
const swipeDuration = new Trend('swipe_duration');
const uploadUrlDuration = new Trend('upload_url_duration');
const totalMatches = new Counter('total_matches');

export const options = {
  stages: [
    { duration: '30s', target: 50 },  // Ramp-up to 50 VUs
    { duration: '1m', target: 200 },  // Scale to 200 VUs
    { duration: '30s', target: 500 },  // Peak traffic burst
    { duration: '30s', target: 0 },    // Ramp-down
  ],
  thresholds: {
    'http_req_duration': ['p(95)<150'],       // 95% of requests must complete below 150ms
    'discovery_duration': ['p(95)<100'],      // Discovery p95 < 100ms
    'swipe_duration': ['p(95)<30'],           // Swipe p95 < 30ms
    'upload_url_duration': ['p(95)<50'],      // Upload URL p95 < 50ms
    'error_rate': ['rate<0.01'],              // Under 1% error rate
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

export default function () {
  const userId = `00000000-0000-0000-0000-${String(__VU).padStart(12, '0')}`;
  const targetId = `00000000-0000-0000-0001-${String((__VU + __ITER) % 500 + 1).padStart(12, '0')}`;

  const headers = {
    'Content-Type': 'application/json',
    'X-User-ID': userId,
    'Accept': 'application/json',
  };

  // 1. Discovery Deck Fetch
  const discRes = http.get(`${BASE_URL}/v1/discovery?limit=15`, { headers });
  const discOk = check(discRes, {
    'discovery status 200': (r) => r.status === 200,
  });
  errorRate.add(!discOk);
  discoveryDuration.add(discRes.timings.duration);

  sleep(0.5);

  // 2. Swiping Action (Like or Pass)
  const direction = __ITER % 3 === 0 ? 'super' : (__ITER % 2 === 0 ? 'like' : 'nope');
  const swipePayload = JSON.stringify({
    target_id: targetId,
    direction: direction,
  });

  const swipeRes = http.post(`${BASE_URL}/v1/swipes`, swipePayload, { headers });
  const swipeOk = check(swipeRes, {
    'swipe status 200 or 429': (r) => r.status === 200 || r.status === 429,
  });
  errorRate.add(!swipeOk);
  swipeDuration.add(swipeRes.timings.duration);

  if (swipeRes.status === 200) {
    try {
      const body = JSON.parse(swipeRes.body);
      if (body.matched) {
        totalMatches.add(1);
      }
    } catch (_) {}
  }

  sleep(0.5);

  // 3. Media Upload URL Generation
  if (__ITER % 5 === 0) {
    const uploadPayload = JSON.stringify({
      content_type: 'image/jpeg',
      file_size_bytes: 1048576,
    });
    const uploadRes = http.post(`${BASE_URL}/v1/me/photos/upload-url`, uploadPayload, { headers });
    const uploadOk = check(uploadRes, {
      'upload url status 200': (r) => r.status === 200,
    });
    errorRate.add(!uploadOk);
    uploadUrlDuration.add(uploadRes.timings.duration);
  }

  sleep(1);
}
