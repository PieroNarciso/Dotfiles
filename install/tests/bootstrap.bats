#!/usr/bin/env bats

load test_helper

# Inline teardown at the end of a test body never runs when an assertion
# fails, so every failing test used to leak its temp directory. bats runs
# this hook either way.
teardown() { teardown_tmpdir; }

# Every test that reaches a phase gets an isolated $HOME, a pacman.conf
# fixture and an empty loader-entries directory, so nothing ever touches this
# developer's real dotfiles, real /etc/pacman.conf, real /boot, or the real
# package/service state. BOOTSTRAP_SKIP_NETCHECK keeps the suite runnable
# offline.
setup_fixture() {
    setup_tmpdir
    FAKE_HOME="$TEST_TMPDIR/home"
    mkdir -p "$FAKE_HOME"
    FAKE_ENTRIES="$TEST_TMPDIR/entries"
    mkdir -p "$FAKE_ENTRIES"
    FAKE_PACMAN_CONF="$TEST_TMPDIR/pacman.conf"
    printf '[multilib]\nInclude = /etc/pacman.d/mirrorlist\nColor\nParallelDownloads = 5\n' > "$FAKE_PACMAN_CONF"
    FIXTURE_ENV="HOME='$FAKE_HOME' BOOTSTRAP_PACMAN_CONF='$FAKE_PACMAN_CONF'"
    FIXTURE_ENV="$FIXTURE_ENV BOOTCTL_ENTRIES_DIR='$FAKE_ENTRIES' BOOTSTRAP_SKIP_NETCHECK=1"
    # No microcode hook, so phase_microcode still reaches the loader entries
    # whatever this machine's own /etc/mkinitcpio.conf says.
    FAKE_MKINITCPIO="$TEST_TMPDIR/mkinitcpio.conf"
    printf 'HOOKS=(base udev autodetect block filesystems fsck)\n' > "$FAKE_MKINITCPIO"
    FIXTURE_ENV="$FIXTURE_ENV MKINITCPIO_CONF='$FAKE_MKINITCPIO'"
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
    run bash -c "$FIXTURE_ENV bash '$INSTALL_DIR/bootstrap.sh' --dry-run --skip-dotfiles --groups core,dev 2>&1"
    [[ "$output" == *"core,dev"* ]]
}

@test "default group list is core,dev,desktop,fonts,apps,laptop" {
    setup_fixture
    run bash -c "$FIXTURE_ENV bash '$INSTALL_DIR/bootstrap.sh' --dry-run --skip-dotfiles 2>&1"
    [[ "$output" == *"core,dev,desktop,fonts,apps,laptop"* ]]
}

# Every path, its type, link target and content, so a moved, relinked or
# rewritten file all change the snapshot -- a bare file count does not see a
# file replaced by a symlink.
_snapshot() {
    (cd "$1" && find . -printf '%p %y %l\n' | sort
     find . -type f -exec md5sum {} + | sort) | md5sum
}

@test "--dry-run changes nothing on disk" {
    setup_fixture
    # Give the dotfiles phase real work: an existing checkout with a package
    # and a colliding file in $HOME. With an empty $HOME it found no packages
    # and the test passed even with `run mv` and `run stow` made real.
    local repo="$FAKE_HOME/.dotfiles"
    mkdir -p "$repo/home"
    echo "from repo" > "$repo/home/.zshrc"
    git -C "$repo" init -q
    git -C "$repo" add -A
    git -C "$repo" -c user.email=t@t -c user.name=t commit -qm init
    echo "the user's own" > "$FAKE_HOME/.zshrc"
    # A second repo with nothing colliding. The first repo's collision makes
    # a real stow abort without linking anything, so on its own it could not
    # tell a dry run from a stow that actually ran; this one would link.
    local nvim="$FAKE_HOME/.nvim-config"
    mkdir -p "$nvim/nvim-config/.config/nvim"
    echo "-- repo" > "$nvim/nvim-config/.config/nvim/init.lua"
    git -C "$nvim" init -q
    git -C "$nvim" add -A
    git -C "$nvim" -c user.email=t@t -c user.name=t commit -qm init
    before="$(_snapshot "$FAKE_HOME")"
    entries_before="$(_snapshot "$FAKE_ENTRIES")"
    run bash -c "$FIXTURE_ENV bash '$INSTALL_DIR/bootstrap.sh' --dry-run 2>&1"
    [ "$status" -eq 0 ]
    # Prove the phase had something to do, or the snapshot proves nothing.
    [[ "$output" == *"backing up existing $FAKE_HOME/.zshrc"* ]]
    [ "$before" = "$(_snapshot "$FAKE_HOME")" ]
    [ "$entries_before" = "$(_snapshot "$FAKE_ENTRIES")" ]
}

