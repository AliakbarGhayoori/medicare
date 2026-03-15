# MediCare AI — Single Droplet Deployment Guide

Deploy the entire MediCare AI backend (FastAPI + MongoDB + Caddy reverse proxy) on a single VPS droplet. The iOS app connects to this server via HTTPS.

---

## Architecture on the Droplet

```
Internet (HTTPS :443)
    │
    ▼
┌─────────────────────────────────────────────┐
│  Caddy (auto-HTTPS, reverse proxy)          │
│  :80 → redirect to :443                     │
│  :443 → proxy to backend:8000               │
├─────────────────────────────────────────────┤
│  FastAPI Backend (Docker container)          │
│  :8000 (internal only, not exposed)          │
│  - Firebase Auth verification               │
│  - OpenRouter API (Gemini 3.1 Pro)           │
│  - Tavily search API                         │
│  - SSE streaming                             │
├─────────────────────────────────────────────┤
│  MongoDB 7 (Docker container)                │
│  :27017 (internal only, not exposed)         │
│  - users, conversations, messages            │
│  - v10_digests, user_settings                │
└─────────────────────────────────────────────┘
```

All three services run in Docker containers managed by `docker compose`. Caddy handles SSL certificates automatically via Let's Encrypt. MongoDB and the backend are only reachable from within the Docker network — not exposed to the internet.

---

## Prerequisites

### 1. External Services (get these first)

| Service | What you need | Where to get it |
|---------|--------------|-----------------|
| **Domain** | A domain or subdomain (e.g. `api.medicareai.app`) | Any registrar |
| **Firebase** | Project ID, client email, private key | Firebase Console → Project Settings → Service Accounts → Generate new private key |
| **OpenRouter** | API key | https://openrouter.ai/keys |
| **Tavily** | API key | https://tavily.com (sign up, get API key) |

### 2. VPS Requirements

- **OS**: Ubuntu 22.04 or 24.04
- **RAM**: 2 GB minimum (4 GB recommended)
- **Disk**: 20 GB minimum
- **Provider**: DigitalOcean, Hetzner, Vultr, Linode — any will work

---

## Step-by-Step Deployment

### Step 1: Create the Droplet

Create an Ubuntu 22.04/24.04 droplet with at least 2 GB RAM. Set up SSH key access.

```bash
# From your local machine:
ssh root@YOUR_DROPLET_IP
```

### Step 2: Install Docker

```bash
# Install Docker and Docker Compose
curl -fsSL https://get.docker.com | sh

# Verify
docker --version
docker compose version
```

### Step 3: Configure Firewall

```bash
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
```

Only SSH (22), HTTP (80), and HTTPS (443) are open. MongoDB (27017) and the backend (8000) are NOT exposed — they communicate internally via Docker networking.

### Step 4: Point DNS

Add an A record in your DNS provider:

```
Type: A
Name: api (or @ for root domain)
Value: YOUR_DROPLET_IP
TTL: 300
```

Wait for DNS propagation (usually 1-5 minutes).

### Step 5: Clone and Configure

```bash
# Clone the repo
git clone https://github.com/AliakbarGhayoori/medicare.git /opt/medicare
cd /opt/medicare

# Create production env file from template
cp .env.example .env
```

Edit `.env` with your real values:

```bash
nano .env
```

**Critical values to set:**

```bash
# Firebase — from your Firebase service account JSON
FIREBASE_PROJECT_ID=medicare-8fd9e
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@medicare-8fd9e.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"

# MongoDB — use a strong password, NOT 'localdev'
MONGODB_URI=mongodb://root:YOUR_STRONG_PASSWORD@mongo:27017/medicare-ai?authSource=admin
MONGO_ROOT_PASSWORD=YOUR_STRONG_PASSWORD

# AI — your OpenRouter API key
OPENROUTER_API_KEY=sk-or-v1-...
OPENROUTER_SITE_URL=https://api.yourdomain.com
ANTHROPIC_MODEL=google/gemini-3.1-pro-preview

# Search — your Tavily API key
TAVILY_API_KEY=tvly-...

# Production settings
ENVIRONMENT=production
ALLOWED_ORIGINS=["https://yourdomain.com"]
AUTH_MODE=firebase
MOCK_AI=false
```

