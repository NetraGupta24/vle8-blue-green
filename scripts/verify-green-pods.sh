#!/usr/bin/env bash
# Confirm every live Green pod serves the app-green/index.html from this checkout.
# Run from the repository root (the Jenkins workspace).
set -euo pipefail

expected=$(sha256sum app-green/index.html | cut -d' ' -f1)
replicas=$(kubectl get deployment green-deployment -o jsonpath='{.spec.replicas}')
checked=0

# Skip pods that are still terminating from the previous rollout (they have a deletionTimestamp).
pods=$(kubectl get pods -l app=myapp,color=green \
  -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.metadata.deletionTimestamp}{"\n"}{end}' |
  awk 'NF == 1 {print $1}')

for pod in $pods; do
  actual=$(kubectl exec "$pod" -- sha256sum /usr/share/nginx/html/index.html | cut -d' ' -f1)
  image=$(kubectl get pod "$pod" -o jsonpath='{.status.containerStatuses[0].imageID}')
  echo "$pod  $image  index.html=$actual"
  if [ "$actual" != "$expected" ]; then
    echo "ERROR: $pod is not serving this build (expected index.html=$expected)" >&2
    exit 1
  fi
  checked=$((checked + 1))
done

if [ "$checked" -ne "$replicas" ]; then
  echo "ERROR: verified $checked Green pods, expected $replicas" >&2
  exit 1
fi
echo "All $checked Green pods serve this build."
