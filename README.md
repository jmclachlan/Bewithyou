# GameLink MVP0 (Mux + Postmark + Rails)

Private single-link stream watcher for one recipient.

## What this does

- `GET /g/:token` serves a private watch page (no login).
- `POST /webhooks/mux` processes Mux webhooks:
  - `video.live_stream.active` => marks stream live and sends one "Game is LIVE" email.
  - `video.live_stream.idle` => marks stream idle.
  - `video.asset.live_stream_completed` => stores VOD playback id and sends one "Replay is ready" email.
- Same watch link works for both live and replay.
- Watch page auto-updates using Rails 8 Hotwire Turbo Streams.

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

## Deploy to Heroku

This repo is now Heroku-ready:
- `Procfile` includes `release: bundle exec rails db:migrate` and web process.
- Production uses Postgres via `DATABASE_URL`.
- `app.json` declares required env vars and Postgres addon.

### Quick deploy (CLI)

```bash
# 1) Create app
heroku create your-gamelink-app

# 2) Ensure stack/buildpack
heroku buildpacks:set heroku/ruby -a your-gamelink-app

# 3) Add Postgres
heroku addons:create heroku-postgresql:mini -a your-gamelink-app

# (Optional) Add Redis if you will run multiple dynos for Turbo Streams
# heroku addons:create heroku-redis:mini -a your-gamelink-app

# 4) Set required config vars
heroku config:set \
  APP_HOST=your-gamelink-app.herokuapp.com \
  POSTMARK_API_TOKEN=... \
  FROM_EMAIL=alerts@yourdomain.com \
  TO_EMAIL=james@example.com \
  WATCH_TOKEN=long_random_token \
  MUX_WEBHOOK_SECRET=shared_secret \
  RAILS_SERVE_STATIC_FILES=enabled \
  RAILS_LOG_TO_STDOUT=enabled \
  -a your-gamelink-app

# 5) Deploy
git push heroku main
```

### After deploy

```bash
# Health check
curl https://your-gamelink-app.herokuapp.com/up

# Watch URL
echo "https://your-gamelink-app.herokuapp.com/g/<WATCH_TOKEN>"
```

## Mux webhook notes

This app verifies `Mux-Signature` using:

- `t=` timestamp
- `v1=` HMAC SHA256 signature of `"{timestamp}.{raw_body}"` with `MUX_WEBHOOK_SECRET`
- 5-minute timestamp tolerance

Webhook idempotency is enforced with a dedicated `processed_webhook_events` table
and a unique index on `(provider, external_event_id)`.

## Hotwire stack

- Importmap is configured (`config/importmap.rb`, `app/javascript/application.js`).
- Turbo + Stimulus are wired in the application layout.
- Watch clients subscribe to Turbo Streams and update live/replay state without page refresh.

## Email format

- Live subject: `Game is LIVE`
- Live body: `Watch now -> https://APP_HOST/g/WATCH_TOKEN`

- Replay subject: `Replay is ready`
- Replay body: `Watch replay -> https://APP_HOST/g/WATCH_TOKEN`

## Test suite

```bash
bin/rails test
```

## Staging environment + smoke test

A dedicated `staging` Rails environment is included (`config/environments/staging.rb` + `storage/staging.sqlite3`).

Run a quick end-to-end smoke test in staging:

```bash
APP_HOST=watch.staging.local \
POSTMARK_API_TOKEN=smoke-postmark-token \
FROM_EMAIL=alerts@example.com \
TO_EMAIL=james@example.com \
WATCH_TOKEN=smoke-watch-token \
MUX_WEBHOOK_SECRET=smoke-mux-secret \
RAILS_ENV=staging \
bin/smoke
```

This smoke run verifies:
- invalid watch token returns 404
- valid watch token renders page
- signed live webhook updates state + triggers live notification path
- signed idle webhook marks stream offline
- signed replay webhook stores VOD playback id + triggers replay notification path

## Alternative suggestion

If you want simpler ongoing ops and predictable pricing, **Render** is a good alternative for this app:
- Native Rails + Postgres flow
- Easy env var management
- Straightforward deploys from GitHub

Heroku remains the fastest path if you want to launch immediately.
