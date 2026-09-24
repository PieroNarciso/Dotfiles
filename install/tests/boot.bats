#!/usr/bin/env bats

load test_helper

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

# Three entries, covering every shape the function has to handle: one ordinary
# entry with no microcode line, one that already has it, and one that is not a
# normal systemd-boot entry at all. BOOTCTL_ENTRIES_DIR points here, so the
# real /boot is never read or written by the suite.
setup_entries() {
    ENTRIES="$TEST_TMPDIR/entries"
    BACKUP="$TEST_TMPDIR/backup"
    # The ESP must hold the microcode image itself: boot_add_microcode_initrd
    # refuses to name an initrd that is not there.
    ESP="$TEST_TMPDIR/esp"
    mkdir -p "$ENTRIES" "$ESP"
    : > "$ESP/amd-ucode.img"
    cat > "$ENTRIES/arch.conf" <<'EOF'
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=/dev/mapper/root rw
EOF
    cat > "$ENTRIES/arch-fallback.conf" <<'EOF'
title   Arch Linux (fallback)
linux   /vmlinuz-linux
initrd  /amd-ucode.img
initrd  /initramfs-linux-fallback.img
options root=/dev/mapper/root rw
EOF
    cat > "$ENTRIES/weird.conf" <<'EOF'
title   Unified kernel image
efi     /EFI/Linux/arch-linux.efi
EOF
}

add_ucode() { # [backup-dir]
    bash -c "source '$INSTALL_DIR/lib/log.sh'
             source '$INSTALL_DIR/lib/boot.sh'
             DRY_RUN='${DRY_RUN:-0}' BOOTCTL_ENTRIES_DIR='$ENTRIES' \
                 BOOTCTL_ESP='${BOOTCTL_ESP:-$ESP}' \
                 boot_add_microcode_initrd amd-ucode.img '${1:-}' 2>&1"
}

@test "the microcode line is inserted immediately before the initramfs line" {
    setup_entries
    run add_ucode "$BACKUP"
    [ "$status" -eq 0 ]
    # Order matters: the microcode image must be the first initrd the loader
    # hands the kernel, or it is not applied.
    [ "$(sed -n '3p' "$ENTRIES/arch.conf")" = "initrd /amd-ucode.img" ]
    [ "$(sed -n '4p' "$ENTRIES/arch.conf")" = "initrd  /initramfs-linux.img" ]
    [ "$(grep -c '/amd-ucode.img' "$ENTRIES/arch.conf")" -eq 1 ]
    [ "$(wc -l < "$ENTRIES/arch.conf")" -eq 5 ]
}

@test "an entry that already names the microcode image is left byte-identical" {
    setup_entries
    before="$(md5sum < "$ENTRIES/arch-fallback.conf")"
    run add_ucode "$BACKUP"
    [ "$status" -eq 0 ]
    [ "$(md5sum < "$ENTRIES/arch-fallback.conf")" = "$before" ]
    [[ "$output" == *"arch-fallback.conf: /amd-ucode.img already loaded"* ]]
}

@test "an entry with no initramfs line is skipped with a warning" {
    setup_entries
    before="$(md5sum < "$ENTRIES/weird.conf")"
    run add_ucode "$BACKUP"
    [ "$status" -eq 0 ]
    [ "$(md5sum < "$ENTRIES/weird.conf")" = "$before" ]
    [[ "$output" == *"warn:"* ]]
    [[ "$output" == *"weird.conf"* ]]
    [[ "$output" == *"no 'initrd /initramfs...' line"* ]]
}

@test "a second run changes nothing" {
    setup_entries
    add_ucode "$BACKUP"
    before="$(cd "$ENTRIES" && md5sum ./*.conf)"
    run add_ucode "$BACKUP"
    [ "$status" -eq 0 ]
    [ "$(cd "$ENTRIES" && md5sum ./*.conf)" = "$before" ]
}

