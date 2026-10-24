#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

echo "=== A-Coder Bridge Tests ==="
echo ""

# Install deps if needed
if [ ! -d node_modules ]; then
  echo "[setup] Installing dependencies..."
  npm install --ignore-scripts
fi

# Run vitest
npx vitest run "$@"
