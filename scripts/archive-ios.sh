#!/bin/bash
# Build a Release device archive without uploading or changing Apple account state.
# --unsigned creates a QA archive that cannot be uploaded to App Store Connect.
set -euo pipefail

signing_args=(CODE_SIGNING_ALLOWED=YES)
if [[ "${1:-}" == "--unsigned" ]]; then
    signing_args=(CODE_SIGNING_ALLOWED=NO)
    shift
fi
if [[ $# != 1 || "$1" != /* ]]; then
    echo "Usage: $0 [--unsigned] /absolute/path/EstimateMyMortgage.xcarchive" >&2
    exit 2
fi
archive_path="$1"
if [[ -e "$archive_path" || -e "$archive_path.derived-data" ]]; then
    echo "Choose a new archive path; existing archives and build files are preserved." >&2
    exit 2
fi
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$(dirname "$archive_path")"
xcodebuild -project "$repo_root/EstimateMyMortgage.xcodeproj" \
    -scheme EstimateMyMortgage -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$archive_path" -derivedDataPath "$archive_path.derived-data" \
    "${signing_args[@]}" archive