@test "preflight fails when not on Arch" {
    setup_fixture
    run bash -c "$FIXTURE_ENV BOOTSTRAP_ARCH_RELEASE='/nonexistent' bash '$INSTALL_DIR/bootstrap.sh' --dry-run 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Arch"* ]]
}

@test "preflight refuses to run as root" {
    setup_fixture
    run bash -c "$FIXTURE_ENV BOOTSTRAP_FAKE_EUID=0 bash '$INSTALL_DIR/bootstrap.sh' --dry-run 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" == *"root"* ]]
}

@test "BOOTSTRAP_SKIP_NETCHECK=1 skips the network probe" {
    setup_fixture
    # A curl that always fails stands in for being offline.
    mkdir -p "$TEST_TMPDIR/bin"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$TEST_TMPDIR/bin/curl"
    chmod +x "$TEST_TMPDIR/bin/curl"
    run bash -c "PATH='$TEST_TMPDIR/bin:$PATH' $FIXTURE_ENV bash '$INSTALL_DIR/bootstrap.sh' --dry-run --skip-dotfiles 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" != *"no network connectivity"* ]]
}

@test "the seam is off by default, so a real run still probes" {
    setup_fixture
    mkdir -p "$TEST_TMPDIR/bin"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$TEST_TMPDIR/bin/curl"
    chmod +x "$TEST_TMPDIR/bin/curl"
    run bash -c "PATH='$TEST_TMPDIR/bin:$PATH' HOME='$FAKE_HOME' BOOTSTRAP_PACMAN_CONF='$FAKE_PACMAN_CONF' BOOTCTL_ENTRIES_DIR='$FAKE_ENTRIES' bash '$INSTALL_DIR/bootstrap.sh' --dry-run --skip-dotfiles 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" == *"no network connectivity"* ]]
}

@test "dry-run names every phase it would run, and nothing else" {
    setup_fixture
    run bash -c "$FIXTURE_ENV bash '$INSTALL_DIR/bootstrap.sh' --dry-run 2>&1"
    [ "$status" -eq 0 ]
    # log_step also announces per-file package work ("core.txt: installing 3
    # of 40") and the clone/stow steps; the phase banners are the bare names.
    phases="$(printf '%s\n' "$output" | sed -n 's/^::  //p' \
        | grep -v ':' | grep -vE '^(cloning|updating|stowing)')"
    # Equality, not a subset: a phase dropped from main() has to fail this.
    [ "$phases" = "preflight
pacman.conf
microcode
paru
packages
dotfiles
shell
services
version managers
report" ]
}

@test "pacman.conf phase enables multilib when it is commented out" {
    setup_fixture
    printf '#[multilib]\n#Include = /etc/pacman.d/mirrorlist\n' > "$FAKE_PACMAN_CONF"
    before="$(cat "$FAKE_PACMAN_CONF")"
    run bash -c "$FIXTURE_ENV bash '$INSTALL_DIR/bootstrap.sh' --dry-run --skip-dotfiles 2>&1"
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
}

@test "pacman.conf phase is a no-op when multilib is already enabled" {
    setup_fixture
    before="$(cat "$FAKE_PACMAN_CONF")"
    run bash -c "$FIXTURE_ENV bash '$INSTALL_DIR/bootstrap.sh' --dry-run --skip-dotfiles 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"multilib already enabled"* ]]
    [[ "$output" != *"sed -i"* ]]
    # Byte-identical: DRY_RUN guarantees it, and there was nothing to change anyway.
    [ "$(cat "$FAKE_PACMAN_CONF")" = "$before" ]
}

@test "an unknown group name is rejected before anything is installed" {
    setup_fixture
    run bash -c "$FIXTURE_ENV bash '$INSTALL_DIR/bootstrap.sh' --dry-run --groups nosuchgroup 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" == *"nosuchgroup"* ]]
    [[ "$output" != *"DRY-RUN:"* ]]
}

