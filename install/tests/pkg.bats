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

@test "aur_install_file is a no-op in dry-run and prints the paru command" {
    printf 'neovim\n' > "$TEST_TMPDIR/list.txt"
    cat > "$TEST_TMPDIR/query" <<'FAKE'
#!/usr/bin/env bash
printf 'zsh\n'
FAKE
    chmod +x "$TEST_TMPDIR/query"
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/pkg.sh'; DRY_RUN=1 PKG_QUERY_CMD='$TEST_TMPDIR/query' aur_install_file '$TEST_TMPDIR/list.txt' 2>&1"
    [[ "$output" == *"DRY-RUN"* ]]
    [[ "$output" == *"neovim"* ]]
}

@test "aur_install_file skips the install entirely when nothing is missing" {
    printf 'zsh\n' > "$TEST_TMPDIR/list.txt"
    cat > "$TEST_TMPDIR/query" <<'FAKE'
#!/usr/bin/env bash
printf 'zsh\n'
FAKE
    chmod +x "$TEST_TMPDIR/query"
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/pkg.sh'; DRY_RUN=1 PKG_QUERY_CMD='$TEST_TMPDIR/query' aur_install_file '$TEST_TMPDIR/list.txt' 2>&1"
    [[ "$output" != *"DRY-RUN"* ]]
    [[ "$output" == *"up to date"* ]]
}

@test "a group is installed in one transaction so providers resolve" {
    run bash -c "
        cd '$BATS_TEST_DIRNAME/../..'
        source install/lib/log.sh
        source install/lib/pkg.sh
        pkg_missing() { printf '%s\n' waybar pipewire-jack; }
        printf 'waybar\npipewire-jack\n' > '$BATS_TEST_TMPDIR/g.txt'
        _pkg_install_with 'echo INSTALLER' '$BATS_TEST_TMPDIR/g.txt'
    "
    [ "$status" -eq 0 ]
    # Exactly one installer invocation, carrying both packages.
    [ "$(grep -c 'INSTALLER' <<< "$output")" -eq 1 ]
    [[ "$output" == *"waybar"*"pipewire-jack"* ]]
}

@test "a failed group falls back to one package at a time to isolate the bad one" {
    run bash -c "
        cd '$BATS_TEST_DIRNAME/../..'
        source install/lib/log.sh
        source install/lib/pkg.sh
        pkg_missing() { printf '%s\n' good1 bad good2; }
        # Fails the whole-group call and the single call for 'bad'.
        fake() {
            # Log every attempt, not just the successes: the batches that
            # fail are exactly the evidence of bisection.
            echo ATTEMPT \"\$@\"
            for a in \"\$@\"; do
                [ \"\$a\" = bad ] && return 1
            done
            echo INSTALLED \"\$@\"
            return 0
        }
        export -f fake
        printf 'good1\nbad\ngood2\n' > '$BATS_TEST_TMPDIR/g.txt'
        _pkg_install_with 'fake' '$BATS_TEST_TMPDIR/g.txt'
        echo \"FAILED=\${PKG_FAILED[*]}\"
    "
    [ "$status" -eq 0 ]
    # The good ones still got installed after the group failed.
    [[ "$output" == *"INSTALLED --needed --noconfirm good1"* ]]
    [[ "$output" == *"INSTALLED --needed --noconfirm good2"* ]]
    # Only the genuinely bad package is recorded.
    [[ "$output" == *"FAILED=bad"* ]]
    # The three assertions above all hold for a flat one-at-a-time loop too,
    # so on their own they cannot tell the shipped bisection from the design
    # it replaced. Bisection's signature is that after the whole group fails
    # it retries HALVES: good1 alone, then {bad,good2} together. A flat loop
    # never attempts a multi-package batch, so this line is what gives the
    # test teeth against the pre-17c9038 code.
    [[ "$output" == *"ATTEMPT --needed --noconfirm bad good2"* ]]
}

@test "an up-to-date group invokes the installer not at all" {
    run bash -c "
        cd '$BATS_TEST_DIRNAME/../..'
        source install/lib/log.sh
        source install/lib/pkg.sh
        pkg_missing() { :; }
        printf 'waybar\n' > '$BATS_TEST_TMPDIR/g.txt'
        _pkg_install_with 'echo INSTALLER' '$BATS_TEST_TMPDIR/g.txt'
    "
    [ "$status" -eq 0 ]
    [[ "$output" != *"INSTALLER"* ]]
    [[ "$output" == *"up to date"* ]]
}

@test "a group failure unrelated to any package does not silently reinstall one-at-a-time" {
    # Regression for a hole in the naive fallback: if the whole-group
    # transaction fails for a reason that has nothing to do with any single
    # package (a bad db, a network blip, one unrelated bogus name), falling
    # straight to one-package-at-a-time hides the rest of a large group from
    # pacman's resolver again -- reintroducing the exact D6 provider bug for
    # the survivors. Batching should keep unrelated packages together as long
    # as possible instead of degrading the whole group to singletons.
    run bash -c "
        cd '$BATS_TEST_DIRNAME/../..'
        source install/lib/log.sh
        source install/lib/pkg.sh
        pkg_missing() { printf '%s\n' a b bad c d e f g; }
        fake() {
            for arg in \"\$@\"; do
                [ \"\$arg\" = bad ] && return 1
            done
            echo INSTALLED \"\$@\"
            return 0
        }
        export -f fake
        printf 'a\nb\nbad\nc\nd\ne\nf\ng\n' > '$BATS_TEST_TMPDIR/g.txt'
        _pkg_install_with 'fake' '$BATS_TEST_TMPDIR/g.txt'
        echo \"FAILED=\${PKG_FAILED[*]}\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"FAILED=bad"* ]]
    # At least one successful batch installed more than one package together
    # (the fix isolates the bad package without shattering the whole group
    # into singleton installs).
    run grep -E 'INSTALLED --needed --noconfirm [^ ]+ [^ ]+' <<< "$output"
    [ "$status" -eq 0 ]
}
