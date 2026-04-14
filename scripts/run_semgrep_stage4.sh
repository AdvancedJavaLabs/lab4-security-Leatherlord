#!/usr/bin/env bash

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SEM="${ROOT}/.venv/bin/semgrep"
if [[ ! -x "$SEM" ]]; then
  python3 -m venv .venv
  .venv/bin/pip install -q semgrep
fi

if [[ ! -d /tmp/semgrep-rules/java ]]; then
  rm -rf /tmp/semgrep-rules
  git clone --depth 1 https://github.com/semgrep/semgrep-rules.git /tmp/semgrep-rules
fi
OWASP_YAML="${ROOT}/.semgrep-cache/p-owasp-top-ten.yaml"
mkdir -p "${ROOT}/.semgrep-cache"
if [[ ! -s "$OWASP_YAML" ]]; then
  curl -sS -L --max-time 180 "https://semgrep.dev/c/p/owasp-top-ten" -o "$OWASP_YAML"
fi

run_local() {
  "$SEM" --metrics off --disable-version-check \
    --config /tmp/semgrep-rules/java \
    --config "$OWASP_YAML" \
    "$@"
}

echo "=== Текстовый отчёт (stdout + semgrep-output.txt) ==="
run_local src/ 2>&1 | tee semgrep-output.txt

echo ""
echo "=== SARIF → semgrep-report.sarif ==="
run_local --sarif -o semgrep-report.sarif src/
echo "Готово."
