#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${1:-${BACKEND_DIR}/.env}"

"${SCRIPT_DIR}/live-readiness.sh" "${ENV_FILE}"

export MEDICARE_ENV_FILE="${ENV_FILE}"

cd "${BACKEND_DIR}"
if [[ -f ".venv/bin/activate" ]]; then
  source ".venv/bin/activate"
fi

api_host="$(awk -F= '$1=="API_HOST"{print $2}' "${ENV_FILE}" | tail -n1)"
api_port="$(awk -F= '$1=="API_PORT"{print $2}' "${ENV_FILE}" | tail -n1)"
api_host="${api_host:-127.0.0.1}"
api_port="${api_port:-8000}"

echo "Starting backend in live mode on ${api_host}:${api_port} ..."
exec uvicorn src.main:app --host "${api_host}" --port "${api_port}"
