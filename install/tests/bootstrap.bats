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
