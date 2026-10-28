#!/bin/sh
# Run the offline requests test suite against the local mock HTTP server.
#
# Usage: tools/run-tests.sh
#
# Zap resolves intra-project module imports relative to the entry file's own
# directory (D-0081, zaplang-io/zap#283), so this assembles a single build root
# that holds the library modules (src/requests.zap + src/requests/) next to the
# test driver and mock server (tests/*.zap), then runs the driver with
# `zap run` and diffs its stdout against tests/requests_test.expected. This is
# real multi-module compilation — no source concatenation. Exits non-zero on any
# mismatch.
#
# Printing + golden comparison (rather than in-process asserts) is how the Zap
# compiler's own suite and the aws-lambda-runtime offline test exercise string
# values; it keeps the check deterministic and toolchain-version independent.
#
# Set $ZAP to override the zap binary (default: `zap` on PATH, e.g. inside the
# ghcr.io/zaplang-io/zap image). See the README "Build & test" section.
set -eu

here=$(cd "$(dirname "$0")/.." && pwd)
zap="${ZAP:-zap}"

build="$here/build/test"
rm -rf "$build"
mkdir -p "$build"

# Library modules (the package itself).
cp "$here/src/requests.zap" "$build/"
cp -r "$here/src/requests" "$build/"
# Test driver + mock server.
cp "$here/tests/mockserver.zap" "$here/tests/requests_test.zap" "$build/"

got="$here/build/requests_test.out"
"$zap" run "$build/requests_test.zap" > "$got"

if diff -u "$here/tests/requests_test.expected" "$got"; then
    echo "requests offline test: PASS"
else
    echo "requests offline test: FAIL (actual output differs from tests/requests_test.expected)" >&2
    exit 1
fi
