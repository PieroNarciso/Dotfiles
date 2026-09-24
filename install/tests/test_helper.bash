#!/usr/bin/env bash
# Shared helpers for the install test suite.

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export INSTALL_DIR

# Keep the developer's git config out of every fixture repo. A global
# commit.gpgsign=true made each fixture commit pop a pinentry dialog on the
# desktop, and the test failed on its timeout unless the agent happened to
# have the passphrase cached.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

# Make a scratch directory that bats tears down after each test.
setup_tmpdir() {
    TEST_TMPDIR="$(mktemp -d)"
    export TEST_TMPDIR
}

# Safe to call from a bats teardown() in a file where some tests never make a
# temp directory: a bare [ -n ] would return 1 and fail the teardown.
teardown_tmpdir() {
    [ -n "${TEST_TMPDIR:-}" ] && rm -rf "$TEST_TMPDIR"
    return 0
}
