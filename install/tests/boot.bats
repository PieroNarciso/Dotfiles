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
    mkdir -p "$ENTRIES"
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