@test "--skip-dotfiles omits the dotfiles phase" {
    setup_fixture
    run bash -c "$FIXTURE_ENV bash '$INSTALL_DIR/bootstrap.sh' --dry-run --skip-dotfiles 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"skipping dotfiles"* ]]
    [[ "$output" != *"::  dotfiles"* ]]
}

@test "aur.txt follows the apps group instead of running unconditionally" {
    setup_fixture
    run bash -c "$FIXTURE_ENV bash '$INSTALL_DIR/bootstrap.sh' --dry-run --skip-dotfiles --groups apps 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" != *"skipping aur.txt"* ]]
    [[ "$output" == *"aur.txt"* ]]
    run bash -c "$FIXTURE_ENV bash '$INSTALL_DIR/bootstrap.sh' --dry-run --skip-dotfiles --groups server 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"apps not selected; skipping aur.txt"* ]]
    # A server run must not offer to install the desktop browsers.
    [[ "$output" != *"brave-bin"* ]]
}

@test "the report's optional-group list matches packages/optional/ exactly" {
    setup_fixture
    run bash -c "$FIXTURE_ENV bash '$INSTALL_DIR/bootstrap.sh' --dry-run --skip-dotfiles 2>&1"
    [ "$status" -eq 0 ]
    listed="$(printf '%s\n' "$output" | sed -n 's#^ *install/bootstrap.sh --groups ##p')"
    expected="$(cd "$INSTALL_DIR/packages/optional" && ls ./*.txt | sed -e 's#^\./##' -e 's/\.txt$//' | paste -sd,)"
    [ "$listed" = "$expected" ]
}

# The VM run died twice inside phase_shell: chsh authenticates, and under
# set -e its failure took phase_services, phase_version_managers and
# phase_report with it. --dry-run cannot catch this, because run() executes
# nothing under DRY_RUN, so the guard needs a real invocation to test.
@test "a failing chsh warns and lets the rest of the run continue" {
    setup_fixture
    mkdir -p "$TEST_TMPDIR/bin"
    printf '#!/bin/sh\necho "chsh: Authentication token manipulation error" >&2\nexit 1\n' \
        > "$TEST_TMPDIR/bin/chsh"
    # This developer's own login shell is already zsh, so the phase would
    # return before ever reaching chsh. Report bash, the state a fresh
    # archinstall machine is actually in.
    printf '#!/bin/sh\necho "%s:x:1000:1000::/home/%s:/usr/bin/bash"\n' "$USER" "$USER" \
        > "$TEST_TMPDIR/bin/getent"
    chmod +x "$TEST_TMPDIR/bin/chsh" "$TEST_TMPDIR/bin/getent"
    run bash -c "PATH='$TEST_TMPDIR/bin:$PATH' HOME='$FAKE_HOME' \
        bash -c \"source '$INSTALL_DIR/bootstrap.sh'; DRY_RUN=0; phase_shell; echo PHASE_RETURNED=\\\$?\" 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"PHASE_RETURNED=0"* ]]
    [[ "$output" == *"chsh failed"* ]]
}

@test "sourcing bootstrap.sh defines the phases without running them" {
    setup_fixture
    run bash -c "HOME='$FAKE_HOME' bash -c \"source '$INSTALL_DIR/bootstrap.sh'; \
        declare -F phase_shell phase_services phase_report >/dev/null && echo DEFINED\" 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"DEFINED"* ]]
    # Sourcing must not have executed a phase.
    [[ "$output" != *"::  preflight"* ]]
}

