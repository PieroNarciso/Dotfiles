#!/usr/bin/env bash
# systemd-boot loader entries. Requires lib/log.sh to be sourced first.
# The entries directory is overridable so the tests never touch a real /boot.

BOOTCTL_ENTRIES_DIR="${BOOTCTL_ENTRIES_DIR:-/boot/loader/entries}"

# _boot_backup_entry <entry> <backup-dir> <timestamp> [sudo]
# Never edit a loader entry without a copy of the original first. Prefers the
# run's backup directory; falls back to a sibling file and says so.
_boot_backup_entry() {
    local entry="$1" backup="$2" ts="$3" sudo_cmd="${4:-}"
    # shellcheck disable=SC2086  # $sudo_cmd is empty or the single word "sudo"
    if [ -n "$backup" ] \
        && run $sudo_cmd mkdir -p "$backup" \
        && run $sudo_cmd cp -a "$entry" "$backup/$(basename "$entry")"; then
        return 0
    fi
    [ -z "$backup" ] || log_warn "cannot back up into $backup; using $entry.bak-$ts instead"
    # shellcheck disable=SC2086
    run $sudo_cmd cp -a "$entry" "$entry.bak-$ts"
}

# boot_add_microcode_initrd <ucode-image> [backup-dir]
#
# Installing amd-ucode/intel-ucode only drops the image into /boot; the CPU
# microcode is loaded only if a loader entry names it, and it must be the FIRST
# initrd line — `bootctl update` refreshes the systemd-boot binary and never
# touches the entries. Idempotent, and every mutation goes through `run`, so a
# dry run leaves the entries byte-identical.
#
# Always returns 0: a warning the user can act on beats aborting the bootstrap
# or leaving a half-edited bootloader behind.
boot_add_microcode_initrd() {
    local img="$1" backup="${2:-}"
    local dir="${BOOTCTL_ENTRIES_DIR:-/boot/loader/entries}"
    local manual="add 'initrd /$img' above the first 'initrd /initramfs...' line by hand"
    local sudo_cmd="sudo"
    # Tests point BOOTCTL_ENTRIES_DIR at a writable fixture; no sudo there.
    [ "$dir" = "/boot/loader/entries" ] || sudo_cmd=""

    if [ ! -d "$dir" ]; then
        log_warn "no loader entry directory at $dir; $manual"
        return 0
    fi

    local -a entries=()
    local f
    for f in "$dir"/*.conf; do
        [ -f "$f" ] && entries+=("$f")
    done
    if [ "${#entries[@]}" -eq 0 ]; then
        log_warn "no *.conf loader entries in $dir; $manual"
        return 0
    fi

    local ts; ts="$(date +%Y%m%d-%H%M%S)"
    local entry name
    for entry in "${entries[@]}"; do
        name="$(basename "$entry")"
        if grep -qE "^initrd[[:space:]]+/$img([[:space:]]*)\$" "$entry"; then
            log_info "$name: /$img already loaded"
            continue
        fi
        # No initramfs line means this is not an ordinary systemd-boot entry
        # (a UKI stub, a rescue stanza someone hand-wrote). Guessing where the
        # microcode goes in a file we do not understand is how a machine stops
        # booting, so warn and leave it alone.
        if ! grep -qE '^initrd[[:space:]]+/initramfs' "$entry"; then
            log_warn "$name: no 'initrd /initramfs...' line; skipped — $manual"
            continue
        fi
        if ! _boot_backup_entry "$entry" "$backup" "$ts" "$sudo_cmd"; then
            log_warn "$name: could not be backed up; left untouched — $manual"
            continue
        fi
        log_info "$name: adding 'initrd /$img' before the initramfs line"
        # 0,/re/ limits the substitution to the FIRST match: the microcode
        # image has to be the first initrd the loader hands the kernel.
        # shellcheck disable=SC2086
        if ! run $sudo_cmd sed -i \
            "0,/^initrd[[:space:]]\\+\\/initramfs/s|^initrd[[:space:]]\\+/initramfs|initrd /$img\\n&|" \
            "$entry"; then
            log_warn "$name: editing it failed; $manual"
        fi
    done
    return 0
}
