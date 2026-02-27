#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

ENV_FILE="${1:-${BACKEND_DIR}/.env}"
if [[ ! -f "${ENV_FILE}" ]]; then
  echo "ERROR: env file not found: ${ENV_FILE}"
  exit 1
fi

set -a
source "${ENV_FILE}"
set +a

required=(
  AUTH_MODE
  MOCK_AI
  FIREBASE_PROJECT_ID
  FIREBASE_CLIENT_EMAIL
  FIREBASE_PRIVATE_KEY
  AI_PROVIDER
  OPENROUTER_API_KEY
  TAVILY_API_KEY
  MONGODB_URI
  MONGODB_DATABASE
)

is_placeholder() {
  local value="$1"
  [[ "${value}" == *"..."* ]] && return 0
  [[ "${value}" == *"your-"* ]] && return 0
  [[ "${value}" == *"xxxxx"* ]] && return 0
  [[ "${value}" == *"example"* ]] && return 0
  return 1
}

echo "Checking live readiness using: ${ENV_FILE}"
echo

missing=0
for key in "${required[@]}"; do
  value="${!key-}"
  if [[ -z "${value}" ]] || is_placeholder "${value}"; then
    printf "MISSING  %s\n" "${key}"
    missing=1
  else
    printf "OK       %s\n" "${key}"
  fi
done

echo
if [[ "${AUTH_MODE-}" != "firebase" ]]; then
  echo "WARN: AUTH_MODE should be 'firebase' for live mode."
fi

if [[ "${MOCK_AI-}" != "false" ]]; then
  echo "WARN: MOCK_AI should be 'false' for live mode."
fi

if [[ "${AI_PROVIDER-}" != "openrouter" && "${AI_PROVIDER-}" != "anthropic" ]]; then
  echo "WARN: AI_PROVIDER should be 'openrouter' or 'anthropic'."
fi

if [[ "${missing}" -eq 1 ]]; then
  echo
  echo "Live readiness: NOT READY"
  exit 2
fi

echo
echo "Live readiness: READY"
