#!/usr/bin/env bats

load test_helper

# Every test that reaches a phase gets an isolated $HOME and a pacman.conf
# fixture, so nothing ever touches this developer's real dotfiles, real
# /etc/pacman.conf, or the real package/service state.
setup_fixture() {
    setup_tmpdir
    FAKE_HOME="$TEST_TMPDIR/home"
    mkdir -p "$FAKE_HOME"
    FAKE_PACMAN_CONF="$TEST_TMPDIR/pacman.conf"
    printf '[multilib]\nInclude = /etc/pacman.d/mirrorlist\nColor\nParallelDownloads = 5\n' > "$FAKE_PACMAN_CONF"
}

@test "--help exits 0 and documents the flags" {
    run bash "$INSTALL_DIR/bootstrap.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--dry-run"* ]]
    [[ "$output" == *"--groups"* ]]
    [[ "$output" == *"--skip-dotfiles"* ]]
}

@test "unknown flag exits non-zero" {
    run bash "$INSTALL_DIR/bootstrap.sh" --nonsense
    [ "$status" -ne 0 ]
}

@test "--groups sets the group list" {
    setup_fixture
    run bash -c "HOME='$FAKE_HOME' BOOTSTRAP_PACMAN_CONF='$FAKE_PACMAN_CONF' bash '$INSTALL_DIR/bootstrap.sh' --dry-run --skip-dotfiles --groups core,dev 2>&1"
    [[ "$output" == *"core,dev"* ]]
    teardown_tmpdir
}

@test "default group list is core,dev,desktop,fonts,apps,laptop" {
    setup_fixture
    run bash -c "HOME='$FAKE_HOME' BOOTSTRAP_PACMAN_CONF='$FAKE_PACMAN_CONF' bash '$INSTALL_DIR/bootstrap.sh' --dry-run --skip-dotfiles 2>&1"
    [[ "$output" == *"core,dev,desktop,fonts,apps,laptop"* ]]
    teardown_tmpdir
}

@test "--dry-run changes nothing on disk" {
    setup_fixture
    before="$(find "$FAKE_HOME" -mindepth 1 | wc -l)"
    run bash -c "HOME='$FAKE_HOME' BOOTSTRAP_PACMAN_CONF='$FAKE_PACMAN_CONF' bash '$INSTALL_DIR/bootstrap.sh' --dry-run 2>&1"
    [ "$status" -eq 0 ]
    [ "$before" -eq "$(find "$FAKE_HOME" -mindepth 1 | wc -l)" ]
    teardown_tmpdir
}

@test "preflight fails when not on Arch" {
    setup_fixture
    run bash -c "HOME='$FAKE_HOME' BOOTSTRAP_ARCH_RELEASE='/nonexistent' bash '$INSTALL_DIR/bootstrap.sh' --dry-run 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Arch"* ]]
    teardown_tmpdir
}

@test "preflight refuses to run as root" {
    setup_fixture
    run bash -c "HOME='$FAKE_HOME' BOOTSTRAP_FAKE_EUID=0 bash '$INSTALL_DIR/bootstrap.sh' --dry-run 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" == *"root"* ]]
    teardown_tmpdir
}

@test "dry-run names every phase it would run" {
    setup_fixture
    run bash -c "HOME='$FAKE_HOME' BOOTSTRAP_PACMAN_CONF='$FAKE_PACMAN_CONF' bash '$INSTALL_DIR/bootstrap.sh' --dry-run 2>&1"
    [ "$status" -eq 0 ]
    for phase in preflight microcode paru packages dotfiles shell services report; do
        [[ "$output" == *"$phase"* ]]
    done
    teardown_tmpdir
}

@test "pacman.conf phase enables multilib when it is commented out" {
    setup_fixture
    printf '#[multilib]\n#Include = /etc/pacman.d/mirrorlist\n' > "$FAKE_PACMAN_CONF"
    before="$(cat "$FAKE_PACMAN_CONF")"
    run bash -c "HOME='$FAKE_HOME' BOOTSTRAP_PACMAN_CONF='$FAKE_PACMAN_CONF' bash '$INSTALL_DIR/bootstrap.sh' --dry-run --skip-dotfiles 2>&1"
    [ "$status" -eq 0 ]
    # The branch that actually enables multilib must have been taken (not the
    # "already enabled" no-op branch), evidenced by the exact sed it would run.
    [[ "$output" == *'DRY-RUN: sed -i s/^#\[multilib\]/[multilib]/; /^\[multilib\]/{n;s/^#Include/Include/}'*"$FAKE_PACMAN_CONF"* ]]
    [[ "$output" != *"multilib already enabled"* ]]
    # DRY_RUN must still mean nothing on disk actually changed.
    [ "$(cat "$FAKE_PACMAN_CONF")" = "$before" ]
    # Prove the sed itself is correct by running it for real against a
    # disposable copy (never through bootstrap.sh, no sudo involved).
    cp "$FAKE_PACMAN_CONF" "$TEST_TMPDIR/applied.conf"
    sed -i 's/^#\[multilib\]/[multilib]/; /^\[multilib\]/{n;s/^#Include/Include/}' "$TEST_TMPDIR/applied.conf"
    grep -qx '\[multilib\]' "$TEST_TMPDIR/applied.conf"
    grep -qx 'Include = /etc/pacman.d/mirrorlist' "$TEST_TMPDIR/applied.conf"
    teardown_tmpdir
}

@test "pacman.conf phase is a no-op when multilib is already enabled" {
    setup_fixture
    before="$(cat "$FAKE_PACMAN_CONF")"
    run bash -c "HOME='$FAKE_HOME' BOOTSTRAP_PACMAN_CONF='$FAKE_PACMAN_CONF' bash '$INSTALL_DIR/bootstrap.sh' --dry-run --skip-dotfiles 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"multilib already enabled"* ]]
    [[ "$output" != *"sed -i"* ]]
    # Byte-identical: DRY_RUN guarantees it, and there was nothing to change anyway.
    [ "$(cat "$FAKE_PACMAN_CONF")" = "$before" ]
    teardown_tmpdir
}

@test "an unknown group name is rejected before anything is installed" {
    setup_fixture
    run bash -c "HOME='$FAKE_HOME' BOOTSTRAP_PACMAN_CONF='$FAKE_PACMAN_CONF' bash '$INSTALL_DIR/bootstrap.sh' --dry-run --groups nosuchgroup 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" == *"nosuchgroup"* ]]
    [[ "$output" != *"DRY-RUN:"* ]]
    teardown_tmpdir
}

@test "--skip-dotfiles omits the dotfiles phase" {
    setup_fixture
    run bash -c "HOME='$FAKE_HOME' BOOTSTRAP_PACMAN_CONF='$FAKE_PACMAN_CONF' bash '$INSTALL_DIR/bootstrap.sh' --dry-run --skip-dotfiles 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"skipping dotfiles"* ]]
    [[ "$output" != *"::  dotfiles"* ]]
    teardown_tmpdir
}
