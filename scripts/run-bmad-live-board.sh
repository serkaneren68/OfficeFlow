#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${1:-4173}"
HOST="${2:-127.0.0.1}"

cd "${ROOT_DIR}"
python3 scripts/bmad_live_board.py --port "${PORT}" --host "${HOST}"
