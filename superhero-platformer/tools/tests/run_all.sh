#!/usr/bin/env bash
# Runs every test suite. From the project folder:
#
#     tools/tests/run_all.sh [path-to-godot]
#
# Each suite drives the real game headlessly and prints PASS/FAIL per check.
set -u
GODOT="${1:-godot}"
status=0

for suite in tools/tests/test_*.gd; do
    name="$(basename "$suite" .gd)"
    output="$("$GODOT" --headless --fixed-fps 60 --path . --script "$suite" 2>&1)"
    passed="$(grep -c '^PASS' <<< "$output" || true)"
    failed="$(grep -c '^FAIL' <<< "$output" || true)"
    printf '%-16s %2s passed, %2s failed\n' "$name" "$passed" "$failed"
    if [ "$failed" != "0" ]; then
        grep '^FAIL' <<< "$output" | sed 's/^/    /'
        status=1
    fi
done

exit $status
