# MediCare AI — Production Deployment

Production runs on a single Ubuntu server. Host nginx terminates TLS; the backend and
MongoDB run in Docker, reachable only from the server itself.

---

## How production runs

```
Internet ──HTTPS──▶ host nginx (Let's Encrypt via certbot)
                     ├─ mediguide.co      → static files from /root/medicare/website
                     └─ api.mediguide.co  → /health and /api/ → 127.0.0.1:8000
                                              │
              docker compose project "medicare" (docker-compose.prod.yml)
              ├─ medicare-backend   FastAPI, port 8000 bound to 127.0.0.1
              └─ medicare-mongo     MongoDB 7, port 27017 bound to 127.0.0.1
                                    volumes medicare_mongo_data, medicare_mongo_config

Backend → OpenRouter  https://openrouter.ai/api/v1/chat/completions
          (google/gemini-4-neon, automatic fallback openai/gpt-5.4)
        → Tavily      https://api.tavily.com/search
        → Firebase Admin SDK (ID-token verification)
```

| File | Tracked | Purpose |
|------|---------|---------|
| `docker-compose.prod.yml` | yes | Production stack. Contains no secrets. |
| `.env.prod` | **no** (git-ignored) | All backend settings plus `MONGO_ROOT_USERNAME` / `MONGO_ROOT_PASSWORD`. Template: `.env.example`. `chmod 600`. |
| `deploy/nginx/*.conf` | yes | Copies of `/etc/nginx/sites-available/medicare` and `mediguide-website`. |
| `docker-compose.yml` | yes | Local development only (project `medicare-dev`). Never use it for production. |

The repository is public. Never commit `.env*` files, passwords or keys.

---

## Deploy a new version

```bash
cd /root/medicare
git pull                                   # or check out the release branch

# 1. Keep the running image so it can be restored
docker tag medicare-backend:latest medicare-backend:rollback-$(date +%F-%H%M)

# 2. Build and start (MongoDB is only recreated if its settings changed)
docker compose --env-file .env.prod -f docker-compose.prod.yml up -d --build

# 3. Verify
docker compose --env-file .env.prod -f docker-compose.prod.yml ps   # both "healthy"
curl -fsS https://api.mediguide.co/health
docker logs --since 5m medicare-backend
```

Then run an end-to-end check with a temporary account: sign up through Firebase,
call settings, profile, history and one chat question (expect at least one citation),
then delete the account with `DELETE /api/account` and the body
`{"confirmation": "DELETE"}`.

After changing `.env.prod`, recreate the backend: settings are read once at startup.

```bash
docker compose --env-file .env.prod -f docker-compose.prod.yml up -d --force-recreate backend
```

## Roll back

```bash
cd /root/medicare
docker images medicare-backend                     # find the rollback tag
docker tag medicare-backend:rollback-<stamp> medicare-backend:latest
docker compose --env-file .env.prod -f docker-compose.prod.yml up -d --no-build backend
```

If the deploy also changed `.env.prod`, restore your copy of the previous file first.
Make that copy before every edit:
`cp -p .env.prod /root/env-backups/.env.prod.$(date +%F-%H%M)`.

---

## First-time setup on a new server

1. Install Docker (with the compose plugin), nginx and certbot. Open only SSH, HTTP and
   HTTPS: `ufw allow OpenSSH && ufw allow 80/tcp && ufw allow 443/tcp && ufw enable`.
2. Point the DNS A records for `mediguide.co` and `api.mediguide.co` at the server.
3. Clone the repository to `/root/medicare` (the website config serves files from there).
4. Create the settings file and fill in real values:
   ```bash
   cp .env.example .env.prod && chmod 600 .env.prod
   ```
   `MONGODB_URI` must use the host name `mongo` and the same user and password as
   `MONGO_ROOT_USERNAME` / `MONGO_ROOT_PASSWORD`. MongoDB creates that user only when
   its data volume is first initialised; changing the variables later changes nothing.
5. Install the nginx sites, then add certificates:
   ```bash
   cp deploy/nginx/api.mediguide.co.conf /etc/nginx/sites-available/medicare
   cp deploy/nginx/mediguide.co.conf /etc/nginx/sites-available/mediguide-website
   ln -s /etc/nginx/sites-available/medicare /etc/nginx/sites-enabled/
   ln -s /etc/nginx/sites-available/mediguide-website /etc/nginx/sites-enabled/
   nginx -t && systemctl reload nginx
   certbot --nginx -d api.mediguide.co -d mediguide.co
   ```
   On a brand-new server, remove the certbot-managed `listen 443` / `ssl_*` lines from the
   copies first and let certbot add them back.
6. Start the stack and verify it as in **Deploy a new version**:
   ```bash
   docker compose --env-file .env.prod -f docker-compose.prod.yml up -d --build
   ```

