#!/bin/bash
cd "$(dirname "$0")"
echo "→ Stopping all Docker services..."
docker compose down
echo "✅ Docker services stopped."
echo "→ Ollama (systemd) left running — stop manually with: sudo systemctl stop ollama"
