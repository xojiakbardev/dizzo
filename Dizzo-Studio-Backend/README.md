# Dizzo FastAPI Backend

FastAPI + SQLAlchemy async backend for Dizzo. It keeps the existing frontend
URL contract while the internals follow the `core / db / models / services /
api` architecture used by `uzliga-backend`.

## Local run

```bash
cp .env.example .env
.venv/bin/pip install -e '.[dev,bot]'
.venv/bin/alembic upgrade head          # create / migrate the schema
.venv/bin/python -m app.scripts.seed   # load the demo catalog (fresh DB only)
.venv/bin/python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

## Database migrations

The schema is managed by Alembic (`migrations/`). App startup never creates
or alters tables; the Docker image runs `alembic upgrade head` before
starting the server.

After changing a model:

```bash
.venv/bin/alembic revision --autogenerate -m "short description"
# review the generated file in migrations/versions/, then:
.venv/bin/alembic upgrade head
```

`alembic check` fails if the models and the migrations have drifted apart.

For PostgreSQL, Redis and the Telegram bot:

```bash
docker compose --env-file .env up -d --build
```

API: `http://localhost:8000`, docs: `http://localhost:8000/api/docs`.

## Production deployment

The backend is ready to run in Docker on a VPS or any server that can expose
port `8000` behind HTTPS.

1. Copy `.env.example` to `.env` and set production values:
   - `DATABASE_URL` to your production PostgreSQL instance
   - `FRONTEND_URL` to your Cloudflare frontend domain, for example
     `https://shop.example.com`
   - `CORS_ALLOWED_ORIGINS` to the same frontend origin
   - `COOKIE_SECURE=True`
   - `COOKIE_DOMAIN` if you want cookies shared across subdomains
2. Build and run the stack:

```bash
docker compose --env-file .env up -d --build
```

   On a fresh database, load the demo catalog once:

```bash
docker compose exec backend python -m app.scripts.seed
```

3. Verify the backend is healthy:

```bash
curl https://api.example.com/api/health/
```

4. Point the frontend at the public backend URL:
   - `BACKEND_URL=https://api.example.com`
   - `NUXT_PUBLIC_MEDIA_URL=https://api.example.com/media`
   - `NUXT_PUBLIC_STATIC_URL=https://api.example.com/static`

If you prefer Cloudflare Tunnel instead of opening the port directly, point the
tunnel to the local backend service on `http://localhost:8000`.

## Storage retention

Uploads that nothing uses cost money and are the easy half of an abuse
attempt, so they don't live forever. One script deletes them from R2 and
from the database, in three passes:

| pass | what it takes | window |
| --- | --- | --- |
| `pending` | an upload URL was issued and the upload never finished | `PENDING_UPLOAD_TTL_HOURS` (24) |
| `guests` | a signed-out visitor's picture under `designs/guests/` that no sign-in claimed | `GUEST_MEDIA_TTL_DAYS` (7) |
| `orphans` | a finished upload nothing references any more | `ORPHAN_MEDIA_TTL_DAYS` (30) |

A file is deleted only when nothing in the database points at it — that
includes the media ids and storage keys inside the JSON of designs, cart
items and order lines, so anything an order froze is kept for good
(`app/services/media_cleanup.py`).

```bash
docker compose exec backend python -m app.scripts.cleanup_media --dry-run  # report only
docker compose exec backend python -m app.scripts.cleanup_media            # do it
```

Schedule it daily, off peak, from the host's crontab — the API process
stays a web server and runs no jobs of its own:

```cron
17 4 * * * cd /srv/dizzo && docker compose exec -T backend \
    python -m app.scripts.cleanup_media >> /var/log/dizzo-cleanup.log 2>&1
```

Run it with `--dry-run` first after any change to the models: it prints
what each pass would take, and deleting from R2 cannot be undone.

Three quotas bound what can pile up in between: `GUEST_UPLOADS_PER_HOUR`
(30, per IP) and `UPLOADS_PER_HOUR` (120, per account).

## OAuth setup

Set `GOOGLE_CLIENT_ID` to the OAuth Web client ID used by Google Identity
Services. The backend verifies the ID token server-side. Set
`TELEGRAM_BOT_TOKEN` and `TELEGRAM_BOT_USERNAME` for the Telegram Login Widget
and Mini App `initData` validation. The bot calls
`POST /api/auth/telegram/bot` using `X-Bot-Token`.

### Mobile app (Flutter)

- `GOOGLE_MOBILE_CLIENT_IDS` — the app's Android and iOS OAuth client ids,
  comma separated (e.g. `123-abc.apps.googleusercontent.com,123-def.apps.googleusercontent.com`).
  `POST /api/auth/oauth/google/` accepts id_tokens issued for any of these or
  for `GOOGLE_CLIENT_ID`.
- The app can't use cookies: login/register/OAuth responses carry
  `access_token` and `refresh_token` in the body, and
  `POST /api/auth/token/refresh/` and `POST /api/auth/logout/` take
  `{"refresh_token": "..."}`.
- Telegram sign-in goes through the bot (needs `TELEGRAM_BOT_USERNAME`):
  `POST /api/auth/telegram/app-login/` returns a 5-minute code and a
  `t.me/<bot>?start=login_<token>` link. The bot shows a warning with
  "Tasdiqlash" / "Bekor qilish" buttons and only then calls
  `POST /api/auth/telegram/app-login/confirm/` or `.../cancel/`
  (`X-Bot-Token`). The app polls `GET /api/auth/telegram/app-login/<token>/`
  until it gets the tokens (once) or `410`.
