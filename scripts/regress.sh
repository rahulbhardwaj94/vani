#!/bin/bash
# Build and run the regression harness against fixtures/baseline.json.
# ./scripts/regress.sh                   -> fail on any regressed fixture
# ./scripts/regress.sh --update-baseline -> accept current scores as baseline
set -euo pipefail
cd "$(dirname "$0")/.."
[ -e fixtures/s1-ramble.wav ] || ./scripts/gen-fixtures.sh
swift build -c release --product VaniRegress
.build/release/VaniRegress "$@"
