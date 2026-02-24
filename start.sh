#!/bin/bash
set -e
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

echo "──────────────────────────────────────────"
echo "  mortgage-uw Autonomous Coding Stack"
echo "──────────────────────────────────────────"

# Load .env to get PROJECT_PATH and OLLAMA_API_KEY
set -a; source .env; set +a

# ── 1. Ensure Ollama systemd service is configured and running ───────────
# Unset OLLAMA_HOST for native ollama CLI commands (it's Docker-container-specific)
unset OLLAMA_HOST

OLLAMA_OVERRIDE_DIR="/etc/systemd/system/ollama.service.d"
OLLAMA_OVERRIDE_FILE="$OLLAMA_OVERRIDE_DIR/override.conf"

# Check if the 32k context window is already configured in systemd
if [ ! -f "$OLLAMA_OVERRIDE_FILE" ] || ! grep -q "OLLAMA_CONTEXT_LENGTH=32768" "$OLLAMA_OVERRIDE_FILE"; then
  echo "→ Configuring native Ollama for 32k context window..."
  sudo mkdir -p "$OLLAMA_OVERRIDE_DIR"
  sudo bash -c "cat > $OLLAMA_OVERRIDE_FILE" << 'OVERRIDE'
[Service]
Environment="OLLAMA_CONTEXT_LENGTH=32768"
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_KEEP_ALIVE=-1"
OVERRIDE
  sudo systemctl daemon-reload
  sudo systemctl restart ollama
  echo "✅ Ollama context window set to 32768"
fi

if ! curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; then
  echo "→ Starting Ollama..."
  sudo systemctl start ollama
  echo "→ Waiting for Ollama to initialize..."
  until curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; do
    printf "."; sleep 2
  done
  echo " ready."
else
  echo "✅ Ollama is running"
fi


# ── 2. Ensure local model is pulled ──────────────────────────────────────
if ! ollama list | grep -q "qwen2.5-coder:7b"; then
  echo "→ Pulling qwen2.5-coder:7b (first run only, ~4.7GB)..."
  ollama pull qwen2.5-coder:7b
else
  echo "✅ qwen2.5-coder:7b ready"
fi

# Re-export OLLAMA_HOST for use in docker compose environment
export OLLAMA_HOST='host.docker.internal:11434'

# ── 3. Create required host directories ──────────────────────────────────
mkdir -p "$PROJECT_PATH"
mkdir -p "$PROJECT_DIR/shared"
mkdir -p "$PROJECT_DIR/n8n/demo-data"

# ── 4. Create .openhands/skills scaffold in project if not exists ─────────
if [ ! -d "$PROJECT_PATH/.openhands/skills" ]; then
  echo "→ Creating .openhands/skills scaffold in project..."
  mkdir -p "$PROJECT_PATH/.openhands/skills"
  cat > "$PROJECT_PATH/.openhands/skills/repo.md" << 'SKILL'
---
name: mortgage-uwRepo
type: repo
---
Stack: FastAPI, SQLAlchemy, Alembic, PostgreSQL, Docker
Conventions: snake_case, /api/v1 prefix, Decimal for financials, pytest for tests
Never: modify existing Alembic migrations, hardcode secrets, skip input validation
SKILL
  echo "✅ .openhands/skills created — add specialist skill files as needed"
fi

# ── 5. Install agents.py Python dependencies if requirements file exists ──
if [ -f "$PROJECT_PATH/requirements-agents.txt" ]; then
  echo "→ Installing agent dependencies..."
  pip install -q -r "$PROJECT_PATH/requirements-agents.txt" 2>/dev/null || {
    echo "⚠ Note: System Python doesn't allow direct installs (PEP 668)"
    echo "  Use a virtual environment or Docker for agent scripts"
  }
fi

# ── 6. Start Docker Compose stack ────────────────────────────────────────
echo "→ Starting Docker services..."
docker compose pull --quiet 2>/dev/null || true
docker compose up -d

# ── 7. Wait for all services to be healthy ────────────────────────────────
echo "→ Waiting for services to be healthy..."
until docker inspect postgres --format='{{.State.Health.Status}}' 2>/dev/null | grep -q "healthy"; do
  printf "."; sleep 2
done
echo " Postgres healthy."

until curl -sf http://localhost:3000 > /dev/null 2>&1; do
  printf "."; sleep 2
done
echo " OpenHands ready."

# ── 8. Show status ────────────────────────────────────────────────────────
echo ""
echo "✅ All services up:"
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo "──────────────────────────────────────────"
echo "  n8n         → http://localhost:5678"
echo "  OpenHands   → http://localhost:3000"
echo "  Ollama API  → http://localhost:11434"
echo "  Qdrant      → http://localhost:6333"
echo "──────────────────────────────────────────"
echo "  switch model: ./switch-model.sh local|cloud"
echo "  run agents:   cd $PROJECT_PATH && python agents.py"
echo "  stop all:     ./stop.sh"
echo "──────────────────────────────────────────"
