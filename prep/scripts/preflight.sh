#!/usr/bin/env bash
# preflight.sh — idempotent readiness check for the MyGo Explorer workspace.
#
# Prints PASS / FAIL (and SKIP for optional checks) per capability, then a
# summary, and exits non-zero if anything FAILed. Safe to re-run: builds go to
# a temporary directory that is removed on exit; no source files are modified.
#
# Usage:
#   prep/scripts/preflight.sh                 # fast checks (no GUI launch)
#   prep/scripts/preflight.sh --gui           # also launch the probe app briefly
#   prep/scripts/preflight.sh --verbose       # show command output on failures
#   prep/scripts/preflight.sh --no-log        # do not write the evidence log
#
# Environment overrides:
#   PROBE_DIR   probe project to build (default: prep/probe-native)
#   MYGO_BIN    mygo CLI binary (default: mygo on PATH, else $HOME/go/bin/mygo)
#   EXPECT_REF_HEAD  expected reference/mygo commit (default: b553a90)
#
# Reference environment (verified 2026-10-27): macOS 27.0.1 arm64, Apple M5 Pro,
# Go 1.26.4 host + go1.27.3 toolchain, mygo CLI 0.7.1, Bun 1.3.14, Xcode 27.1.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROBE="${PROBE_DIR:-$ROOT/prep/probe-native}"
EVIDENCE="$ROOT/research/prep/evidence"
EXPECT_REF_HEAD="${EXPECT_REF_HEAD:-b553a90}"
EXPECT_MYGO_VERSION="v0.7.1"
EXPECT_GO_MIN="1.27.3"

GUI=0
VERBOSE=0
WRITE_LOG=1
for arg in "$@"; do
	case "$arg" in
	--gui) GUI=1 ;;
	--verbose|-v) VERBOSE=1 ;;
	--no-log) WRITE_LOG=0 ;;
	-h|--help)
		sed -n '2,26p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
		exit 0
		;;
	*)
		echo "preflight: unknown flag: $arg (try --help)" >&2
		exit 2
		;;
	esac
done

TMP="$(mktemp -d "${TMPDIR:-/tmp}/mygo-preflight.XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

PASS=0
FAIL=0
SKIP=0
FAILED_NAMES=""

say() { printf '%s\n' "$*"; }

pass() { PASS=$((PASS + 1)); printf 'PASS  %-32s %s\n' "$1" "${2:-}"; }
fail() {
	FAIL=$((FAIL + 1))
	FAILED_NAMES="$FAILED_NAMES $1"
	printf 'FAIL  %-32s %s\n' "$1" "${2:-}"
	if [ "$VERBOSE" = 1 ] && [ -n "${RUN_LOG:-}" ] && [ -f "$RUN_LOG" ]; then
		sed 's/^/      | /' "$RUN_LOG" | tail -20
	fi
}
skip() { SKIP=$((SKIP + 1)); printf 'SKIP  %-32s %s\n' "$1" "${2:-}"; }

# run_check NAME COMMAND... — runs COMMAND, logging to $TMP/<name>.log and
# setting RUN_RC/RUN_LOG. The redirection happens in a subshell so that the
# counters and RUN_RC stay in this shell (not a lost subshell).
run_check() {
	local name="$1"
	shift
	RUN_LOG="$TMP/$(printf '%s' "$name" | tr -c '[:alnum:]_-' '_').log"
	( "$@" ) >"$RUN_LOG" 2>&1
	RUN_RC=$?
}

# probe_run NAME COMMAND... — like run_check, but in $PROBE.
probe_run() {
	local name="$1"
	shift
	RUN_LOG="$TMP/$(printf '%s' "$name" | tr -c '[:alnum:]_-' '_').log"
	( cd "$PROBE" && "$@" ) >"$RUN_LOG" 2>&1
	RUN_RC=$?
}

check() {
	local name="$1" desc="$2"
	shift 2
	run_check "$name" "$@"
	if [ "$RUN_RC" -eq 0 ]; then pass "$name" "$desc"; else fail "$name" "see $RUN_LOG"; fi
}

say "MyGo Explorer preflight — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
say "workspace: $ROOT"
say "probe:     $PROBE"
say ""

# ---------------------------------------------------------------- toolchain --
say "-- host and toolchain --"

