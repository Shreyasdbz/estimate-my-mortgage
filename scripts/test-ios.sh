#!/bin/bash
# Run the shared scheme on an explicit simulator; the optional group defaults to all tests.
set -euo pipefail
if [[ $# -lt 1 || $# -gt 3 ]]; then
  echo "Usage: $0 SIMULATOR_UUID [RESULT_BUNDLE_PATH] [TEST_GROUP]" >&2
  exit 2
fi
cd "$(dirname "$0")/.."
result_path="${2:-/private/tmp/estimate-my-mortgage-$(date +%Y%m%d-%H%M%S).xcresult}"
group="${3:-all}"
selector_file="$(mktemp "${TMPDIR:-/private/tmp}/mortgage-test-selectors.XXXXXX")"
trap 'rm -f "$selector_file"' EXIT
# Process substitution hides validator failures. A nonempty command array also
# keeps the default full-suite invocation compatible with Bash 3.2 and nounset.
python3 scripts/test-groups.py "$group" > "$selector_file"
# The outer600-second cap permits native event-idling overhead; field and Save checks keep their own deadlines.
command=(xcodebuild -project EstimateMyMortgage.xcodeproj -scheme EstimateMyMortgage
  -destination "platform=iOS Simulator,id=$1"
  -derivedDataPath /private/tmp/estimate-my-mortgage-derived
  -resultBundlePath "$result_path" -parallel-testing-enabled NO -collect-test-diagnostics never
  -test-timeouts-enabled YES -default-test-execution-time-allowance 600
  -maximum-test-execution-time-allowance 600)
while IFS= read -r selector; do
  command+=("$selector")
done < "$selector_file"
command+=(CODE_SIGNING_ALLOWED=NO test)
set +e
"${command[@]}"
build_status=$?
set -e
if python3 scripts/test-groups.py "$group" --check-result "$result_path"; then
  coverage_status=0
else
  coverage_status=$?
fi
# Coverage checks must never turn a failed test/build into a successful job.
if [[ $build_status -ne 0 ]]; then
  exit "$build_status"
fi
exit "$coverage_status"