@test "every edited entry is backed up first" {
    setup_entries
    run add_ucode "$BACKUP"
    [ "$status" -eq 0 ]
    [ -f "$BACKUP/arch.conf" ]
    # The backup is the original, not the edited file.
    ! grep -q 'amd-ucode' "$BACKUP/arch.conf"
    # Entries that were not edited are not backed up.
    [ ! -f "$BACKUP/weird.conf" ]
}

@test "with no backup directory the original lands beside the entry" {
    setup_entries
    run add_ucode ""
    [ "$status" -eq 0 ]
    [ -n "$(find "$ENTRIES" -name 'arch.conf.bak-*')" ]
    grep -q '^initrd /amd-ucode.img$' "$ENTRIES/arch.conf"
}

@test "dry-run leaves every entry byte-identical and writes no backup" {
    setup_entries
    before="$(cd "$ENTRIES" && md5sum ./*.conf)"
    DRY_RUN=1 run add_ucode "$BACKUP"
    [ "$status" -eq 0 ]
    [ "$(cd "$ENTRIES" && md5sum ./*.conf)" = "$before" ]
    [ ! -d "$BACKUP" ]
    [[ "$output" == *"DRY-RUN"* ]]
}

@test "a missing entries directory warns and still returns 0" {
    ENTRIES="$TEST_TMPDIR/nonexistent"
    run add_ucode ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"warn:"* ]]
    [[ "$output" == *"no loader entry directory"* ]]
    [[ "$output" == *"by hand"* ]]
}

@test "an entries directory with no *.conf warns and still returns 0" {
    ENTRIES="$TEST_TMPDIR/entries"
    mkdir -p "$ENTRIES"
    run add_ucode ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"no *.conf loader entries"* ]]
}

# archinstall mounts the ESP dmask=0077, so /boot is mode 700 and root-owned;
# bootstrap.sh runs unprivileged. Mode 000 reproduces that precisely without
# needing real root: only root can bypass it, so an inline `[ -d "$dir" ]`
# (or a glob, or a plain grep/sed) fails exactly the way it does on the real
# ESP. BOOTCTL_SUDO points at a stub that opens the directory, runs the real
# command, and closes it again -- standing in for what sudo would do for real.
# This is the primary regression test: it needs no privilege at all, so it
# always runs, unlike the real-sudo tests below.
@test "an entries directory untraversable by its own owner is still processed" {
    local dir="$TEST_TMPDIR/esp/loader/entries"
    mkdir -p "$dir"
    cat > "$dir/arch.conf" <<'EOF'
title	Arch Linux
linux	/vmlinuz-linux
initrd	/initramfs-linux.img
options	rw
EOF
    # Order matters: chmod the child before the parent, or the second chmod
    # cannot even resolve its own path. Same order in reverse to undo it.
    chmod 000 "$dir"
    chmod 000 "$TEST_TMPDIR/esp"

    local stub="$TEST_TMPDIR/sudo-stub.sh"
    cat > "$stub" <<STUB
#!/usr/bin/env bash
chmod 755 '$TEST_TMPDIR/esp' '$dir'
"\$@"
rc=\$?
chmod 000 '$dir'
chmod 000 '$TEST_TMPDIR/esp'
exit "\$rc"
STUB
    chmod +x "$stub"

    run bash -c "
        source '$INSTALL_DIR/lib/log.sh'
        source '$INSTALL_DIR/lib/boot.sh'
        BOOTCTL_ENTRIES_DIR='$dir' BOOTCTL_SUDO='$stub' \
            boot_add_microcode_initrd amd-ucode.img '$TEST_TMPDIR/backup' 2>&1
    "
    # Clean up before any assertion can fail and skip the chmod.
    chmod 755 "$TEST_TMPDIR/esp" "$dir"

    [ "$status" -eq 0 ]
    [[ "$output" != *"no loader entry directory"* ]]
    [[ "$output" != *"no *.conf loader entries"* ]]

    # The microcode line must be first, above the initramfs line.
    local ucode_line initramfs_line
    ucode_line=$(grep -n 'amd-ucode' "$dir/arch.conf" | cut -d: -f1)
    initramfs_line=$(grep -n 'initramfs-linux.img' "$dir/arch.conf" | cut -d: -f1)
    [ -n "$ucode_line" ]
    [ -n "$initramfs_line" ]
    [ "$ucode_line" -lt "$initramfs_line" ]
}