OS="$(sw_vers -productVersion 2>/dev/null || echo unknown)"
ARCH="$(uname -m)"
if [ "$(uname -s)" = "Darwin" ] && [ "$ARCH" = "arm64" ]; then
	pass "host OS" "macOS $OS $ARCH"
else
	fail "host OS" "expected Darwin/arm64 (reference env), got $(uname -s)/$ARCH"
fi

if command -v go >/dev/null 2>&1; then
	pass "host go" "$(go version)"
	run_check "toolchain-$EXPECT_GO_MIN" env GOTOOLCHAIN="go$EXPECT_GO_MIN" go version
	if [ "$RUN_RC" -eq 0 ] && grep -q "go$EXPECT_GO_MIN" "$RUN_LOG"; then
		pass "go toolchain $EXPECT_GO_MIN" "$(cat "$RUN_LOG")"
	else
		fail "go toolchain $EXPECT_GO_MIN" "GOTOOLCHAIN=go$EXPECT_GO_MIN go version failed (see $RUN_LOG)"
	fi
else
	fail "host go" "go not on PATH (install Go 1.27+ from https://go.dev/dl/)"
	skip "go toolchain $EXPECT_GO_MIN" "no host go"
fi

MYGO=""
if [ -n "${MYGO_BIN:-}" ]; then
	MYGO="$MYGO_BIN"
elif command -v mygo >/dev/null 2>&1; then
	MYGO="$(command -v mygo)"
elif [ -x "$HOME/go/bin/mygo" ]; then
	MYGO="$HOME/go/bin/mygo"
fi
if [ -n "$MYGO" ] && [ -x "$MYGO" ]; then
	run_check "mygo-cli" "$MYGO" version
	if [ "$RUN_RC" -eq 0 ] && grep -q "0\.7\.1" "$RUN_LOG"; then
		pass "mygo CLI" "$(cat "$RUN_LOG") ($MYGO)"
	else
		fail "mygo CLI" "want mygo 0.7.1 (see $RUN_LOG)"
	fi
else
	fail "mygo CLI" "not found (go install github.com/egoist/mygo/cmd/mygo@v0.7.1)"
fi

if command -v bun >/dev/null 2>&1; then
	pass "bun (web template only)" "bun $(bun --version)"
else
	skip "bun (web template only)" "not installed; native UI does not need Bun"
fi

if xcode-select -p >/dev/null 2>&1; then
	pass "Xcode CLI tools" "$(xcode-select -p)"
else
	skip "Xcode CLI tools" "not installed; native UI does not need Xcode"
fi

# ------------------------------------------------------------------ project --
say ""
say "-- probe project ($PROBE) --"

HAVE_PROBE=0
if [ -f "$PROBE/go.mod" ]; then
	HAVE_PROBE=1
	run_check "probe-go-directive" grep -Eq "^go $EXPECT_GO_MIN$" "$PROBE/go.mod"
	if [ "$RUN_RC" -eq 0 ]; then
		pass "probe go directive" "go $EXPECT_GO_MIN"
	else
		fail "probe go directive" "go.mod does not say 'go $EXPECT_GO_MIN'"
	fi
	run_check "probe-tool-directive" grep -q "tool github.com/egoist/mygo/cmd/mygo" "$PROBE/go.mod"
	if [ "$RUN_RC" -eq 0 ]; then
		pass "probe tool directive" "tool github.com/egoist/mygo/cmd/mygo"
	else
		fail "probe tool directive" "go.mod lacks the tool directive for go tool mygo"
	fi
	probe_run "probe-module" go list -m github.com/egoist/mygo
	if [ "$RUN_RC" -eq 0 ] && grep -q "$EXPECT_MYGO_VERSION" "$RUN_LOG"; then
		pass "pinned MyGo module" "$(cat "$RUN_LOG")"
	else
		fail "pinned MyGo module" "want github.com/egoist/mygo $EXPECT_MYGO_VERSION"
	fi
else
	fail "probe project" "$PROBE/go.mod missing (run: mygo init -template native probe-native from prep/)"
fi

