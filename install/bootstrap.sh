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
# NOTE: not GROUPS — that is a bash special variable and assignments to it
# are silently ignored.
PKG_GROUPS="core,dev,desktop,fonts,apps,laptop"

readonly DOTFILES_URL="https://github.com/PieroNarciso/Dotfiles.git"
readonly DOTFILES_DIR="$HOME/.dotfiles"
readonly NVIM_URL="https://github.com/PieroNarciso/nvim-config.git"
readonly NVIM_DIR="$HOME/.nvim-config"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

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
                PKG_GROUPS="$2"; shift ;;
            -h|--help)       usage; exit 0 ;;
            *)               usage >&2; die "unknown option: $1" ;;
        esac
        shift
    done
    export DRY_RUN
}

phase_preflight() {
    log_step "preflight"
    [ -f "${BOOTSTRAP_ARCH_RELEASE:-/etc/arch-release}" ] || die "this is not Arch Linux"
    [ "${BOOTSTRAP_FAKE_EUID:-$EUID}" -ne 0 ] || die "do not run as root; it uses sudo where needed"
    command -v sudo >/dev/null || die "sudo is not installed"
    # Validate the group names before touching the system, and before the
    # network probe — an unknown group offline should fail with the group
    # error, not a misleading network error.
    local g
    local -a groups
    IFS=',' read -ra groups <<< "$PKG_GROUPS"
    for g in "${groups[@]}"; do
        [ -f "$INSTALL_DIR/packages/$g.txt" ] || [ -f "$INSTALL_DIR/packages/optional/$g.txt" ] \
            || die "unknown package group: $g"
    done
    curl -fsS --max-time 5 https://archlinux.org/ -o /dev/null || die "no network connectivity"
    [ "$DRY_RUN" = "1" ] || sudo -v
}

phase_microcode() {
    log_step "microcode"
    local ucode; ucode="$(hw_microcode_package)"
    if [ -z "$ucode" ]; then
        log_warn "unrecognised CPU vendor; install the microcode package by hand"
        return 0
    fi
    if [ -z "$(pkg_missing "$ucode")" ]; then
        log_info "$ucode already installed"
        return 0
    fi
    run sudo pacman -S --needed --noconfirm "$ucode"
    run sudo bootctl update || log_warn "bootctl update failed; check the boot entry by hand"
}

phase_pacman_conf() {
    log_step "pacman.conf"
    local conf="${BOOTSTRAP_PACMAN_CONF:-/etc/pacman.conf}"
    local sudo_cmd="sudo"
    # Tests point BOOTSTRAP_PACMAN_CONF at a writable fixture; no sudo there.
    [ "$conf" = "/etc/pacman.conf" ] || sudo_cmd=""
    if grep -q '^\[multilib\]' "$conf"; then
        log_info "multilib already enabled"
    else
        # lib32-* packages (vulkan, pipewire, nvidia-utils) live in multilib,
        # and archinstall does not enable it.
        log_info "enabling multilib in $conf"
        run $sudo_cmd sed -i 's/^#\[multilib\]/[multilib]/; /^\[multilib\]/{n;s/^#Include/Include/}' "$conf"
        run $sudo_cmd pacman -Syu --noconfirm
    fi
    grep -q '^Color' "$conf" || run $sudo_cmd sed -i 's/^#Color/Color/' "$conf"
    grep -q '^ParallelDownloads' "$conf" || run $sudo_cmd sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 5/' "$conf"
}

phase_paru() {
    log_step "paru"
    if command -v paru >/dev/null; then log_info "paru already present"; return 0; fi
    if [ "${DRY_RUN:-0}" = "1" ]; then
        log_info "DRY-RUN: would install base-devel, clone paru from the AUR and makepkg -si"
        return 0
    fi
    run sudo pacman -S --needed --noconfirm base-devel git
    local tmp; tmp="$(mktemp -d)"
    run git clone https://aur.archlinux.org/paru.git "$tmp/paru"
    ( cd "$tmp/paru" && run makepkg -si --noconfirm )
    run rm -rf "$tmp"
}

phase_packages() {
    log_step "packages"
    # Everything goes through paru, which resolves repo and AUR packages
    # alike. Several optional groups (mobile, work, media) contain AUR-only
    # packages, so a pacman-only path would fail every one of them.
    local g file
    local -a groups
    IFS=',' read -ra groups <<< "$PKG_GROUPS"
    for g in "${groups[@]}"; do
        file="$INSTALL_DIR/packages/$g.txt"
        [ -f "$file" ] || file="$INSTALL_DIR/packages/optional/$g.txt"
        aur_install_file "$file"
    done
    local gpu; gpu="$(hw_gpu_vendor)"
    if [ -f "$INSTALL_DIR/packages/gpu-$gpu.txt" ]; then
        log_info "gpu detected: $gpu"
        aur_install_file "$INSTALL_DIR/packages/gpu-$gpu.txt"
    else
        log_warn "unrecognised GPU; install the driver by hand"
    fi
    aur_install_file "$INSTALL_DIR/packages/aur.txt"
}

