# Autonomous Coding Agents - Infrastructure

**Complete containerized infrastructure for running AI-powered autonomous coding agents.**

This repository contains the Docker Compose setup, n8n workflows, and OpenHands configuration needed to support AI-driven development. The actual agent orchestration and feature development logic is in separate application repositories (e.g., auto-mortgage-uw).

---

## 🏗️ Infrastructure Components

### OpenHands (Port 3000)
**AI Agent Runtime & Sandbox**
- Web UI: http://localhost:3000
- Safe containerized execution environment for AI agents
- Mounts project workspace via `${PROJECT_PATH}` environment variable
- Access to Docker socket for spawning isolated test containers
- LLM:
  - Local: qwen2.5-coder:7b (via Ollama at localhost:11434)
  - Cloud: qwen3-coder:480b-cloud (via Ollama cloud API with OLLAMA_API_KEY)

### n8n (Port 5678)
**Workflow Automation & Orchestration**
- Web UI: http://localhost:5678
- Visual workflow builder for triggering agents
- Event triggers: GitHub webhooks, schedules, manual
- Credential management
- Execution history and monitoring
- Example workflows in `n8n/demo-data/workflows/`

### PostgreSQL (Port 5432)
**n8n Persistence**
- Stores all n8n data:
  - Workflow definitions
  - Credentials and secrets
  - Execution history
  - User data
- Separate from application databases
- Data persisted to `postgres_storage/` volume

### Qdrant (Port 6333)
**Vector Database & Agent Memory**
- REST API: http://localhost:6333
- Stores embeddings for long-term agent context
- n8n can embed and retrieve documents
- Enables agents to learn from past workflows
- Data persisted to `qdrant_storage/` volume

### Ollama (Port 11434)
**Local LLM Runtime (Your Machine)**
- Runs locally on your machine (NOT in Docker)
- Models hosted: qwen2.5-coder:7b (default)
- OpenHands connects via `host.docker.internal:11434`
- Configure via `LLM_BASE_URL` in `.env`

---

## 🚀 Getting Started

### Prerequisites

