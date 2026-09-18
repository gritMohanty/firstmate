#!/usr/bin/env bash
# Transport regression only: Captain owns the live auth/catalog/quota policy.
# No model calls; the fixture module proves forwarding and fail-closed behavior.
set -u
# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
TMP_ROOT=$(fm_test_tmproot fm-subscription-check)
mkdir -p "$TMP_ROOT/primary/config" "$TMP_ROOT/secondmate/config"
export FM_HOME="$TMP_ROOT/primary"
unset GRIT_SUBSCRIPTION_POLICY_FILE
export GRIT_SUBSCRIPTION_POLICY=1
if node "$ROOT/bin/fm-subscription-check.mjs" codex model high 0 >"$TMP_ROOT/out" 2>&1; then
  fail "managed home accepted a missing policy"
fi
assert_grep 'Subscription policy is missing' "$TMP_ROOT/out"
cat >"$TMP_ROOT/policy.mjs" <<'JS'
export function checkFirstmateSubscription(registry, request) {
  if (registry.marker !== 'test' || request.harness !== 'cursor' || request.model !== 'model' || request.effort !== 'high' || request.raw) throw new Error('fixture policy rejected request');
}
export function firstmateEnvironment(env) {
  const result = { ...env }; delete result.AGENT_CLI_CREDENTIAL_STORE; return result;
}
JS
printf '%s\n' '{"marker":"test"}' >"$TMP_ROOT/registry.json"
node -e 'const fs=require("node:fs"); const p=process.argv[1]; fs.writeFileSync(p+"/primary/config/subscription-policy.json",JSON.stringify({module:p+"/policy.mjs",registry:p+"/registry.json"}));' "$TMP_ROOT"
node "$ROOT/bin/fm-subscription-check.mjs" cursor model high 0 || fail "valid profile was not forwarded"
if node "$ROOT/bin/fm-subscription-check.mjs" cursor model high 1 >"$TMP_ROOT/out" 2>&1; then
  fail "raw-launch flag was lost"
fi
export GRIT_SUBSCRIPTION_POLICY_FILE="$FM_HOME/config/subscription-policy.json"
export FM_HOME="$TMP_ROOT/secondmate"
node "$ROOT/bin/fm-subscription-check.mjs" cursor model high 0 || fail "secondmate lost inherited policy"
AGENT_CLI_CREDENTIAL_STORE=memory node "$ROOT/bin/fm-subscription-exec.mjs" node -e 'if (process.env.AGENT_CLI_CREDENTIAL_STORE) process.exit(1)' || fail "managed executor did not apply policy"
rc=0
node "$ROOT/bin/fm-subscription-exec.mjs" node -e 'process.exit(7)' || rc=$?
assert_equals 7 "$rc" "managed executor lost child exit status"
export GRIT_SUBSCRIPTION_POLICY_FILE=relative.json
if node "$ROOT/bin/fm-subscription-check.mjs" cursor model high 0 >"$TMP_ROOT/out" 2>&1; then
  fail "relative policy path accepted"
fi
assert_grep 'must be absolute' "$TMP_ROOT/out"
if node "$ROOT/bin/fm-subscription-exec.mjs" node -e 'process.exit(0)' >"$TMP_ROOT/out" 2>&1; then
  fail "managed executor accepted a relative policy"
fi
pass "managed policy transport refuses missing/relative policies and preserves profile and inheritance"
