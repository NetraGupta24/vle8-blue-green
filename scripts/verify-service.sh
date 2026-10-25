#!/usr/bin/env bash
# Verify myapp-service routes only to the given color and the app answers with that color's page.
# Usage: bash scripts/verify-service.sh blue|green
set -euo pipefail

color=${1:-}
case "$color" in
  blue)  marker='VLE-8 Blue Environment' ;;
  green) marker='VLE-8 Green Environment' ;;
  *) echo "usage: $0 blue|green" >&2; exit 2 ;;
esac

selector=$(kubectl get service myapp-service -o jsonpath='{.spec.selector.color}')
echo "myapp-service selector color: $selector"
if [ "$selector" != "$color" ]; then
  echo "ERROR: selector is '$selector', expected '$color'" >&2
  exit 1
fi

# 1. Endpoints: every ready endpoint must be a pod of $color, one per ready replica.
expected_pods=$(kubectl get pods -l "app=myapp,color=$color" -o name | sed 's|^pod/||')
ready=$(kubectl get deployment "$color-deployment" -o jsonpath='{.status.readyReplicas}')
endpoints_ok=false
for _ in $(seq 1 30); do
  endpoints=$(kubectl get endpointslices -l kubernetes.io/service-name=myapp-service \
    -o jsonpath='{range .items[*].endpoints[?(@.conditions.ready==true)]}{.targetRef.name}{"\n"}{end}')
  count=$(grep -c . <<<"$endpoints" || true)
  stray=$(grep -vxF -e "$expected_pods" <<<"$endpoints" || true)
  if [ "$count" -gt 0 ] && [ "$count" -eq "${ready:-0}" ] && [ -z "$stray" ]; then
    endpoints_ok=true
    break
  fi
  sleep 2
done
echo "Ready endpoints:"
echo "$endpoints"
if [ "$endpoints_ok" != true ]; then
  echo "ERROR: endpoints do not match the $ready ready $color pods" >&2
  exit 1
fi

# 2. Application response through the NodePort: 10 requests in a row must all return the $color page.
node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
node_port=$(kubectl get service myapp-service -o jsonpath='{.spec.ports[0].nodePort}')
url="http://$node_ip:$node_port/"
for _ in $(seq 1 30); do
  hits=0
  for _ in $(seq 1 10); do
    body=$(curl -fsS --max-time 5 "$url" || true)
    if [[ $body == *"$marker"* ]]; then
      hits=$((hits + 1))
    fi
  done
  if [ "$hits" -eq 10 ]; then
    echo "$url returned '$marker' on 10/10 requests."
    exit 0
  fi
  echo "$url: $hits/10 requests returned '$marker', retrying..."
  sleep 2
done
echo "ERROR: $url did not consistently return the $color page" >&2
exit 1