@test "an interrupt ends the run with a message instead of dying silently" {
    # A terminal Ctrl-C signals the whole foreground process group, so the
    # script itself takes SIGINT -- no `|| rc=$?` downstream ever sees it and
    # the run ends with no output at all. The trap makes the exit deliberate.
    run bash -c "
        cd '$BATS_TEST_DIRNAME/../..'
        source install/bootstrap.sh
        kill -INT \$\$
        echo SHOULD-NOT-REACH
    "
    [ "$status" -eq 130 ]
    [[ "$output" == *"interrupted"* ]]
    [[ "$output" != *"SHOULD-NOT-REACH"* ]]
}

@test "a failed system upgrade warns, continues, and is named in the report" {
    # set -e used to end the run here, at phase 2 of 10, with no error line
    # and nothing to say which of the eight later phases never happened.
    printf '#[multilib]\n#Include = /etc/pacman.d/mirrorlist\n#Color\n#ParallelDownloads = 5\n' \
        > "$BATS_TEST_TMPDIR/pacman.conf"
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat > "$BATS_TEST_TMPDIR/bin/pacman" <<'STUB'
#!/usr/bin/env bash
[ "$1" = "-Syu" ] && exit 1
exit 0
STUB
    chmod +x "$BATS_TEST_TMPDIR/bin/pacman"
    run bash -c "
        cd '$BATS_TEST_DIRNAME/../..'
        PATH='$BATS_TEST_TMPDIR/bin:$PATH'
        source install/bootstrap.sh
        # main() sources the libs; sourcing bootstrap.sh alone gives only
        # log.sh, and phase_report reads PKG_FAILED out of pkg.sh.
        source install/lib/pkg.sh
        BOOTSTRAP_PACMAN_CONF='$BATS_TEST_TMPDIR/pacman.conf' phase_pacman_conf
        echo PHASE_RETURNED=\$?
        phase_report
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"PHASE_RETURNED=0"* ]]
    [[ "$output" == *"partial upgrade"* ]]
    # The report is the only place the operator learns about it afterwards.
    [[ "$output" == *"sudo pacman -Syu"* ]]
}

@test "the upgrade is retried on a run where multilib is already enabled" {
    # The retry used to live inside the "enabling multilib" branch, so a
    # second run took the "already enabled" path and never synced again --
    # leaving the just-added multilib database undownloaded and every
    # lib32-* package in the gpu groups unresolvable.
    printf '[multilib]\nInclude = /etc/pacman.d/mirrorlist\nColor\nParallelDownloads = 5\n' \
        > "$BATS_TEST_TMPDIR/pacman.conf"
    run bash -c "
        cd '$BATS_TEST_DIRNAME/../..'
        source install/bootstrap.sh
        DRY_RUN=1 BOOTSTRAP_PACMAN_CONF='$BATS_TEST_TMPDIR/pacman.conf' phase_pacman_conf
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"multilib already enabled"* ]]
    [[ "$output" == *"pacman -Syu"* ]]
}

@test "a failed nvm download is reported, not passed off as installed" {
    # curl | bash without pipefail takes bash's status, and bash exits 0 on
    # the empty script a failed curl leaves it.
    setup_fixture
    mkdir -p "$TEST_TMPDIR/bin"
    printf '#!/bin/sh\nexit 22\n' > "$TEST_TMPDIR/bin/curl"
    chmod +x "$TEST_TMPDIR/bin/curl"
    run bash -c "PATH='$TEST_TMPDIR/bin:$PATH' HOME='$FAKE_HOME'; source '$INSTALL_DIR/bootstrap.sh'
        phase_version_managers 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"the nvm installer failed"* ]]
}

@test "every detected GPU gets its driver list, and an unknown one a warning" {
    # A hybrid laptop reports two vendors; both need their packages.
    setup_fixture
    run bash -c "HOME='$FAKE_HOME'; source '$INSTALL_DIR/bootstrap.sh'
        DRY_RUN=1; PKG_GROUPS=core
        aur_install_file() { echo \"INSTALL \$(basename \"\$1\")\"; }
        hw_gpu_vendors() { printf 'intel\nnvidia\nunknown\n'; }
        phase_packages 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"INSTALL gpu-intel.txt"* ]]
    [[ "$output" == *"INSTALL gpu-nvidia.txt"* ]]
    [[ "$output" != *"INSTALL gpu-amd.txt"* ]]
    [[ "$output" == *"unrecognised GPU"* ]]
}