phase_dotfiles() {
    [ "$SKIP_DOTFILES" = "1" ] && { log_info "skipping dotfiles"; return 0; }
    log_step "dotfiles"
    df_clone_or_pull "$DOTFILES_URL" "$DOTFILES_DIR"
    df_clone_or_pull "$NVIM_URL" "$NVIM_DIR"
    df_backup_conflicts "$DOTFILES_DIR" "$HOME" "$BACKUP_DIR"
    df_backup_conflicts "$NVIM_DIR" "$HOME" "$BACKUP_DIR"
    df_stow_repo "$DOTFILES_DIR" "$HOME"
    df_stow_repo "$NVIM_DIR" "$HOME"
    [ -d "$BACKUP_DIR" ] && log_warn "pre-existing files were moved to $BACKUP_DIR"
    return 0
}

phase_shell() {
    log_step "shell"
    local want="/usr/bin/zsh"
    # An unguarded assignment here would kill the whole bootstrap under set -e
    # if the user is not resolvable through NSS.
    local current=""
    current="$(getent passwd "$USER" | cut -d: -f7)" \
        || { log_warn "cannot read the passwd entry for $USER; skipping chsh"; return 0; }
    if [ "$current" = "$want" ]; then log_info "login shell already zsh"; return 0; fi
    [ -x "$want" ] || { log_warn "zsh not installed; skipping chsh"; return 0; }
    grep -qxF "$want" /etc/shells || { log_warn "$want is not listed in /etc/shells; skipping chsh"; return 0; }
    run chsh -s "$want"
}

phase_services() {
    log_step "services"
    local -a services=(NetworkManager)
    command -v bluetoothctl >/dev/null && services+=(bluetooth)
    if hw_has_battery; then
        services+=(tlp thermald)
        if [ -z "$(pkg_missing power-profiles-daemon)" ]; then
            log_warn "power-profiles-daemon conflicts with tlp; remove it: sudo pacman -Rns power-profiles-daemon"
        fi
    fi
    local s
    for s in "${services[@]}"; do
        systemctl list-unit-files "$s.service" >/dev/null 2>&1 || { log_warn "no unit: $s"; continue; }
        run sudo systemctl enable --now "$s.service"
    done
}

phase_version_managers() {
    log_step "version managers"
    if [ -d "$HOME/.nvm" ]; then
        log_info "nvm already installed"
    else
        run bash -c 'curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash'
    fi
    if [ -d "$HOME/.pyenv" ]; then
        log_info "pyenv already installed"
    elif command -v pyenv >/dev/null; then
        log_info "pyenv installed from the repos"
    else
        log_warn "pyenv missing; it ships in the dev group"
    fi
}

phase_report() {
    log_step "report"
    if [ "${#PKG_FAILED[@]}" -gt 0 ]; then
        log_warn "packages that failed to install: ${PKG_FAILED[*]}"
    fi
    cat >&2 <<'MANUAL'

Remaining manual steps — none of these can be automated safely:

  1. Copy your SSH keys to ~/.ssh, then switch both repos to SSH remotes:
       git -C ~/.dotfiles remote set-url origin git@github.com:PieroNarciso/Dotfiles.git
       git -C ~/.nvim-config remote set-url origin git@github.com:PieroNarciso/nvim-config.git
  2. Import your GPG key, then check: git config --global user.signingkey
  3. Copy ~/.aws, ~/.gitconfig-bsale and ~/.gitconfig-pws from the desktop.
  4. Authenticate the CLIs: gh auth login, aws configure, gcloud init.
  5. Open neovim once and let the plugin manager install everything.
  6. Install any optional group you skipped:
       install/bootstrap.sh --groups audio-prod,gaming,virt,media,x11,work,mobile

MANUAL
}

main() {
    parse_args "$@"
    # shellcheck source=lib/hw.sh
    source "$INSTALL_DIR/lib/hw.sh"
    # shellcheck source=lib/pkg.sh
    source "$INSTALL_DIR/lib/pkg.sh"
    # shellcheck source=lib/dotfiles.sh
    source "$INSTALL_DIR/lib/dotfiles.sh"

    log_info "groups: $PKG_GROUPS"
    phase_preflight
    phase_pacman_conf
    phase_microcode
    phase_paru
    phase_packages
    phase_dotfiles
    phase_shell
    phase_services
    phase_version_managers
    phase_report
    log_info "done"
}

main "$@"