The iOS app's release build talks to `https://api.mediguide.co` by default
(`ios/MediCareAI/Services/AppEnvironment.swift`); the `API_BASE_URL` scheme variable in
`ios/project.yml` overrides it for local testing.

---

## Operations

### Logs

```bash
docker logs -f medicare-backend      # JSON lines; one request_complete per API call
docker logs -f medicare-mongo
```

Logs never contain question, search query, answer or profile text. `/health` checks are
not logged. Docker rotates the files (backend 20 MB × 5, MongoDB 10 MB × 3).

### Restart

```bash
docker compose --env-file .env.prod -f docker-compose.prod.yml restart backend
```

### MongoDB backup and restore

The database user and password come from the container's own environment, so they never
appear on the host command line.

```bash
mkdir -p /root/backups
docker exec medicare-mongo sh -c 'mongodump --username "$MONGO_INITDB_ROOT_USERNAME" \
  --password "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin \
  --db medicare-ai --archive --gzip' > /root/backups/medicare-$(date +%F).archive.gz

# Restore (replaces the collections in the archive)
docker exec -i medicare-mongo sh -c 'mongorestore --username "$MONGO_INITDB_ROOT_USERNAME" \
  --password "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin \
  --archive --gzip --drop' < /root/backups/medicare-YYYY-MM-DD.archive.gz
```

Collections: `users` (includes settings), `conversations`, `messages`, `v10Memories`,
`analyticsEvents`.

### Resource usage

```bash
docker stats --no-stream medicare-backend medicare-mongo
```

---

## Environment variables reference

| Variable | Required | Example | Description |
|----------|----------|---------|-------------|
| `MONGO_ROOT_USERNAME` / `MONGO_ROOT_PASSWORD` | Yes | — | MongoDB root user, created when the volume is first initialised |
| `MONGODB_URI` | Yes | `mongodb://USER:PASS@mongo:27017/medicare-ai?authSource=admin` | Backend connection string |
| `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY` | Yes | — | Firebase service account (keep the `\n` escapes in the key) |
| `OPENROUTER_API_KEY` | Yes | `sk-or-v1-...` | OpenRouter API key |
| `OPENROUTER_BASE_URL` | No | `https://openrouter.ai/api` | The backend appends `/v1` |
| `AI_MODEL` | No | `google/gemini-4-neon` | Primary model (legacy name `ANTHROPIC_MODEL` is still read) |
| `AI_FALLBACK_MODELS` | No | `["openai/gpt-5.4"]` | Tried in order when the primary fails |
| `AI_MAX_TOKENS` | No | `8192` | Output cap per round; reasoning tokens count against it |
| `AI_REASONING_EFFORT` | No | `low` | Optional; unset uses the provider default |
| `AI_TOOL_MIN_CALLS` | No | `2` | Searches required before a health answer |
| `AI_TOOL_MAX_ROUNDS` / `AI_TOOL_MAX_CALLS` | No | `6` / `12` | Caps on tool rounds and total searches |
| `TAVILY_API_KEY` | Yes | `tvly-...` | Tavily search key |
| `TAVILY_INCLUDE_ANSWER` | No | `false` | Keep false: only numbered results may be cited |
| `ENVIRONMENT` | No | `production` | |
| `AUTH_MODE` / `MOCK_AI` | No | `firebase` / `false` | Production values |
| `ALLOWED_ORIGINS` | No | `["https://mediguide.co"]` | CORS origins |
| `CHAT_RATE_LIMIT_PER_HOUR` / `V10_RATE_LIMIT_PER_HOUR` | No | `30` / `10` | Per user |
| `ANALYTICS_ENABLED` / `ANALYTICS_STORE_DB` | No | `true` / `true` | Event logging and storage |

---

## Troubleshooting

- **Every endpoint returns 500 ("Could not complete your request" in the app):** read
  `docker logs medicare-backend`. On 2026-11-22 this was a legacy unique index on
  `users.email`; startup now removes it.
- **Backend cannot reach MongoDB:** `MONGODB_URI` must use the host `mongo` and the user
  that exists in the data volume.
- **Answers fail with `AI_ERROR`:** check `OPENROUTER_API_KEY`, and check that `AI_MODEL`
  and `AI_FALLBACK_MODELS` are valid OpenRouter ids.
- **Rate limit errors (429):** raise `CHAT_RATE_LIMIT_PER_HOUR` in `.env.prod` and
  recreate the backend.
- **iOS connection errors:** `curl https://api.mediguide.co/health`; check the
  certificate with `certbot certificates`.

---

## Security checklist

- [ ] `.env.prod` is `chmod 600` and git-ignored
- [ ] MongoDB and the backend are bound to `127.0.0.1` only
- [ ] UFW allows only SSH, HTTP and HTTPS
- [ ] `ALLOWED_ORIGINS` lists real origins only (never `*`)
- [ ] No secret in any tracked file (`git grep` before every commit; the repo is public)
- [ ] Rotate any key or password that was ever printed or committed
