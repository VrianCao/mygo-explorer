#!/usr/bin/env bash
# Local quality gate for MyGo Explorer (TODO.md 1.1.8).
#
# Checks formatting, runs the tests, runs MyGo's vet (Go vet plus native UI
# build-lifetime checks), compiles every package and packages the app for the
# host platform. Prints a PASS/FAIL summary and exits non-zero when any check
# fails.
#
#   ./scripts/check.sh
#
# The Go toolchain is the one pinned by go.mod (GOTOOLCHAIN=auto, the default),
# so this script needs no `mygo` on PATH: `go tool mygo` reads the tool
# directive.
set -u

cd "$(dirname "$0")/.." || exit 1

# Compiled binaries go to a temporary directory: a plain `go build` of the
# main package would drop an executable named app next to the sources.
builddir=$(mktemp -d) || exit 1
trap 'rm -rf "$builddir"' EXIT

failures=0
passed=0
summary=()

section() {
	printf '\n==> %s\n' "$1"
}

record_pass() {
	summary+=("PASS  ${1}")
	passed=$((passed + 1))
	printf 'PASS  %s\n' "$1"
}

record_fail() {
	summary+=("FAIL  ${1}")
	failures=$((failures + 1))
	printf 'FAIL  %s\n' "$1"
}

# check runs one named command and records its result.
check() {
	local name=$1
	shift
	section "$name"
	local start=$SECONDS
	if "$@"; then
		printf '%s took %ds\n' "$name" "$((SECONDS - start))"
		record_pass "$name"
	else
		local status=$?
		printf '%s failed with exit %d after %ds\n' "$name" "$status" "$((SECONDS - start))"
		record_fail "$name"
	fi
}

check_gofmt() {
	local unformatted
	unformatted=$(gofmt -l . 2>&1)
	if [ -n "$unformatted" ]; then
		printf 'gofmt would reformat:\n%s\n' "$unformatted"
		return 1
	fi
	printf 'all Go files are formatted\n'
}

check "gofmt -l ." check_gofmt
check "go test ./..." go test ./...
check "go tool mygo vet ." go tool mygo vet .
check "go build ./..." go build -o "$builddir/" ./...
check "go tool mygo build" go tool mygo build

section "Summary"
for line in "${summary[@]}"; do
	printf '%s\n' "$line"
done
printf '%d passed, %d failed\n' "$passed" "$failures"

if [ "$failures" -ne 0 ]; then
	printf 'CHECK FAILED\n'
	exit 1
fi
printf 'CHECK PASSED\n'
exit 0
