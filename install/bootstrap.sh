#!/usr/bin/env bash
# Stage 1 of the Arch laptop setup: everything after the first login.
# See docs/superpowers/specs/2026-09-21-arch-laptop-bootstrap-design.md
set -euo pipefail

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly INSTALL_DIR
# shellcheck source=lib/log.sh
source "$INSTALL_DIR/lib/log.sh"

DRY_RUN=0
SKIP_DOTFILES=0
GROUPS="core,dev,desktop,fonts,apps,laptop"

usage() {
    cat <<'USAGE'
bootstrap.sh — set up this Arch machine from the Dotfiles repo.

Usage: bootstrap.sh [options]

Options:
  --dry-run            Print every action without changing anything.
  --groups <list>      Comma-separated package groups to install.
                       Default: core,dev,desktop,fonts,apps,laptop
                       Optional: audio-prod, gaming, virt, media, x11,
                                 server, work, mobile
  --skip-dotfiles      Do not clone or stow the dotfile repos.
  -h, --help           Show this help.
USAGE
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run)       DRY_RUN=1 ;;
            --skip-dotfiles) SKIP_DOTFILES=1 ;;
            --groups)
                [ $# -ge 2 ] || die "--groups needs a value"
                GROUPS="$2"; shift ;;
            -h|--help)       usage; exit 0 ;;
            *)               usage >&2; die "unknown option: $1" ;;
        esac
        shift
    done
    export DRY_RUN
}

main() {
    parse_args "$@"
    log_info "groups: $GROUPS"
    log_info "dry-run: $DRY_RUN, skip-dotfiles: $SKIP_DOTFILES"
}

main "$@"
