#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# Stage 1 of the Arch laptop setup: everything after the first login.
# See docs/superpowers/specs/2026-09-21-arch-laptop-bootstrap-design.md
set -euo pipefail

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly INSTALL_DIR
# shellcheck source=lib/log.sh
source "$INSTALL_DIR/lib/log.sh"

# Ctrl-C at a package prompt sends SIGINT to the whole foreground process
# group, so this script dies too -- before any `|| rc=$?` can record it and
# before phase_report runs. Without this trap the run ends with no output at
# all and no way to tell an interrupt from a crash.
_on_interrupt() {
    trap - INT TERM
    log_warn "interrupted — stopping here"
    log_warn "nothing is left half-written; re-run this script to continue"
    exit 130
}
trap _on_interrupt INT TERM

# Things the run could not do that the operator must. phase_report prints it.
BOOTSTRAP_MANUAL=()

DRY_RUN=0
SKIP_DOTFILES=0
# NOTE: not GROUPS — that is a bash special variable and assignments to it
# are silently ignored.
PKG_GROUPS="core,dev,desktop,fonts,apps,laptop"
# 1 once --groups is passed: an explicit group list is a request to honor, so
# the battery gate on the laptop group does not apply to it.
PKG_GROUPS_EXPLICIT=0

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
                       (the laptop group is skipped automatically on a machine
                       with no battery, e.g. the desktop; name it on --groups
                       to force it)
                       Optional: audio-prod, gaming, media, mobile, server,
                                 virt, work, x11
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
                PKG_GROUPS="$2"; PKG_GROUPS_EXPLICIT=1; shift ;;
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
    # The probe is the one preflight check with no override, which is why the
    # script-level tests all needed live network. Default off: a real run still
    # probes.
    if [ "${BOOTSTRAP_SKIP_NETCHECK:-0}" = "1" ]; then
        log_info "BOOTSTRAP_SKIP_NETCHECK=1: skipping the network probe"
    else
        curl -fsS --max-time 5 https://archlinux.org/ -o /dev/null || die "no network connectivity"
    fi
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
    elif ! run sudo pacman -S --needed --noconfirm "$ucode"; then
        # Return, do not fall through: boot_add_microcode_initrd would add
        # `initrd /$ucode.img` for an image that was never installed, and
        # systemd-boot fails to boot an entry naming a missing initrd. A
        # missing microcode update is survivable; an unbootable machine is not.
        log_warn "could not install $ucode; leaving the loader entries alone"
        return 0
    else
        # bootctl update exits 1 when the installed loader is already current,
        # which is the normal case and not a failure. It is not load-bearing
        # for microcode either -- it refreshes the systemd-boot binary and
        # never touches loader entries, which is what
        # boot_add_microcode_initrd is for.
        local bootctl_out
        if bootctl_out="$(run sudo bootctl update 2>&1)"; then
            [ -z "$bootctl_out" ] || log_info "$bootctl_out"
        elif [[ "$bootctl_out" == *"same boot loader version in place already"* ]]; then
            log_info "systemd-boot already current"
        else
            log_warn "bootctl update failed; check the boot entry by hand"
            log_warn "$bootctl_out"
        fi
    fi
    # The package is still worth having with the hook: its files trigger an
    # initramfs rebuild, and that rebuild is what embeds the microcode. The
    # loader entries are then left alone -- a second, separate initrd line
    # would load the same update twice, and editing the bootloader is the one
    # step in this script that can leave a machine unbootable.
    if boot_initramfs_has_microcode; then
        log_info "mkinitcpio's microcode hook already loads $ucode early; loader entries left alone"
        return 0
    fi
    # Without the hook, installing the package only drops the image into
    # /boot. The microcode is loaded only when a loader entry names it, and `bootctl update` refreshes
    # the systemd-boot binary without ever touching the entries — so this runs
    # on the already-installed path too: a machine that has the package and no
    # initrd line is exactly the broken case worth fixing.
    # Only edit loader entries on a machine archinstall installed. The desktop
    # was built another way: its board firmware carries newer microcode than
    # amd-ucode, and the decision there is to leave its entries alone. A machine
    # we did not install is one whose bootloader we do not own.
    if ! boot_machine_archinstalled; then
        log_info "this machine was not installed by archinstall; leaving the loader entries alone"
        BOOTSTRAP_MANUAL+=("microcode: this machine was not installed by archinstall, so its loader entries were left alone; if $ucode should load from a loader entry, add 'initrd /$ucode.img' above the first 'initrd /initramfs...' line by hand")
        return 0
    fi
    boot_add_microcode_initrd "$ucode.img" "$BACKUP_DIR/loader-entries"
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
    fi

    # Outside the branch above, deliberately. Enabling multilib adds a repo
    # whose database has never been downloaded, and a FAILED upgrade has to be
    # retried on the next run -- if this sat in the else, a re-run would take
    # the "already enabled" path and never sync again, leaving every lib32-*
    # in the gpu-*.txt groups unresolvable.
    #
    # Warn rather than abort: this is phase 2 of 10 and set -e would end the
    # run with no error line and no report of what never happened.
    if ! run $sudo_cmd pacman -Syu --noconfirm; then
        log_warn "pacman -Syu failed"
        # The dangerous half is a sync that SUCCEEDED before the upgrade did:
        # fresh databases on an un-upgraded system, and the ~300 packages the
        # next phase installs are then built against libraries this machine
        # does not have. That is a partial upgrade, and it breaks Arch.
        log_warn "do NOT ignore this: installing packages now risks a partial upgrade"
        log_warn "fix it first, in another terminal or after this run: sudo pacman -Syu"
        BOOTSTRAP_MANUAL+=("run 'sudo pacman -Syu' — the upgrade during bootstrap failed, and packages installed after it may be built against libraries this system does not have")
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
    # Every step here can fail on a fresh machine (no network yet, an AUR
    # outage, a makepkg dependency problem) and each one used to abort the
    # whole run under set -e -- losing dotfiles, shell, services and the
    # manual-steps report, none of which need paru.
    local manual="install paru by hand: https://github.com/Morganamilo/paru"
    if ! run sudo pacman -S --needed --noconfirm base-devel git; then
        log_warn "could not install base-devel; $manual"
        return 0
    fi
    local tmp; tmp="$(mktemp -d)"
    if ! run git clone https://aur.archlinux.org/paru.git "$tmp/paru"; then
        log_warn "could not clone paru from the AUR; $manual"
        run rm -rf "$tmp"
        return 0
    fi
    if ! ( cd "$tmp/paru" && run makepkg -si --noconfirm ); then
        log_warn "building paru failed; $manual"
    fi
    run rm -rf "$tmp"
    return 0
}

