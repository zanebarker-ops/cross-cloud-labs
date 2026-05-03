#!/usr/bin/env bash
# Walks every lab under labs/ and runs `terraform destroy -auto-approve`.
# Safe to run nightly. Skips dirs without a terraform state.
#
# Usage:
#   ./teardown-all.sh                     destroy all labs
#   ./teardown-all.sh <lab-name>          destroy a single lab
#
# Requires: .env in repo root with cloud credentials.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABS_DIR="${REPO_ROOT}/labs"

if [[ ! -f "${REPO_ROOT}/.env" ]]; then
  echo "ERROR: ${REPO_ROOT}/.env not found. Copy .env.example to .env and fill in." >&2
  exit 1
fi

# shellcheck disable=SC1091
set -a
source "${REPO_ROOT}/.env"
set +a

destroy_lab() {
  local lab_dir="$1"
  local lab_name
  lab_name="$(basename "${lab_dir}")"

  if [[ ! -f "${lab_dir}/main.tf" ]]; then
    echo "[skip] ${lab_name} — no main.tf"
    return 0
  fi

  if ! ls "${lab_dir}"/*.tfstate >/dev/null 2>&1 && ! ls "${lab_dir}"/.terraform >/dev/null 2>&1; then
    echo "[skip] ${lab_name} — no state, nothing to destroy"
    return 0
  fi

  echo "==> destroying ${lab_name}"
  (
    cd "${lab_dir}"
    terraform init -input=false -upgrade=false >/dev/null
    terraform destroy -auto-approve
  )
  echo "[done] ${lab_name}"
}

if [[ ! -d "${LABS_DIR}" ]]; then
  echo "No labs/ directory yet — nothing to destroy."
  exit 0
fi

if [[ $# -ge 1 ]]; then
  destroy_lab "${LABS_DIR}/$1"
  exit 0
fi

shopt -s nullglob
for lab in "${LABS_DIR}"/*/; do
  destroy_lab "${lab%/}"
done
shopt -u nullglob

echo "==> teardown-all complete"
