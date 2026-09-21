#!/usr/bin/env bats

load test_helper

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
    run bash "$INSTALL_DIR/bootstrap.sh" --dry-run --groups core,dev
    [[ "$output" == *"core,dev"* ]]
}

@test "default group list is core,dev,desktop,fonts,apps,laptop" {
    run bash "$INSTALL_DIR/bootstrap.sh" --dry-run
    [[ "$output" == *"core,dev,desktop,fonts,apps,laptop"* ]]
}

@test "--dry-run changes nothing on disk" {
    before="$(find "$HOME" -maxdepth 1 -newermt '-1 second' | wc -l)"
    run bash "$INSTALL_DIR/bootstrap.sh" --dry-run
    [ "$status" -eq 0 ]
    [ "$before" -eq "$(find "$HOME" -maxdepth 1 -newermt '-1 second' | wc -l)" ]
}

@test "preflight fails when not on Arch" {
    run bash -c "BOOTSTRAP_ARCH_RELEASE='/nonexistent' bash '$INSTALL_DIR/bootstrap.sh' --dry-run 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Arch"* ]]
}

@test "preflight refuses to run as root" {
    run bash -c "BOOTSTRAP_FAKE_EUID=0 bash '$INSTALL_DIR/bootstrap.sh' --dry-run 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" == *"root"* ]]
}

@test "dry-run names every phase it would run" {
    run bash -c "bash '$INSTALL_DIR/bootstrap.sh' --dry-run 2>&1"
    [ "$status" -eq 0 ]
    for phase in preflight microcode paru packages dotfiles shell services report; do
        [[ "$output" == *"$phase"* ]]
    done
}

@test "pacman.conf phase enables multilib when it is commented out" {
    setup_tmpdir
    printf '#[multilib]\n#Include = /etc/pacman.d/mirrorlist\n' > "$TEST_TMPDIR/pacman.conf"
    run bash -c "BOOTSTRAP_PACMAN_CONF='$TEST_TMPDIR/pacman.conf' bash '$INSTALL_DIR/bootstrap.sh' --dry-run 2>&1"
    [[ "$output" == *"multilib"* ]]
    teardown_tmpdir
}

@test "an unknown group name is rejected before anything is installed" {
    run bash -c "bash '$INSTALL_DIR/bootstrap.sh' --dry-run --groups nosuchgroup 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" == *"nosuchgroup"* ]]
}

@test "--skip-dotfiles omits the dotfiles phase" {
    run bash -c "bash '$INSTALL_DIR/bootstrap.sh' --dry-run --skip-dotfiles 2>&1"
    [[ "$output" != *"cloning"* ]]
}