phase_packages() {
    log_step "packages"
    # phase_paru now warns instead of aborting, so paru can legitimately be
    # missing here. Without this, every package in every group would be
    # attempted, bisected and recorded as failed -- hundreds of lines of
    # "command not found" hiding the one fact that matters.
    if [ "$DRY_RUN" != "1" ] && ! command -v paru >/dev/null; then
        log_warn "paru is not installed; skipping all package groups"
        log_warn "install paru, then re-run: install/bootstrap.sh"
        return 0
    fi
    # Everything goes through paru, which resolves repo and AUR packages
    # alike. Several optional groups (mobile, work, media) contain AUR-only
    # packages, so a pacman-only path would fail every one of them.
    local g file
    local -a groups
    IFS=',' read -ra groups <<< "$PKG_GROUPS"
    for g in "${groups[@]}"; do
        # laptop.txt is tlp, thermald and other battery hardware support. It is
        # in the default groups so a laptop needs no --groups, but on a machine
        # with no battery (the desktop) it is dead weight -- the same reason
        # phase_services gates the tlp/thermald enable on a battery. Skip it
        # there -- unless the user named the groups explicitly on --groups, in
        # which case laptop was asked for and is installed regardless.
        if [ "$g" = "laptop" ] && ! hw_has_battery && [ "$PKG_GROUPS_EXPLICIT" != "1" ]; then
            log_info "no battery detected; skipping the laptop package group (pass --groups ...,laptop to force it)"
            continue
        fi
        file="$INSTALL_DIR/packages/$g.txt"
        [ -f "$file" ] || file="$INSTALL_DIR/packages/optional/$g.txt"
        aur_install_file "$file"
    done
    local gpu
    while IFS= read -r gpu; do
        if [ -f "$INSTALL_DIR/packages/gpu-$gpu.txt" ]; then
            log_info "gpu detected: $gpu"
            aur_install_file "$INSTALL_DIR/packages/gpu-$gpu.txt"
        else
            log_warn "unrecognised GPU; install the driver by hand"
        fi
    done < <(hw_gpu_vendors)
    # aur.txt is desktop applications — browsers and an editor. Running it
    # unconditionally meant `--groups server` still pulled in Brave, Code and
    # zen-browser, so it follows the apps group.
    if [[ ",$PKG_GROUPS," == *",apps,"* ]]; then
        aur_install_file "$INSTALL_DIR/packages/aur.txt"
    else
        log_info "apps not selected; skipping aur.txt"
    fi
}

