#!/usr/bin/env bash
# Destroys the AWS side of the vpn-site-to-site lab.
# Idempotent: safe to re-run after a partial destroy.
#
# Requires: ../../../.env with AWS credentials sourced into the shell.

set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${LAB_DIR}/../../.." && pwd)"

if [[ ! -f "${REPO_ROOT}/.env" ]]; then
  echo "ERROR: ${REPO_ROOT}/.env not found. Copy .env.example to .env and fill in." >&2
  exit 1
fi

# shellcheck disable=SC1091
set -a
source "${REPO_ROOT}/.env"
set +a

cd "${LAB_DIR}"

if [[ ! -d .terraform ]]; then
  echo "[init] terraform init"
  terraform init -input=false >/dev/null
fi

# terraform.tfvars is gitignored; on a clean teardown box it may not exist.
# `azure_gw_public_ip` is required, but for `destroy` the value is irrelevant
# — pass a placeholder so we never block on an interactive prompt.
DESTROY_VARS=(-auto-approve -input=false)
if [[ ! -f terraform.tfvars ]]; then
  echo "[warn] no terraform.tfvars — passing placeholder var for destroy"
  DESTROY_VARS+=(-var "azure_gw_public_ip=0.0.0.0")
fi

echo "[destroy] aws/labs/vpn-site-to-site"
terraform destroy "${DESTROY_VARS[@]}"

echo "[done] aws/labs/vpn-site-to-site"
