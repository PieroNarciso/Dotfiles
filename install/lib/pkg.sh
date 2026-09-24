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
    _pkg_install_batch "$installer" "${missing[@]}"
    return 0
}

# _pkg_install_batch <installer-command> <package>...
#
# Tries the whole batch as one transaction first, so pacman sees every
# explicit target while it resolves virtual dependencies (a package earlier
# in a group must not make pacman pick a default provider that a package
# later in the same group then conflicts with). If the transaction fails,
# bisect: split the batch in half and retry each half. This isolates a
# genuinely bad package (the guarantee the old one-at-a-time loop existed
# for) without falling all the way to singleton installs when the failure
# has nothing to do with any one package -- a group-wide failure caused by
# one unrelated bad name must not silently strip every other package's
# sibling context and reintroduce the provider bug for them too.
_pkg_install_batch() {
    local installer="$1"; shift
    local -a pkgs=("$@")
    [ "${#pkgs[@]}" -eq 0 ] && return 0
    # shellcheck disable=SC2086  # $installer intentionally splits into multiple words
    if run $installer --needed --noconfirm "${pkgs[@]}"; then
        return 0
    fi
    if [ "${#pkgs[@]}" -eq 1 ]; then
        log_warn "failed to install: ${pkgs[0]}"
        PKG_FAILED+=("${pkgs[0]}")
        return 0
    fi
    log_warn "batch of ${#pkgs[@]} packages failed as a unit; narrowing down"
    local mid=$(( ${#pkgs[@]} / 2 ))
    _pkg_install_batch "$installer" "${pkgs[@]:0:mid}"
    _pkg_install_batch "$installer" "${pkgs[@]:mid}"
}

# Everything installs through paru, which resolves repo and AUR packages
# alike, so there is no pacman-only entry point.
aur_install_file() { _pkg_install_with "paru -S" "$1"; }