phase_dotfiles() {
    [ "$SKIP_DOTFILES" = "1" ] && { log_info "skipping dotfiles"; return 0; }
    log_step "dotfiles"
    local -a repos=()
    local pair url dir
    for pair in "$DOTFILES_URL|$DOTFILES_DIR" "$NVIM_URL|$NVIM_DIR"; do
        url="${pair%%|*}"; dir="${pair#*|}"
        df_clone_or_pull "$url" "$dir" \
            || BOOTSTRAP_MANUAL+=("get $dir up to date, then re-run this script: git -C $dir status")
        # A failed pull leaves a usable checkout; a failed clone leaves none.
        # A dry run clones nothing either, so it has nothing to link.
        if [ -d "$dir/.git" ]; then repos+=("$dir"); fi
    done
    # stow comes from paru (core.txt). If paru never built it, moving files
    # aside for a stow that will fail with "command not found" only takes the
    # user's data out of the way for links that never get made. A dry run is
    # exempt -- it moves nothing (run() is a no-op) and its conflict report is
    # still useful -- so this guards the real run only.
    if [ "$DRY_RUN" != "1" ] && ! df_stow_available; then
        log_warn "stow is not installed; skipping the dotfile backup and linking"
        log_warn "without it, files would be moved aside for links that never get made"
        BOOTSTRAP_MANUAL+=("install stow (it is a paru package), then re-run this script to back up conflicts and link the dotfiles")
        return 0
    fi
    for dir in "${repos[@]}"; do df_backup_conflicts "$dir" "$HOME" "$BACKUP_DIR"; done
    for dir in "${repos[@]}"; do df_stow_repo "$dir" "$HOME"; done
    # Count, not `[ -d "$BACKUP_DIR" ]`: phase_microcode backs loader entries
    # into the same directory and runs first, so on a fresh laptop the
    # directory exists with nothing of the user's in it.
    if [ "$DF_BACKED_UP" -gt 0 ]; then
        if [ "$DRY_RUN" = "1" ]; then
            log_warn "$DF_BACKED_UP pre-existing file(s) would be moved to $BACKUP_DIR"
        else
            log_warn "$DF_BACKED_UP pre-existing file(s) were moved to $BACKUP_DIR"
        fi
    fi
    return 0
}

