#!/usr/bin/env bash
# Render checks for the agent chart (QA-059). Run: bash tests/render_test.sh
set -euo pipefail
cd "$(dirname "$0")/.."
TOKEN="tok-render-test-123"
out=$(helm template t charts/optryn-agent --set clusterId=c1 --set agentToken="$TOKEN")
dep=$(printf '%s\n' "$out" | awk '/^kind: Deployment/,/^---/' )
fail=0
check() { if ! eval "$2"; then echo "FAIL: $1"; fail=1; else echo "ok: $1"; fi; }
check "token not in Deployment"          '! grep -q "$TOKEN" <<<"$dep"'
check "token read from a Secret"         'grep -q "secretKeyRef" <<<"$dep"'
check "Secret carries the token"         'printf "%s\n" "$out" | awk "/^kind: Secret/,/^---/" | grep -q "$TOKEN"'
check "runs as non-root"                 'grep -q "runAsNonRoot: true" <<<"$dep"'
check "no privilege escalation"          'grep -q "allowPrivilegeEscalation: false" <<<"$dep"'
check "read-only root filesystem"        'grep -q "readOnlyRootFilesystem: true" <<<"$dep"'
check "drops all capabilities"           'grep -q "ALL" <<<"$dep"'
ext=$(helm template t charts/optryn-agent --set clusterId=c1 --set existingSecret=mine)
check "existingSecret: no chart Secret"  '! grep -q "^kind: Secret" <<<"$(printf "%s\n" "$ext" | grep -v prometheus)" || ! printf "%s\n" "$ext" | grep -q "t-token\|optryn-agent-token"'
check "existingSecret is referenced"     'grep -q "name: mine" <<<"$ext"'
exit $fail