REF="$ROOT/reference/mygo"
if [ -d "$REF/.git" ] || [ -f "$REF/.git" ]; then
	run_check "reference-head" git -C "$REF" rev-parse --short HEAD
	if [ "$RUN_RC" -eq 0 ] && [ "$(cat "$RUN_LOG")" = "$EXPECT_REF_HEAD" ]; then
		pass "reference checkout HEAD" "$EXPECT_REF_HEAD"
	else
		fail "reference checkout HEAD" "want $EXPECT_REF_HEAD (see $RUN_LOG)"
	fi
	run_check "reference-clean" git -C "$REF" status --porcelain
	if [ "$RUN_RC" -eq 0 ] && [ ! -s "$RUN_LOG" ]; then
		pass "reference checkout clean" "no local changes"
	else
		fail "reference checkout clean" "reference/mygo has local changes; it is read-only"
	fi
else
	skip "reference checkout" "$REF not a git checkout"
fi

if [ -n "$MYGO" ] && [ -x "$MYGO" ] && [ "$HAVE_PROBE" = 1 ]; then
	probe_run "doctor" "$MYGO" doctor
	if [ "$RUN_RC" -eq 0 ] && ! grep -q '✗' "$RUN_LOG"; then
		pass "mygo doctor" "no missing requirement (optional tools may warn)"
	else
		fail "mygo doctor" "see $RUN_LOG"
	fi
fi

# ------------------------------------------------------- build and test ----
say ""
say "-- build and test --"

if [ "$HAVE_PROBE" = 1 ]; then
	START=$(date +%s)
	probe_run "go-test" go test ./...
	ELAPSED=$(($(date +%s) - START))
	if [ "$RUN_RC" -eq 0 ]; then
		pass "headless view tests" "go test ./... in ${ELAPSED}s"
	else
		fail "headless view tests" "go test ./... failed (see $RUN_LOG)"
	fi

	probe_run "go-vet" go tool mygo vet
	if [ "$RUN_RC" -eq 0 ]; then
		pass "mygo vet" "no findings"
	else
		fail "mygo vet" "go tool mygo vet failed (see $RUN_LOG)"
	fi

	if [ -f "$PROBE/capture_test.go" ]; then
		START=$(date +%s)
		RUN_LOG="$TMP/headless-snapshot.log"
		( cd "$PROBE" && PROBE_EVIDENCE_DIR="$TMP/render" go test -v -run TestCapture . ) >"$RUN_LOG" 2>&1
		RUN_RC=$?
		ELAPSED=$(($(date +%s) - START))
		if [ "$RUN_RC" -eq 0 ] && grep -q "ui.Render deterministic" "$RUN_LOG"; then
			pass "headless snapshots" "ui.Render + ui.Tester deterministic in ${ELAPSED}s"
		else
			fail "headless snapshots" "capture_test.go failed (see $RUN_LOG)"
		fi
	else
		skip "headless snapshots" "capture_test.go not present in probe"
	fi

	START=$(date +%s)
	probe_run "package-darwin" go tool mygo build -platform darwin/arm64 -skip-dmg -o "$TMP/build-darwin"
	ELAPSED=$(($(date +%s) - START))
	APP="$(find "$TMP/build-darwin" -maxdepth 3 -name '*.app' 2>/dev/null | head -1)"
	if [ "$RUN_RC" -eq 0 ] && [ -n "$APP" ]; then
		pass "macOS packaging" "darwin/arm64 .app $(du -sh "$APP" 2>/dev/null | cut -f1) in ${ELAPSED}s"
	else
		fail "macOS packaging" "go tool mygo build darwin/arm64 failed (see $RUN_LOG)"
	fi

	START=$(date +%s)
	probe_run "cross-compile" go tool mygo build -platform linux/amd64,windows/amd64 -skip-dmg -o "$TMP/build-cross"
	ELAPSED=$(($(date +%s) - START))
	LINUX_BIN="$(find "$TMP/build-cross/linux-amd64" -maxdepth 1 -type f \( -name 'probe-*' -o -name 'app' \) 2>/dev/null | grep -v -E '\.(deb|tar\.gz|desktop|png)$' | head -1)"
	WIN_BIN="$(find "$TMP/build-cross/windows-amd64" -maxdepth 1 -name '*.exe' 2>/dev/null | head -1)"
	if [ "$RUN_RC" -eq 0 ] && [ -n "$LINUX_BIN" ] && [ -n "$WIN_BIN" ]; then
		pass "cross-compile (no cgo)" "linux/amd64 + windows/amd64 in ${ELAPSED}s"
	else
		fail "cross-compile (no cgo)" "linux/windows cross build failed (see $RUN_LOG)"
	fi

	START=$(date +%s)
	probe_run "web-build" go tool mygo build -platform web -o "$TMP/build-web"
	ELAPSED=$(($(date +%s) - START))
	WASM="$(find "$TMP/build-web/web" -name '*.wasm' 2>/dev/null | head -1)"
	if [ "$RUN_RC" -eq 0 ] && [ -n "$WASM" ]; then
		pass "web/wasm build" "$(du -h "$WASM" | cut -f1) wasm in ${ELAPSED}s"
	else
		fail "web/wasm build" "go tool mygo build -platform web failed (see $RUN_LOG)"
	fi