phase_shell() {
    log_step "shell"
    # The zsh path and the shells file are overridable so the tests can point
    # them at fixtures instead of the machine's real /usr/bin/zsh and
    # /etc/shells.
    local want="${BOOTSTRAP_ZSH:-/usr/bin/zsh}"
    local shells="${BOOTSTRAP_SHELLS:-/etc/shells}"
    # An unguarded assignment here would kill the whole bootstrap under set -e
    # if the user is not resolvable through NSS.
    local current=""
    current="$(getent passwd "$USER" | cut -d: -f7)" \
        || { log_warn "cannot read the passwd entry for $USER; skipping chsh"; return 0; }
    if [ "$current" = "$want" ]; then log_info "login shell already zsh"; return 0; fi
    [ -x "$want" ] || { log_warn "zsh not installed; skipping chsh"; return 0; }
    grep -qxF "$want" "$shells" || { log_warn "$want is not listed in $shells; skipping chsh"; return 0; }
    # chsh authenticates, so it fails on a mistyped password -- and under
    # set -e an unguarded failure here kills the run before services, the
    # version managers and the report. Every other branch of this phase is
    # already guarded; this one was not. A dry run cannot catch it, because
    # run() does not execute anything under DRY_RUN.
    run chsh -s "$want" || log_warn "chsh failed; set it by hand: chsh -s $want"
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
        # One service that will not start must not cost the user the report.
        run sudo systemctl enable --now "$s.service" \
            || log_warn "could not enable $s; check: systemctl status $s"
    done
}

phase_version_managers() {
    log_step "version managers"
    if [ -d "$HOME/.nvm" ]; then
        log_info "nvm already installed"
    else
        # PROFILE=/dev/null: the installer otherwise appends its loader to the
        # profile of $SHELL -- still bash in this session, since chsh only
        # takes effect at the next login -- and ~/.bashrc is a stowed link
        # into the repo, so the append dirties home/.bashrc. .zshrc already
        # loads nvm. pipefail: without it the pipeline's status is bash's,
        # and bash reading an empty script from a failed curl exits 0.
        run bash -c 'set -o pipefail; curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | PROFILE=/dev/null bash' \
        || log_warn "the nvm installer failed; install it by hand from https://github.com/nvm-sh/nvm"
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
    if [ "${#BOOTSTRAP_MANUAL[@]}" -gt 0 ]; then
        log_warn "steps this run could not complete — do these yourself:"
        local m
        for m in "${BOOTSTRAP_MANUAL[@]}"; do
            log_warn "  - $m"
        done
    fi
    cat >&2 <<'MANUAL'

Remaining manual steps — none of these can be automated safely:

  1. Copy your SSH keys to ~/.ssh, then switch both repos to SSH remotes:
       git -C ~/.dotfiles remote set-url origin git@github.com:PieroNarciso/Dotfiles.git
       git -C ~/.nvim-config remote set-url origin git@github.com:PieroNarciso/nvim-config.git
  2. Import your GPG key, then check: git config --global user.signingkey
  3. Copy ~/.aws, ~/.gitconfig-bsale and ~/.gitconfig-pws from the desktop.
  4. Authenticate the CLIs: gh auth login, aws configure, gcloud init.
  5. Open neovim, wait for packer to finish installing (an E492 about
     TSUpdate during that first sync is expected), quit, and open it again.
     Then :Codeium Auth.
  5b. Hyprland only: the stowed config requires the hyprsplit plugin, which
      is gitignored and must be cloned separately, and its monitor lines name
      the desktop's outputs. On a laptop, check `hyprctl monitors` and edit
      the hl.monitor() lines in ~/.config/hypr/hyprland.lua to match
      (hyprpaper.conf needs no edit: its "*" block covers any output):
        git clone https://github.com/shezdy/hyprsplit ~/.config/hypr/hyprsplit
  6. Install any optional group you skipped:
       install/bootstrap.sh --groups audio-prod,gaming,media,mobile,server,virt,work,x11

MANUAL
}

main() {
    parse_args "$@"
    # shellcheck source=lib/hw.sh
    source "$INSTALL_DIR/lib/hw.sh"
    # shellcheck source=lib/boot.sh
    source "$INSTALL_DIR/lib/boot.sh"
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

# Sourced by the tests to get the phase functions without running them.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi
