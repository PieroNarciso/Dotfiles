#!/usr/bin/env bats

load test_helper

setup() {
    source "$INSTALL_DIR/lib/log.sh"
}

@test "log_info writes to stderr, not stdout" {
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; log_info hello 2>/dev/null"
    [ "$output" = "" ]
}

@test "log_info message reaches stderr" {
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; log_info hello 2>&1 >/dev/null"
    [[ "$output" == *"hello"* ]]
}

@test "run executes the command when DRY_RUN is 0" {
    setup_tmpdir
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; DRY_RUN=0 run touch '$TEST_TMPDIR/made'"
    [ -f "$TEST_TMPDIR/made" ]
    teardown_tmpdir
}

@test "run prints instead of executing when DRY_RUN is 1" {
    setup_tmpdir
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; DRY_RUN=1 run touch '$TEST_TMPDIR/made' 2>&1"
    [ ! -f "$TEST_TMPDIR/made" ]
    [[ "$output" == *"DRY-RUN"* ]]
    teardown_tmpdir
}

@test "run returns 0 in dry-run even for a command that would fail" {
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; DRY_RUN=1 run false"
    [ "$status" -eq 0 ]
}

@test "die exits non-zero" {
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; die 'boom'"
    [ "$status" -eq 1 ]
}
