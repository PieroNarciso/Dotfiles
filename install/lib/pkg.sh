#!/usr/bin/env bash
# Package queries and installs. Requires lib/log.sh to be sourced first.

PKG_QUERY_CMD="${PKG_QUERY_CMD:-pacman -Qq}"
PKG_FAILED=()

pkg_read_list() {
    local file="$1"
    [ -f "$file" ] || die "package list not found: $file"
    sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$file" | grep -v '^$' || true
}

pkg_missing() {
    local installed
    installed="$($PKG_QUERY_CMD 2>/dev/null || true)"
    local p
    for p in "$@"; do
        grep -qxF "$p" <<< "$installed" || printf '%s\n' "$p"
    done
}

# _pkg_install_with <installer-command> <list-file>
_pkg_install_with() {
    local installer="$1" file="$2"
    local -a wanted missing
    mapfile -t wanted < <(pkg_read_list "$file")
    [ "${#wanted[@]}" -gt 0 ] || { log_info "$(basename "$file"): empty, nothing to do"; return 0; }
    mapfile -t missing < <(pkg_missing "${wanted[@]}")
    if [ "${#missing[@]}" -eq 0 ]; then
        log_info "$(basename "$file"): up to date (${#wanted[@]} packages)"
        return 0
    fi
    log_step "$(basename "$file"): installing ${#missing[@]} of ${#wanted[@]}"
    local p
    for p in "${missing[@]}"; do
        # One at a time: a single unavailable package must not abort the group.
        # shellcheck disable=SC2086  # $installer intentionally splits into multiple words
        if ! run $installer --needed --noconfirm "$p"; then
            log_warn "failed to install: $p"
            PKG_FAILED+=("$p")
        fi
    done
    return 0
}

pkg_install_file() { _pkg_install_with "sudo pacman -S" "$1"; }
aur_install_file() { _pkg_install_with "paru -S" "$1"; }
