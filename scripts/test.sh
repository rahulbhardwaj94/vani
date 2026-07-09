#!/bin/bash
# Runs the unit tests. A plain executable stands in for `swift test` because
# Command Line Tools ship neither XCTest nor swift-testing (no Xcode needed).
set -euo pipefail
cd "$(dirname "$0")/.."
swift run VaniTestRunner
