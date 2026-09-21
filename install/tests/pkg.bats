#!/usr/bin/env bats

load test_helper

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "pkg_read_list strips comments and blank lines" {
    printf '# a comment\n\nzsh\n  stow  \n' > "$TEST_TMPDIR/list.txt"
    run bash -c "source '$INSTALL_DIR/lib/pkg.sh'; pkg_read_list '$TEST_TMPDIR/list.txt'"
    [ "$output" = "zsh
stow" ]
}

@test "pkg_read_list dies on a missing file" {
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/pkg.sh'; pkg_read_list '$TEST_TMPDIR/nope.txt'"
    [ "$status" -ne 0 ]
}

@test "pkg_missing returns only packages absent from the query output" {
    cat > "$TEST_TMPDIR/query" <<'FAKE'
#!/usr/bin/env bash
printf 'zsh\nstow\n'
FAKE
    chmod +x "$TEST_TMPDIR/query"
    run bash -c "source '$INSTALL_DIR/lib/pkg.sh'; PKG_QUERY_CMD='$TEST_TMPDIR/query' pkg_missing zsh neovim stow"
    [ "$output" = "neovim" ]
}

@test "pkg_missing prints nothing when everything is installed" {
    cat > "$TEST_TMPDIR/query" <<'FAKE'
#!/usr/bin/env bash
printf 'zsh\nstow\n'
FAKE
    chmod +x "$TEST_TMPDIR/query"
    run bash -c "source '$INSTALL_DIR/lib/pkg.sh'; PKG_QUERY_CMD='$TEST_TMPDIR/query' pkg_missing zsh stow"
    [ "$output" = "" ]
}

@test "pkg_install_file is a no-op in dry-run and prints the pacman command" {
    printf 'neovim\n' > "$TEST_TMPDIR/list.txt"
    cat > "$TEST_TMPDIR/query" <<'FAKE'
#!/usr/bin/env bash
printf 'zsh\n'
FAKE
    chmod +x "$TEST_TMPDIR/query"
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/pkg.sh'; DRY_RUN=1 PKG_QUERY_CMD='$TEST_TMPDIR/query' pkg_install_file '$TEST_TMPDIR/list.txt' 2>&1"
    [[ "$output" == *"DRY-RUN"* ]]
    [[ "$output" == *"neovim"* ]]
}

@test "pkg_install_file skips the install entirely when nothing is missing" {
    printf 'zsh\n' > "$TEST_TMPDIR/list.txt"
    cat > "$TEST_TMPDIR/query" <<'FAKE'
#!/usr/bin/env bash
printf 'zsh\n'
FAKE
    chmod +x "$TEST_TMPDIR/query"
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/pkg.sh'; DRY_RUN=1 PKG_QUERY_CMD='$TEST_TMPDIR/query' pkg_install_file '$TEST_TMPDIR/list.txt' 2>&1"
    [[ "$output" != *"DRY-RUN"* ]]
    [[ "$output" == *"up to date"* ]]
}
