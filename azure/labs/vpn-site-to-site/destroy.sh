#!/usr/bin/env bash
# Destroys the Azure side of the site-to-site VPN lab.
# Source the repo-root .env first so credentials are loaded.
#
# NOTE: Azure VPN Gateway delete takes 10–20 minutes. Be patient.

set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${LAB_DIR}/../../.." && pwd)"

if [[ ! -f "${REPO_ROOT}/.env" ]]; then
  echo "ERROR: ${REPO_ROOT}/.env not found." >&2
  exit 1
fi

# shellcheck disable=SC1091
set -a
source "${REPO_ROOT}/.env"
set +a

cd "${LAB_DIR}"
terraform init -input=false -upgrade=false >/dev/null
terraform destroy -auto-approve