else
	skip "build and test" "probe project missing"
fi

# ------------------------------------------------------------- optional GUI --
say ""
say "-- GUI (optional) --"
if [ "$GUI" = 1 ]; then
	APP="$(find "$TMP/build-darwin" -maxdepth 3 -name '*.app' 2>/dev/null | head -1)"
	if [ -z "$APP" ]; then
		fail "GUI launch" "no .app from the packaging check"
	elif ! pgrep -x WindowServer >/dev/null 2>&1; then
		skip "GUI launch" "no WindowServer session (SSH/headless)"
	else
		BIN="$APP/Contents/MacOS/$(basename "$APP" .app)"
		GUI_LOG="$TMP/gui.log"
		( MYGO_FRAME_STATS=all "$BIN" >"$GUI_LOG" 2>&1 ) &
		GUI_PID=$!
		sleep 2
		if kill -0 "$GUI_PID" 2>/dev/null; then
			pass "GUI window opens" "app process alive after 2s"
			if grep -q "drawn on the GPU" "$GUI_LOG"; then
				pass "GPU rendering (Metal)" "$(grep -m1 'drawn on the GPU' "$GUI_LOG" | cut -c1-110)..."
			else
				fail "GPU rendering (Metal)" "no 'drawn on the GPU' frame stat (see $GUI_LOG)"
			fi
			if command -v screencapture >/dev/null 2>&1; then
				mkdir -p "$EVIDENCE"
				if screencapture -x "$EVIDENCE/preflight-gui.png" >/dev/null 2>&1 && [ -s "$EVIDENCE/preflight-gui.png" ]; then
					pass "GUI screenshot" "$EVIDENCE/preflight-gui.png ($(du -h "$EVIDENCE/preflight-gui.png" | cut -f1))"
				else
					skip "GUI screenshot" "screencapture failed (Screen Recording permission?)"
				fi
			fi
		else
			fail "GUI window opens" "app exited early (see $GUI_LOG)"
		fi
		kill "$GUI_PID" 2>/dev/null
		sleep 0.5
		kill -9 "$GUI_PID" 2>/dev/null
		wait "$GUI_PID" 2>/dev/null
	fi
else
	skip "GUI launch" "pass --gui to launch the probe app for ~2s"
fi

# ---------------------------------------------------------------- cleanup --
say ""
LEFTOVER="$(pgrep -fl 'probe-native|probe-capture|mygo dev' 2>/dev/null | grep -v pgrep)"
if [ -n "$LEFTOVER" ]; then
	fail "process cleanup" "still running: $(printf '%s' "$LEFTOVER" | tr '\n' ';')"
else
	pass "process cleanup" "no probe or dev-server processes left"
fi

# ----------------------------------------------------------------- summary --
say ""
say "summary: $PASS passed, $FAIL failed, $SKIP skipped"
if [ "$FAIL" -gt 0 ]; then
	say "failed:${FAILED_NAMES}"
	say "result: FAIL"
	exit 1
fi
say "result: PASS"

if [ "$WRITE_LOG" = 1 ] && [ -d "$ROOT/research/prep" ]; then
	mkdir -p "$EVIDENCE"
	{
		echo "preflight run $(date -u +%Y-%m-%dT%H:%M:%SZ) on $(sw_vers -productVersion 2>/dev/null || uname -s) $(uname -m)"
		echo "probe: $PROBE"
		echo "result: PASS ($PASS passed, $SKIP skipped)"
	} >"$EVIDENCE/preflight-last.log"
fi
