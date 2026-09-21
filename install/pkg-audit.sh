#!/usr/bin/env bash
# Two-way diff between explicitly installed packages and the group files.
# Exits non-zero when either side has entries the other lacks.
set -euo pipefail

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The audit compares against EXPLICITLY installed packages, not every dep.
PKG_QUERY_CMD="${PKG_QUERY_CMD:-pacman -Qqe}"
# shellcheck source=lib/log.sh
source "$INSTALL_DIR/lib/log.sh"
# shellcheck source=lib/pkg.sh
source "$INSTALL_DIR/lib/pkg.sh"

PKG_AUDIT_DIR="${PKG_AUDIT_DIR:-$INSTALL_DIR/packages}"

# Register the cleanup BEFORE creating anything: if the second or third
# mktemp fails, set -e aborts at that statement and a trap registered after
# it would never run, leaking the files already created.
listed=""; live=""; ignore=""
trap 'rm -f "$listed" "$live" "$ignore"' EXIT
listed="$(mktemp)"; live="$(mktemp)"

# Packages deliberately outside every group (installed by a phase, or
# dropped on purpose). Without this the audit exits 1 on every run here
# and stops being read — the exact rot it exists to prevent.
ignore="$(mktemp)"
if [ -f "$PKG_AUDIT_DIR/.audit-ignore" ]; then
    # `grep -v` exits 1 when everything is filtered out, and pipefail would
    # promote that to the script's status and kill the run silently.
    sed -e 's/#.*//' -e 's/[[:space:]]//g' "$PKG_AUDIT_DIR/.audit-ignore" \
        | { grep -v '^$' || true; } | sort -u > "$ignore"
fi

find "$PKG_AUDIT_DIR" -name '*.txt' -print0 \
    | xargs -0 -I{} sh -c 'sed -e "s/#.*//" -e "s/[[:space:]]//g" "$1"' _ {} \
    | { grep -v '^$' || true; } | sort -u > "$listed"

$PKG_QUERY_CMD 2>/dev/null | sort -u > "$live"

unlisted="$(comm -13 "$listed" "$live" | comm -23 - "$ignore")"
missing="$(comm -23 "$listed" "$live")"
status=0

if [ -n "$unlisted" ]; then
    log_warn "installed but unlisted in any group file:"
    printf '  %s\n' $unlisted >&2
    status=1
fi

if [ -n "$missing" ]; then
    log_warn "listed in a group file but missing from this machine:"
    printf '  %s\n' $missing >&2
    status=1
fi

[ "$status" -eq 0 ] && log_info "package groups match this machine"
exit "$status"
