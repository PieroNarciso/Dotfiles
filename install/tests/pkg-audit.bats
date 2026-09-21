#!/usr/bin/env bats

load test_helper

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

make_groups() {
    mkdir -p "$TEST_TMPDIR/packages/optional"
    printf 'zsh\nstow\n' > "$TEST_TMPDIR/packages/core.txt"
}

fake_query() {
    cat > "$TEST_TMPDIR/query" <<FAKE
#!/usr/bin/env bash
printf '%s\n' $1
FAKE
    chmod +x "$TEST_TMPDIR/query"
}

@test "audit exits 0 when the group files match the live state" {
    make_groups
    fake_query "'zsh' 'stow'"
    run bash -c "PKG_AUDIT_DIR='$TEST_TMPDIR/packages' PKG_QUERY_CMD='$TEST_TMPDIR/query' bash '$INSTALL_DIR/pkg-audit.sh'"
    [ "$status" -eq 0 ]
}

@test "audit reports a package installed but unlisted" {
    make_groups
    fake_query "'zsh' 'stow' 'htop'"
    run bash -c "PKG_AUDIT_DIR='$TEST_TMPDIR/packages' PKG_QUERY_CMD='$TEST_TMPDIR/query' bash '$INSTALL_DIR/pkg-audit.sh' 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" == *"htop"* ]]
    [[ "$output" == *"unlisted"* ]]
}

@test "audit reports a package listed but not installed" {
    make_groups
    fake_query "'zsh'"
    run bash -c "PKG_AUDIT_DIR='$TEST_TMPDIR/packages' PKG_QUERY_CMD='$TEST_TMPDIR/query' bash '$INSTALL_DIR/pkg-audit.sh' 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" == *"stow"* ]]
    [[ "$output" == *"missing"* ]]
}
