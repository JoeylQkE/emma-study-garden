#!/usr/bin/env bash
set -euo pipefail
emma_repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$emma_repo_dir"
if [[ -n "${SUPABASE_URL:-}" || -n "${SUPABASE_PUBLISHABLE_KEY:-}" ]]; then
  python3 tools/configure-cloud.py
fi
python3 tools/build-public.py
python3 tools/build-test.py
node --test tests/core.test.cjs
