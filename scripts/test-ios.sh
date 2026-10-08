#!/bin/bash
# Run the shared app scheme on an explicit available simulator; all results remain local.
set -euo pipefail
if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 SIMULATOR_UUID [RESULT_BUNDLE_PATH]" >&2
  exit 2
fi
cd "$(dirname "$0")/.."
result_path="${2:-/private/tmp/estimate-my-mortgage-$(date +%Y%m%d-%H%M%S).xcresult}"
xcodebuild -project EstimateMyMortgage.xcodeproj -scheme EstimateMyMortgage \
  -destination "platform=iOS Simulator,id=$1" \
  -derivedDataPath /private/tmp/estimate-my-mortgage-derived \
  -resultBundlePath "$result_path" -parallel-testing-enabled NO -collect-test-diagnostics never \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 180 \
  -maximum-test-execution-time-allowance 180 CODE_SIGNING_ALLOWED=NO test