**Important notes:**
- `MONGODB_URI` must use `mongo` as hostname (Docker service name), not `localhost`
- `MONGO_ROOT_PASSWORD` must match the password in `MONGODB_URI`
- `FIREBASE_PRIVATE_KEY` — paste the full key, keep the `\n` escapes

### Step 6: Deploy

```bash
cd /opt/medicare

# Set your domain for Caddy (auto-HTTPS)
export DOMAIN=api.yourdomain.com

# Build and start everything
DOMAIN=$DOMAIN docker compose up -d --build
```

This starts:
1. **MongoDB** — database, data persisted in Docker volume
2. **Backend** — FastAPI server on internal port 8000
3. **Caddy** — auto-obtains Let's Encrypt SSL cert, proxies HTTPS → backend

### Step 7: Verify

```bash
# Check all containers are running
docker compose ps

# Check backend health
curl https://api.yourdomain.com/health
# → {"status":"healthy","version":"3.0"}

# Check logs for errors
docker compose logs backend --tail 50
docker compose logs caddy --tail 20
docker compose logs mongo --tail 20
```

---

## iOS App Configuration

After the backend is live, update the iOS app to point to your production URL.

### Option A: Update project.yml (recommended)

In `ios/project.yml`, update the `MediCareAI-Live` scheme:

```yaml
# Change API_BASE_URL to your production domain
environmentVariables:
  - variable: API_BASE_URL
    value: https://api.yourdomain.com
    isEnabled: true
```

Then regenerate: `cd ios && xcodegen generate`

### Option B: Add a production scheme

Create a third Xcode scheme `MediCareAI-Prod` with:
- `AUTH_MODE=firebase`
- `API_BASE_URL=https://api.yourdomain.com`

---

## How the Pieces Connect

```
┌─────────────┐  HTTPS  ┌───────┐         ┌─────────┐
│  iOS App    │────────►│ Caddy │────────►│ FastAPI │
│  (SwiftUI)  │  :443   │       │  :8000   │ Backend │
└──────┬──────┘         └───────┘         └────┬────┘
       │                                       │
  Firebase Auth                                │
  (get ID token)                     ┌─────────┼──────────┐
       │                             │         │          │
       ▼                             ▼         ▼          ▼
┌──────────────┐              ┌──────────┐ ┌────────┐ ┌───────┐
│ Firebase     │              │ MongoDB  │ │OpenRou-│ │Tavily │
│ Auth Service │              │ :27017   │ │ter API │ │Search │
└──────────────┘              │(internal)│ │(Gemini)│ │  API  │
                              └──────────┘ └────────┘ └───────┘
```

**Request flow:**
1. User types a question in the iOS app
2. iOS gets a Firebase ID token from Firebase Auth
3. iOS sends `POST /api/chat/ask` with `Authorization: Bearer <token>` over HTTPS
4. Caddy terminates TLS, forwards to FastAPI on port 8000
5. FastAPI verifies the Firebase token with Firebase Admin SDK
6. FastAPI loads user's V10 health profile and conversation history from MongoDB
7. FastAPI calls Gemini 3.1 Pro via OpenRouter (OpenAI Chat Completions format)
8. Gemini may call `tavily_search` tool 0-12 times for medical evidence
9. FastAPI streams the response back as Server-Sent Events (SSE)
10. iOS renders markdown text with citations in real-time
11. FastAPI saves the message to MongoDB and updates V10 digest asynchronously

**External API calls (from backend):**
- `https://openrouter.ai/api/v1/chat/completions` — AI model inference
- `https://api.tavily.com/search` — web evidence retrieval
- Firebase Admin SDK — token verification (uses cached Google public keys)

---

## Operations

### View Logs

```bash
cd /opt/medicare
docker compose logs -f              # All services
docker compose logs -f backend      # Backend only
docker compose logs -f caddy        # Caddy/HTTPS only
```