# The real-world check: an actual root-owned mode-700 directory via real
# sudo. Skips without passwordless sudo -- this machine has none, so it is
# not the evidence for the fix, the test above is. It is kept so the
# machinery is exercised against genuine privilege whenever that is available.
@test "a root-owned mode-700 entries directory is still processed (real sudo)" {
    sudo -n true 2>/dev/null || skip "needs passwordless sudo"

    local dir="$TEST_TMPDIR/rootesp/loader/entries"
    sudo mkdir -p "$dir"
    sudo tee "$dir/arch.conf" >/dev/null <<'EOF'
title	Arch Linux
linux	/vmlinuz-linux
initrd	/initramfs-linux.img
options	rw
EOF
    sudo chmod 700 "$TEST_TMPDIR/rootesp" "$dir"
    sudo chmod 600 "$dir/arch.conf"

    run bash -c "
        source '$INSTALL_DIR/lib/log.sh'
        source '$INSTALL_DIR/lib/boot.sh'
        BOOTCTL_ENTRIES_DIR='$dir' BOOTCTL_SUDO=sudo \
            boot_add_microcode_initrd amd-ucode.img '$TEST_TMPDIR/backup' 2>&1
    "
    [ "$status" -eq 0 ]
    [[ "$output" != *"no loader entry directory"* ]]
    [[ "$output" != *"no *.conf loader entries"* ]]

    run sudo sed -n '1,10p' "$dir/arch.conf"
    [[ "$output" == *"initrd /amd-ucode.img"* ]]
    local ucode_line initramfs_line
    ucode_line=$(sudo grep -n 'amd-ucode' "$dir/arch.conf" | cut -d: -f1)
    initramfs_line=$(sudo grep -n 'initramfs-linux.img' "$dir/arch.conf" | cut -d: -f1)
    [ "$ucode_line" -lt "$initramfs_line" ]

    # The backup must exist and be owned by the invoking user, not root.
    run bash -c "ls '$TEST_TMPDIR/backup'/*/arch.conf"
    [ "$status" -eq 0 ]
    run bash -c "stat -c %U '$TEST_TMPDIR/backup'/*/arch.conf"
    [ "$output" = "$(id -un)" ]

    sudo rm -rf "$TEST_TMPDIR/rootesp"
}

@test "a root-owned entries directory is left byte-identical by a dry run (real sudo)" {
    sudo -n true 2>/dev/null || skip "needs passwordless sudo"

    local dir="$TEST_TMPDIR/rootesp2/loader/entries"
    sudo mkdir -p "$dir"
    sudo tee "$dir/arch.conf" >/dev/null <<'EOF'
title	Arch Linux
linux	/vmlinuz-linux
initrd	/initramfs-linux.img
EOF
    sudo chmod 700 "$TEST_TMPDIR/rootesp2" "$dir"
    local before
    before=$(sudo md5sum "$dir/arch.conf" | cut -d' ' -f1)

    run bash -c "
        source '$INSTALL_DIR/lib/log.sh'
        source '$INSTALL_DIR/lib/boot.sh'
        DRY_RUN=1 BOOTCTL_ENTRIES_DIR='$dir' BOOTCTL_SUDO=sudo \
            boot_add_microcode_initrd amd-ucode.img '$TEST_TMPDIR/backup2' 2>&1
    "
    [ "$status" -eq 0 ]
    local after
    after=$(sudo md5sum "$dir/arch.conf" | cut -d' ' -f1)
    [ "$before" = "$after" ]

    sudo rm -rf "$TEST_TMPDIR/rootesp2"
}

