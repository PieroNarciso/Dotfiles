#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# Two-way diff between explicitly installed packages and the group files.
# Exits non-zero when either side has entries the other lacks.
set -euo pipefail

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The audit compares against EXPLICITLY installed packages, not every dep.
PKG_QUERY_CMD="${PKG_QUERY_CMD:-pacman -Qqe}"
# shellcheck source=lib/log.sh
# shellcheck source=lib/log.sh
source "$INSTALL_DIR/lib/log.sh"
# shellcheck source=lib/pkg.sh
# shellcheck source=lib/pkg.sh
source "$INSTALL_DIR/lib/pkg.sh"
# shellcheck source=lib/hw.sh
source "$INSTALL_DIR/lib/hw.sh"

PKG_AUDIT_DIR="${PKG_AUDIT_DIR:-$INSTALL_DIR/packages}"

# Register the cleanup BEFORE creating anything: if the second or third
# mktemp fails, set -e aborts at that statement and a trap registered after
# it would never run, leaking the files already created.
listed=""; live=""; ignore=""; required=""
trap 'rm -f "$listed" "$live" "$ignore" "$required"' EXIT
listed="$(mktemp)"; live="$(mktemp)"; required="$(mktemp)"

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

read_lists() { # <find-expression>...
    # shellcheck disable=SC2016  # $1 is the xargs argument, expanded by the inner sh
    find "$PKG_AUDIT_DIR" "$@" \
        | xargs -0 -I{} sh -c 'sed -e "s/#.*//" -e "s/[[:space:]]//g" "$1"' _ {} \
        | { grep -v '^$' || true; } | sort -u
}

# Two different lists, because the two columns ask different questions.
#
# "unlisted" asks whether an installed package is recorded ANYWHERE, so it
# compares against every group file including the optional ones.
#
# "missing" asks what THIS machine still needs, so it counts only the groups
# that apply to it. Three kinds never do:
#   - optional/: opt-in by definition, so a machine that never asked for
#     gaming/media/virt is not missing them;
#   - the gpu-*.txt for hardware this machine does not have — they are
#     mutually exclusive, so two of the three are always absent;
#   - laptop.txt on a machine with no battery.
# Counting all of them printed ~50 expected absences and exited 1 on every
# ordinary run, which is how a check stops being read -- the same rot the
# .audit-ignore file exists to prevent.
read_lists -name '*.txt' -print0 > "$listed"

gpus="$(hw_gpu_vendors)"
audit_skip=()
for g in amd intel nvidia; do
    grep -qx "$g" <<< "$gpus" || audit_skip+=("gpu-$g.txt")
done
hw_has_battery || audit_skip+=("laptop.txt")

# Build the find expression: prune optional/, then exclude each inapplicable
# group file by name.
find_args=(-path "$PKG_AUDIT_DIR/optional" -prune -o -name '*.txt')
for f in "${audit_skip[@]}"; do
    find_args+=(! -name "$f")
done
read_lists "${find_args[@]}" -print0 > "$required"
[ "${#audit_skip[@]}" -eq 0 ] \
    || log_info "not applicable to this machine, skipped: ${audit_skip[*]}"

$PKG_QUERY_CMD 2>/dev/null | sort -u > "$live"

unlisted="$(comm -13 "$listed" "$live" | comm -23 - "$ignore")"
missing_pkgs="$(comm -23 "$required" "$live")"
status=0

if [ -n "$unlisted" ]; then
    log_warn "installed but unlisted in any group file:"
    # shellcheck disable=SC2086  # unquoted on purpose: one package per line
    printf '  %s\n' $unlisted >&2
    status=1
fi

if [ -n "$missing_pkgs" ]; then
    log_warn "listed in a group file but missing from this machine:"
    # shellcheck disable=SC2086  # unquoted on purpose: one package per line
    printf '  %s\n' $missing_pkgs >&2
    status=1
fi

[ "$status" -eq 0 ] && log_info "package groups match this machine"
exit "$status"