- Docker & Docker Compose installed
- Ollama running locally (https://ollama.ai)
- 8GB+ RAM available
- Git for version control

### 1. Clone Repository

```bash
git clone https://github.com/schmouli/autonomous-coding-agents.git
cd autonomous-coding-agents
```

### 2. Download LLM Model

```bash
# On your local machine (NOT Docker)
ollama pull qwen2.5-coder:7b
ollama serve
```

Keep this running in the background.

### 3. Configure Environment

```bash
# Copy template
cp .env.example .env

# Edit with your settings
nano .env
```

See [Environment Configuration](#-environment-configuration) below.

### 4. Start Infrastructure

```bash
# Start all services
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f
```

Wait 1-2 minutes for all services to be healthy.

### 5. Access Services

- **OpenHands**: http://localhost:3000
- **n8n**: http://localhost:5678 (default user: admin@n8n.local / password)
- **Qdrant**: http://localhost:6333
- **PostgreSQL**: localhost:5432

---

## 🔧 Environment Configuration

### `cat .env.example`

```bash
# ── PostgreSQL Configuration ──────────────────────────────
POSTGRES_USER=root
POSTGRES_PASSWORD=password
POSTGRES_DB=n8n

# ── n8n Configuration ─────────────────────────────────────
# Generate secure values:
# openssl rand -base64 32 (for each)

N8N_ENCRYPTION_KEY=<generate-with-openssl>
N8N_USER_MANAGEMENT_JWT_SECRET=<generate-with-openssl>
N8N_DEFAULT_BINARY_DATA_MODE=filesystem

# ── OpenHands Configuration ──────────────────────────────
# Path to your application project (workspace)
PROJECT_PATH=/path/to/your/project

# For Mac/Apple Silicon users
OLLAMA_HOST=host.docker.internal:11434
DOCKER_EXTRA_HOSTS=host.docker.internal:host-gateway

# ── LLM Configuration ────────────────────────────────────
# Local mode (default - fast)
LLM_MODEL=openai/qwen2.5-coder:7b
LLM_API_KEY=ollama
LLM_BASE_URL=http://host.docker.internal:11434/v1

# Cloud mode (advanced reasoning)
# OLLAMA_API_KEY=your-ollama-cloud-api-key
```

### Key Settings

| Variable | Value | Purpose |
|----------|-------|---------|
| `PROJECT_PATH` | `/path/to/your/app` | **REQUIRED** - Where agents write code |
| `POSTGRES_PASSWORD` | Strong password | Security - change from default |
| `N8N_ENCRYPTION_KEY` | 32-char base64 | Security - generate with openssl |
| `LLM_BASE_URL` | http://host.docker.internal:11434/v1 | Connection to local Ollama |
| `OLLAMA_API_KEY` | Your API key | Only if using cloud models |

### Generate Secure Values

```bash
# Generate encryption key
openssl rand -base64 32

# Generate JWT secret
openssl rand -base64 32
```

---

## 📂 Project Structure

```
autonomous-coding-agents/
├── docker-compose.yml          # Service orchestration
├── .env.example                # Configuration template
├── .env                        # Your configuration (git ignored)
├── .gitignore                  # Excludes secrets & volumes
│
├── n8n/
│   └── demo-data/
│       ├── credentials/        # n8n credential templates
│       └── workflows/          # Example workflows
│
├── .openhands/
│   ├── skills/                 # Agent skill definitions
│   │   ├── designer.md
│   │   ├── coder.md
│   │   ├── tester.md
│   │   ├── dba.md
│   │   ├── validator.md
│   │   ├── reviewer.md
│   │   ├── security.md
│   │   ├── documentor.md
│   │   └── ci.md
│   └── config.json            # OpenHands settings
│
├── shared/                     # Shared utilities & data
├── start.sh                    # Start infrastructure script
├── stop.sh                     # Stop infrastructure script
├── switch-model.sh             # Switch between local/cloud LLM
├── README.md                   # This file
└── LICENSE                     # MIT License
```

---

## 🎮 Managing the Infrastructure

### Start Services

```bash
docker compose up -d

# Or with script
./start.sh
```

### Stop Services

```bash
docker compose down

# Or with script
./stop.sh

# To also remove volumes (delete all data)
docker compose down -v
```

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f openhands
docker compose logs -f n8n
docker compose logs -f postgres
```

### Check Service Health

```bash
docker compose ps

# Expected output:
# postgres      running (healthy)
# n8n           running
# openhands     running
# qdrant        running
```

### Restart Service

```bash
docker compose restart openhands
docker compose restart n8n
```

### Rebuild Services (after file changes)

```bash
docker compose up -d --build
```

---

## 🔄 Component Details

### OpenHands Workspace

OpenHands mounts your project at `/workspace`:

```bash
# In .env
PROJECT_PATH=/home/mouli/projects/mortgage-uw

# Inside OpenHands container
# Files appear at: /workspace
```

When agents write code, it appears in `${PROJECT_PATH}` on your machine.

### n8n Workflows

Workflows are stored in PostgreSQL. To export:

```bash
# Manual export via UI:
# 1. Go to http://localhost:5678
# 2. Select workflow → Download
# 3. Save as JSON
```

Pre-loaded workflows from `n8n/demo-data/workflows/` automatically import on first run.

### PostgreSQL Access

Connect to database directly:

```bash
# From your machine
psql -h localhost -p 5432 -U root -d n8n

# Or use pgAdmin (optional, add to docker-compose.yml)
```

### Qdrant Vector Search

Access Qdrant API:

```bash
# Health check
curl http://localhost:6333/health

# List collections
curl http://localhost:6333/collections

# Search endpoint
curl http://localhost:6333/collections/{collection_name}/points/search
```

See [Qdrant API docs](https://qdrant.tech/documentation/concepts/api/)

---

## 🔌 LLM Configuration

### Local Model (Default)

```bash
# .env
LLM_MODEL=openai/qwen2.5-coder:7b
LLM_API_KEY=ollama
LLM_BASE_URL=http://host.docker.internal:11434/v1
```

Requires Ollama running locally:
```bash
ollama serve
```

### Cloud Model (Advanced)

```bash
# .env
LLM_MODEL=openai/qwen3-coder:480b-cloud
LLM_API_KEY=your-ollama-cloud-api-key
LLM_BASE_URL=https://ollama.com/api
```

Get API key from: https://ollama.com

### Switch Models

```bash
./switch-model.sh local    # Use local qwen2.5-7b (fast)
./switch-model.sh cloud    # Use cloud qwen3-coder:480b-cloud (advanced)
```

---

## 🛠️ Troubleshooting

### Services won't start

```bash
# Check Docker is running
docker ps

# View error logs
docker compose logs

# Clean slate
docker compose down -v
docker compose up -d
```

### OpenHands can't access Ollama

```bash
# Verify Ollama is running
ollama list

# Check connectivity from container
docker compose exec openhands curl http://host.docker.internal:11434/api/tags
```

### n8n login failed

```bash
# Default credentials
Username: admin@n8n.local
Password: (set in N8N_USER_MANAGEMENT_JWT_SECRET)

# Reset n8n
docker compose down -v
docker compose up -d
# Re-configure from UI
```

### PostgreSQL connection refused

```bash
# Check service is healthy
docker compose ps postgres

# View postgres logs
docker compose logs postgres

# Restart
docker compose restart postgres
```

### Out of disk space (volumes too large)

```bash
# View volume size
docker system df

# Clean unused volumes
docker volume prune

# Or remove specific volumes
docker volume rm autonomous-coding-agents_postgres_storage
```

### Port already in use

```bash
# Find what's using the port (e.g., 5678)
lsof -i :5678

# Kill the process or change port in docker-compose.yml
```

---

## 📖 Scripts Reference

### `start.sh`
Starts all services and displays status.
```bash
./start.sh
```

### `stop.sh`
Stops all services cleanly.
```bash
./stop.sh
```

### `switch-model.sh`
Switch between local and cloud LLM models.
```bash
./switch-model.sh local    # Fast, local execution
./switch-model.sh cloud    # Advanced reasoning
```

---

## 🔐 Security Notes

- `.env` is git-ignored (contains secrets)
- PostgreSQL password should be changed from default
- Generate N8N encryption keys with `openssl rand -base64 32`
- Don't commit credentials to git
- Use `.env.example` as template only

---

## 🙏 Credits

Built on top of [n8n Self-Hosted AI Starter Kit](https://github.com/n8n-io/self-hosted-ai-starter-kit).

Modified and extended by [@schmouli](https://github.com/schmouli) to create a specialized autonomous coding agents infrastructure.

---

1. Fork repository
2. Create feature branch
3. Make changes
4. Test locally: `docker compose up -d`
5. Submit pull request

See [CONTRIBUTING.md](CONTRIBUTING.md)

---

## 📄 License

MIT License - See [LICENSE](LICENSE)

---

## 📚 Related Documentation

- Agent implementation & coding: See your application repository (e.g., auto-mortgage-uw)
- Agent skill definitions: [.openhands/skills/](.openhands/skills/)
- n8n documentation: https://docs.n8n.io
- OpenHands documentation: https://docs.openhands.dev
- Qdrant documentation: https://qdrant.tech/documentation/

---

**Infrastructure to power AI-driven development** 🤖