@test "a dry run never blocks on a sudo password prompt" {
    # The D4 fix moved the probes off run() so they execute under DRY_RUN --
    # which on the real ESP meant a bare `sudo test -d` with no cached
    # credential, i.e. a password prompt in the mode that promises to change
    # nothing. The VM could not catch this: the harness had
    # `Defaults:piero !authenticate`, so sudo never prompted there.
    if sudo -n true 2>/dev/null; then
        skip "passwordless sudo here; this test needs sudo to require a password"
    fi
    run timeout 10 bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/boot.sh'; \
        DRY_RUN=1 BOOTCTL_ENTRIES_DIR=/boot/loader/entries \
        boot_add_microcode_initrd amd-ucode.img '' < /dev/null 2>&1"
    # 124 is timeout's "still running" -- that is the hang this guards against.
    [ "$status" -ne 124 ]
    [ "$status" -eq 0 ]
    [[ "$output" == *"needs a sudo password"* ]]
    # And it must not print the false warning D4 existed to remove.
    [[ "$output" != *"no loader entry directory"* ]]
}

@test "the backup copy is chowned back to the invoking user" {
    # The real-sudo test that would cover ownership skips without passwordless
    # sudo, and the mode-000 fixture cannot catch it either: there the entry is
    # already owned by the test user, so the copy comes out user-owned whether
    # or not the chown runs. Deleting the chown from _boot_backup_entry left
    # the whole suite green. Observing the privileged calls through the
    # BOOTCTL_SUDO seam tests it with no root at all.
    local dir="$BATS_TEST_TMPDIR/entries" log="$BATS_TEST_TMPDIR/privileged.log"
    mkdir -p "$dir" "$BATS_TEST_TMPDIR/backup"
    printf 'title Arch\nlinux /vmlinuz-linux\ninitrd /initramfs-linux.img\n' \
        > "$dir/arch.conf"
    cat > "$BATS_TEST_TMPDIR/sudo-stub" <<STUB
#!/usr/bin/env bash
echo "\$@" >> "$log"
exec "\$@"
STUB
    chmod +x "$BATS_TEST_TMPDIR/sudo-stub"

    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/boot.sh'; \
        DRY_RUN=0 BOOTCTL_ENTRIES_DIR='$dir' BOOTCTL_SUDO='$BATS_TEST_TMPDIR/sudo-stub' \
        boot_add_microcode_initrd amd-ucode.img '$BATS_TEST_TMPDIR/backup' 2>&1"
    [ "$status" -eq 0 ]
    # The backup was taken with privilege and then handed back to the user.
    grep -q "^cp -a $dir/arch.conf " "$log"
    grep -q "^chown $(id -un):$(id -gn) $BATS_TEST_TMPDIR/backup/arch.conf$" "$log"
    [ -f "$BATS_TEST_TMPDIR/backup/arch.conf" ]
}

@test "a lookalike initrd line does not count as the microcode already loaded" {
    # The `.` in "amd-ucode.img" is an ERE any-character metacharacter, so an
    # unescaped pattern also matches "amd-ucodeXimg" -- and the entry would be
    # declared done and skipped, leaving a machine running without microcode.
    setup_entries
    cat > "$ENTRIES/arch.conf" <<'EOF'
title   Arch Linux
linux   /vmlinuz-linux
initrd  /amd-ucodeXimg
initrd  /initramfs-linux.img
options root=/dev/mapper/root rw
EOF
    run add_ucode "$BACKUP"
    [ "$status" -eq 0 ]
    [[ "$output" != *"arch.conf: /amd-ucode.img already loaded"* ]]
    grep -qx 'initrd /amd-ucode.img' "$ENTRIES/arch.conf"
}

@test "an entry is not told to load a microcode image that is not on the ESP" {
    # pacman reporting amd-ucode installed does not put the image on THIS ESP
    # (a reinstalled /boot, a second ESP, a failed post-install hook).
    # systemd-boot refuses to boot an entry naming a missing initrd, so
    # writing the line would trade a missing microcode update for a machine
    # that does not start.
    setup_entries
    rm -f "$ESP/amd-ucode.img"
    local before; before="$(cat "$ENTRIES/arch.conf")"
    run add_ucode "$BACKUP"
    [ "$status" -eq 0 ]
    [[ "$output" == *"not on the ESP"* ]]
    [ "$(cat "$ENTRIES/arch.conf")" = "$before" ]
}
