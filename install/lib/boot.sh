#!/usr/bin/env bash
# systemd-boot loader entries. Requires lib/log.sh to be sourced first.
# The entries directory is overridable so the tests never touch a real /boot.

BOOTCTL_ENTRIES_DIR="${BOOTCTL_ENTRIES_DIR:-/boot/loader/entries}"

# _boot_backup_entry <entry> <backup-dir> <timestamp> [sudo]
# Never edit a loader entry without a copy of the original first. Prefers the
# run's backup directory; falls back to a sibling file and says so.
_boot_backup_entry() {
    local entry="$1" backup="$2" ts="$3" sudo_cmd="${4:-}"
    # /boot is mode 700 and root-owned on any machine stage 0 installs, so
    # reading an entry needs sudo; the copy is then chowned back so the
    # backup directory under $HOME stays owned by the user who ran bootstrap.
    # shellcheck disable=SC2086
    if [ -n "$backup" ] \
        && run mkdir -p "$backup" \
        && run $sudo_cmd cp -a "$entry" "$backup/$(basename "$entry")" \
        && run $sudo_cmd chown "$(id -un):$(id -gn)" "$backup/$(basename "$entry")"; then
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
    # Default: sudo against the real ESP, nothing against a test fixture.
    # BOOTCTL_SUDO overrides both -- tests use it to point privilege at a
    # stub, and an operator could use it to force sudo off entirely.
    local sudo_cmd probe_blocked=0
    if [ -n "${BOOTCTL_SUDO+set}" ]; then
        sudo_cmd="$BOOTCTL_SUDO"
    elif [ "$dir" = "/boot/loader/entries" ]; then
        if [ "${DRY_RUN:-0}" = "1" ]; then
            # phase_preflight deliberately skips `sudo -v` under DRY_RUN, so
            # there is no cached credential here. A bare `sudo` probe would
            # sit on a password prompt -- invisible if the operator piped the
            # dry run to a file, and a hang in the one mode whose whole
            # promise is that it changes nothing.
            sudo_cmd="sudo -n"
            sudo -n true 2>/dev/null || probe_blocked=1
        else
            sudo_cmd="sudo"
        fi
    else
        sudo_cmd=""
    fi

    # Saying so beats guessing: an unprivileged probe would report the
    # directory missing and print D4's false warning back again.
    if [ "$probe_blocked" = 1 ]; then
        log_info "dry run: reading $dir needs a sudo password; the real run will inspect it"
        return 0
    fi

    # Probes must NOT go through run(): run() skips execution under DRY_RUN
    # and a probe that does not run returns a wrong answer. /boot is mode 700
    # and root-owned on any machine stage 0 installs, so an unprivileged
    # `[ -d ... ]` here reports "missing" for a directory that is present.
    # shellcheck disable=SC2086
    if ! $sudo_cmd test -d "$dir"; then
        log_warn "no loader entry directory at $dir; $manual"
        return 0
    fi

    local -a entries=()
    local f
    # A symlinked entry would be rewritten in place by sed -i, replacing the
    # link with a plain file and leaving the real entry untouched. Warn and skip.
    # shellcheck disable=SC2086
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        log_warn "$(basename "$f") is a symlink; skipped — $manual"
    done < <($sudo_cmd find "$dir" -maxdepth 1 -name '*.conf' -type l 2>/dev/null | sort)

    # find -type f does not follow symlinks, so an entry cannot land in both
    # this list and the symlink list above.
    # shellcheck disable=SC2086
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        entries+=("$f")
    done < <($sudo_cmd find "$dir" -maxdepth 1 -name '*.conf' -type f 2>/dev/null | sort)

    if [ "${#entries[@]}" -eq 0 ]; then
        log_warn "no *.conf loader entries in $dir; $manual"
        return 0
    fi

    local ts; ts="$(date +%Y%m%d-%H%M%S)"
    local entry name
    for entry in "${entries[@]}"; do
        name="$(basename "$entry")"
        # shellcheck disable=SC2086
        if $sudo_cmd grep -qE "^initrd[[:space:]]+/$img([[:space:]]*)\$" "$entry"; then
            log_info "$name: /$img already loaded"
            continue
        fi
        # No initramfs line means this is not an ordinary systemd-boot entry
        # (a UKI stub, a rescue stanza someone hand-wrote). Guessing where the
        # microcode goes in a file we do not understand is how a machine stops
        # booting, so warn and leave it alone.
        # shellcheck disable=SC2086
        if ! $sudo_cmd grep -qE '^initrd[[:space:]]+/initramfs' "$entry"; then
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
