#!/usr/bin/env bash
# Safe rollback (VLE-8 Step 9): send myapp-service traffic back to Blue, then verify it.
# Usage: bash scripts/rollback-to-blue.sh
set -euo pipefail

# Refuse to switch unless Blue is fully available.
kubectl rollout status deployment/blue-deployment --timeout=60s

kubectl patch service myapp-service \
-p '{"spec":{"selector":{"app":"myapp","color":"blue"}}}'

bash "$(dirname "$0")/verify-service.sh" blue