### Restart

```bash
docker compose restart backend      # Restart backend only
docker compose restart              # Restart all
```

### Update to Latest Code

```bash
cd /opt/medicare
git pull origin main
DOMAIN=api.yourdomain.com docker compose up -d --build
```

Docker rebuilds only the changed layers (fast if only Python code changed).

### MongoDB Backup

```bash
# Create backup
docker compose exec mongo mongodump \
  --username root --password YOUR_STRONG_PASSWORD \
  --authenticationDatabase admin \
  --out /data/db/backup-$(date +%Y%m%d)

# Copy backup to host
docker compose cp mongo:/data/db/backup-$(date +%Y%m%d) ./backups/
```

### Check Resource Usage

```bash
docker stats --no-stream
```

Expected: ~200-400 MB total RAM for all 3 containers.

---

## Environment Variables Reference

| Variable | Required | Example | Description |
|----------|----------|---------|-------------|
| `FIREBASE_PROJECT_ID` | Yes | `medicare-8fd9e` | Firebase project ID |
| `FIREBASE_CLIENT_EMAIL` | Yes | `firebase-adminsdk-...@...iam.gserviceaccount.com` | Service account email |
| `FIREBASE_PRIVATE_KEY` | Yes | `"-----BEGIN PRIVATE KEY-----\n..."` | Service account private key |
| `MONGODB_URI` | Yes | `mongodb://root:PASS@mongo:27017/medicare-ai?authSource=admin` | MongoDB connection string |
| `MONGO_ROOT_PASSWORD` | Yes | `strong-random-password` | Must match URI password |
| `OPENROUTER_API_KEY` | Yes | `sk-or-v1-...` | OpenRouter API key |
| `ANTHROPIC_MODEL` | No | `google/gemini-3.1-pro-preview` | Model ID on OpenRouter |
| `TAVILY_API_KEY` | Yes | `tvly-...` | Tavily search API key |
| `DOMAIN` | Yes* | `api.yourdomain.com` | Passed to Caddy for SSL (* set via env, not in .env) |
| `ENVIRONMENT` | No | `production` | Affects logging verbosity |
| `AUTH_MODE` | No | `firebase` | `firebase` for production |
| `ALLOWED_ORIGINS` | No | `["https://yourdomain.com"]` | CORS allowed origins |

---

## Troubleshooting

### Caddy won't get SSL certificate
- DNS must point to the droplet IP first
- Ports 80 and 443 must be open (`ufw status`)
- Check: `docker compose logs caddy`

### Backend can't connect to MongoDB
- `MONGODB_URI` must use `mongo` as hostname (the Docker service name)
- `MONGO_ROOT_PASSWORD` must match the password in the URI
- Check: `docker compose logs backend | grep mongo`

### iOS app gets connection errors
- Verify backend is healthy: `curl https://api.yourdomain.com/health`
- Check `API_BASE_URL` in the iOS scheme matches the domain
- No trailing slash on the URL

### "AI response contained no text output"
- Check `OPENROUTER_API_KEY` is valid
- Check `ANTHROPIC_MODEL` is a valid model ID on OpenRouter
- Check: `docker compose logs backend | grep AI_ERROR`

### Rate limit errors (429)
- Default: 30 chat requests per hour per user
- Adjust `CHAT_RATE_LIMIT_PER_HOUR` in `.env`

---

## Security Checklist

- [ ] MongoDB password is strong (not `localdev`)
- [ ] `.env` file permissions: `chmod 600 .env`
- [ ] MongoDB and backend ports are NOT exposed to internet (bound to 127.0.0.1)
- [ ] Caddy auto-HTTPS is working (check `https://` works)
- [ ] `ALLOWED_ORIGINS` is set to your domain only (not `*`)
- [ ] Firebase private key is in `.env`, not committed to git
- [ ] API keys (OpenRouter, Tavily) are in `.env`, not committed to git
- [ ] UFW firewall is enabled with only 22, 80, 443 open
