#!/bin/bash
set -e
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

# Load .env to get OLLAMA_API_KEY and PROJECT_PATH
set -a; source .env; set +a

MODE=${1:-local}

if [ "$MODE" = "cloud" ]; then
  echo "→ Switching to Ollama cloud (qwen3-coder-next)..."
  docker compose stop openhands
  LLM_MODEL=openai/qwen3-coder-next \
  LLM_API_KEY="$OLLAMA_API_KEY" \
  LLM_BASE_URL=https://ollama.com/api \
  docker compose up -d openhands
  echo "✅ OpenHands → qwen3-coder-next (Ollama cloud)"
elif [ "$MODE" = "local" ]; then
  echo "→ Switching to local (qwen2.5-coder:7b)..."
  docker compose stop openhands
  LLM_MODEL=openai/qwen2.5-coder:7b \
  LLM_API_KEY=ollama \
  LLM_BASE_URL=http://host.docker.internal:11434/v1 \
  docker compose up -d openhands
  echo "✅ OpenHands → qwen2.5-coder:7b (local Ollama)"
else
  echo "Usage: ./switch-model.sh local|cloud"
  exit 1
fi
