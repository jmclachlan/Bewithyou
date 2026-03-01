# GameLink MVP0 (Mux + Postmark + Rails)

Private single-link stream watcher for one recipient.

## What this does

- `GET /g/:token` serves a private watch page (no login).
- `POST /webhooks/mux` processes Mux webhooks:
  - `video.live_stream.active` => marks stream live and sends one "Game is LIVE" email.
  - `video.live_stream.idle` => marks stream idle.
  - `video.asset.live_stream_completed` => stores VOD playback id and sends one "Replay is ready" email.
- Same watch link works for both live and replay.

## Environment variables

Set these for local/dev/prod:

```bash
APP_HOST=watch.yourdomain.com
POSTMARK_API_TOKEN=...
FROM_EMAIL=alerts@yourdomain.com
TO_EMAIL=james@example.com
WATCH_TOKEN=long_random_token
MUX_WEBHOOK_SECRET=shared_secret
```

## Local setup

```bash
bundle install
bin/rails db:create db:migrate
bin/rails server
```

Watch page:

```bash
http://localhost:3000/g/$WATCH_TOKEN
```

## Mux webhook notes

This app verifies `Mux-Signature` using:

- `t=` timestamp
- `v1=` HMAC SHA256 signature of `"{timestamp}.{raw_body}"` with `MUX_WEBHOOK_SECRET`
- 5-minute timestamp tolerance

## Email format

- Live subject: `Game is LIVE`
- Live body: `Watch now -> https://APP_HOST/g/WATCH_TOKEN`

- Replay subject: `Replay is ready`
- Replay body: `Watch replay -> https://APP_HOST/g/WATCH_TOKEN`

## Test suite

```bash
bin/rails test
```
