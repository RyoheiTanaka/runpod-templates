#!/usr/bin/env bash
set -euo pipefail

RUNPOD_TEMPLATES_REF="${RUNPOD_TEMPLATES_REF:-main}"

curl -fsSL "https://raw.githubusercontent.com/RyoheiTanaka/runpod-templates/${RUNPOD_TEMPLATES_REF}/templates/wan22/setup.sh" | bash
