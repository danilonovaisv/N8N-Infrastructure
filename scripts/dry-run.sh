#!/usr/bin/env bash
set -euo pipefail

# Dry-run infra tests without Docker or integration steps
SKIP_DOCKER=1 SKIP_INTEGRATION=1 bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test-infrastructure.sh"

