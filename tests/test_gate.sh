#!/usr/bin/env bash
set -euo pipefail

# Test harness for fledge-plugin-gate
PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="$SCRIPT_DIR/bin/gate"

export FLEDGE_PLUGIN_DIR="/tmp/fledge-test-plugin-dir"
mkdir -p "$FLEDGE_PLUGIN_DIR"

assert_exit() {
    local expected="$1" desc="$2"
    shift 2
    local actual=0
    "$@" >/dev/null 2>&1 || actual=$?
    if [[ $actual -eq $expected ]]; then
        echo "  PASS  $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL  $desc (expected exit $expected, got $actual)"
        FAIL=$((FAIL + 1))
    fi
}

assert_output_contains() {
    local pattern="$1" desc="$2"
    shift 2
    local output
    output=$("$@" 2>&1 || true)
    if echo "$output" | grep -q "$pattern"; then
        echo "  PASS  $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL  $desc (output did not contain '$pattern')"
        echo "         got: $output"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== fledge-plugin-gate tests ==="
echo ""

# --- help / usage ---
echo "-- help --"
assert_exit 0 "help flag shows usage" "$GATE" --help
assert_exit 0 "no args shows usage" "$GATE"
assert_output_contains "USAGE" "help output contains USAGE" "$GATE" --help

# --- list ---
echo ""
echo "-- list --"
assert_output_contains "branch:" "list shows branch gate" "$GATE" list
assert_output_contains "clean" "list shows clean gate" "$GATE" list
assert_output_contains "env:" "list shows env gate" "$GATE" list
assert_output_contains "tool:" "list shows tool gate" "$GATE" list

# --- check with missing Gatefile ---
echo ""
echo "-- check (no Gatefile) --"
TMPDIR_TEST=$(mktemp -d)
pushd "$TMPDIR_TEST" >/dev/null
assert_exit 1 "check fails when no Gatefile exists" "$GATE" check
popd >/dev/null
rm -rf "$TMPDIR_TEST"

# --- check with gates ---
echo ""
echo "-- check (passing gates) --"
TMPDIR_TEST=$(mktemp -d)
pushd "$TMPDIR_TEST" >/dev/null
git init -q .
git config user.email "test@test.com"
git config user.name "Test"
touch dummy && git add dummy && git commit -q -m "init"

# Create a Gatefile with gates that will pass
export TEST_VAR="hello"
cat > Gatefile <<'EOF'
# A passing gate
env:TEST_VAR
tool:git
EOF
assert_exit 0 "check passes with satisfied gates" "$GATE" check
popd >/dev/null
rm -rf "$TMPDIR_TEST"

echo ""
echo "-- check (failing gates) --"
TMPDIR_TEST=$(mktemp -d)
pushd "$TMPDIR_TEST" >/dev/null
git init -q .
git config user.email "test@test.com"
git config user.name "Test"
touch dummy && git add dummy && git commit -q -m "init"

cat > Gatefile <<'EOF'
env:NONEXISTENT_VAR_XYZ_SHOULD_NOT_EXIST
EOF
assert_exit 1 "check fails with unsatisfied gate" "$GATE" check
popd >/dev/null
rm -rf "$TMPDIR_TEST"

# --- add ---
echo ""
echo "-- add --"
TMPDIR_TEST=$(mktemp -d)
pushd "$TMPDIR_TEST" >/dev/null
export FLEDGE_GATE_FILE="$TMPDIR_TEST/Gatefile"
$GATE add "tool:docker" >/dev/null 2>&1
if grep -q "tool:docker" "$FLEDGE_GATE_FILE"; then
    echo "  PASS  add appends gate to Gatefile"
    PASS=$((PASS + 1))
else
    echo "  FAIL  add did not append gate to Gatefile"
    FAIL=$((FAIL + 1))
fi
unset FLEDGE_GATE_FILE
popd >/dev/null
rm -rf "$TMPDIR_TEST"

# --- status ---
echo ""
echo "-- status --"
TMPDIR_TEST=$(mktemp -d)
pushd "$TMPDIR_TEST" >/dev/null
git init -q .
git config user.email "test@test.com"
git config user.name "Test"
touch dummy && git add dummy && git commit -q -m "init"

cat > Gatefile <<'EOF'
tool:git
env:NONEXISTENT_VAR_XYZ_SHOULD_NOT_EXIST
EOF
# status should always exit 0 (non-blocking)
assert_exit 0 "status does not block on failure" "$GATE" status
popd >/dev/null
rm -rf "$TMPDIR_TEST"

# --- unknown command ---
echo ""
echo "-- unknown command --"
assert_exit 1 "unknown command exits 1" "$GATE" bogus

# --- individual gate checks ---
echo ""
echo "-- individual gates --"
TMPDIR_TEST=$(mktemp -d)
pushd "$TMPDIR_TEST" >/dev/null
git init -q .
git config user.email "test@test.com"
git config user.name "Test"
touch dummy && git add dummy && git commit -q -m "init"

# file gate
touch "$TMPDIR_TEST/exists.txt"
cat > Gatefile <<EOF
file:$TMPDIR_TEST/exists.txt
EOF
assert_exit 0 "file gate passes for existing file" "$GATE" check

cat > Gatefile <<EOF
file:$TMPDIR_TEST/nope.txt
EOF
assert_exit 1 "file gate fails for missing file" "$GATE" check

# port gate (pick an unlikely-to-be-used high port)
cat > Gatefile <<'EOF'
port:59123
EOF
assert_exit 0 "port gate passes for available port" "$GATE" check

# branch gate
cat > Gatefile <<'EOF'
branch:main
EOF
assert_exit 0 "branch gate passes on correct branch" "$GATE" check

cat > Gatefile <<'EOF'
branch:release/*
EOF
assert_exit 1 "branch gate fails on wrong branch" "$GATE" check

popd >/dev/null
rm -rf "$TMPDIR_TEST"

# clean gate needs a fresh dir to avoid leftover untracked files
echo ""
echo "-- clean gate --"
TMPDIR_TEST=$(mktemp -d)
pushd "$TMPDIR_TEST" >/dev/null
git init -q .
git config user.email "test@test.com"
git config user.name "Test"
echo "clean" > Gatefile
git add dummy Gatefile 2>/dev/null || true
touch dummy && git add dummy Gatefile && git commit -q -m "init with Gatefile"
assert_exit 0 "clean gate passes on clean tree" "$GATE" check

touch dirty_file
assert_exit 1 "clean gate fails with untracked files" "$GATE" check

popd >/dev/null
rm -rf "$TMPDIR_TEST"

# --- version comparison gates ---
echo ""
echo "-- version gates --"
TMPDIR_TEST=$(mktemp -d)
pushd "$TMPDIR_TEST" >/dev/null
git init -q .
git config user.email "test@test.com"
git config user.name "Test"
touch dummy && git add dummy && git commit -q -m "init"

if command -v rustc >/dev/null 2>&1; then
    cat > Gatefile <<'EOF'
rust-version:1.0.0
EOF
    assert_exit 0 "rust-version gate passes for low requirement" "$GATE" check
fi

if node --version >/dev/null 2>&1; then
    cat > Gatefile <<'EOF'
node-version:0.1.0
EOF
    assert_exit 0 "node-version gate passes for low requirement" "$GATE" check
fi

popd >/dev/null
rm -rf "$TMPDIR_TEST"

# --- summary ---
echo ""
echo "==========================="
echo "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
