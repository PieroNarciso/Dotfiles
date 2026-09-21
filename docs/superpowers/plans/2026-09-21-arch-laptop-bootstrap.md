# Arch Laptop Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an `install/` toolkit in the Dotfiles repo that takes a new laptop from the Arch ISO — optionally with an encrypted root — to a working copy of this desktop's zsh / neovim / Hyprland environment.

**Architecture:** Two stages. Stage 0 is `archinstall` driven by a JSON config committed to the repo (one plain, one LUKS2). Stage 1 is `bootstrap.sh`, an idempotent bash script that sources small libraries (`lib/log.sh`, `lib/pkg.sh`, `lib/hw.sh`) and installs curated package groups, stows both dotfile repos, enables services and sets up version managers.

**Tech Stack:** bash 5, GNU stow, pacman/paru, archinstall, systemd. Tests with `bats` (extra repo), linting with `shellcheck` (extra repo).

**Spec:** `docs/superpowers/specs/2026-09-21-arch-laptop-bootstrap-design.md`

## Global Constraints

- Target OS is Arch Linux only. Scripts refuse to run elsewhere.
- Every script starts with `#!/usr/bin/env bash` and `set -euo pipefail`.
- Every phase is idempotent: a second run installs nothing and changes nothing.
- `--dry-run` must exercise the same code path as a real run, printing commands instead of executing them.
- No file is ever deleted or overwritten in place by the dotfiles phase; conflicts are **moved** to `~/.dotfiles-backup-<timestamp>/`.
- No disk device path appears in any committed archinstall config. Disk selection stays interactive.
- No passphrase, password or key appears in any committed file. `install/archinstall/creds.json` is gitignored.
- Repo clones in stage 1 use **HTTPS**, because a fresh laptop has no SSH key.
- Commit messages carry no `Co-Authored-By` or generated-by trailers.
- All scripts must pass `shellcheck -x` with no warnings.
- Tests live in `install/tests/*.bats` and run with `bats install/tests/`.
- Work happens in the `~/.dotfiles` repo on a branch `feat/install-bootstrap`, off `main`.

---

## File Structure

```
install/
├── bootstrap.sh              # stage 1 entrypoint: arg parsing, phase sequencing
├── pkg-audit.sh              # drift check between live pacman state and group files
├── lib/
│   ├── log.sh                # log_info/warn/error/step, run() honouring DRY_RUN
│   ├── pkg.sh                # pkg_missing, pkg_install_file, aur_install_file
│   ├── hw.sh                 # cpu vendor, microcode package, gpu vendor, battery
│   └── dotfiles.sh           # clone_or_pull, backup_conflicts, stow_repo
├── packages/
│   ├── core.txt  dev.txt  desktop.txt  fonts.txt  apps.txt  laptop.txt  aur.txt
│   ├── gpu-amd.txt  gpu-intel.txt  gpu-nvidia.txt
│   └── optional/{audio-prod,gaming,virt,media,x11,server,work,mobile}.txt
├── archinstall/
│   ├── laptop.json           # plain root
│   ├── laptop-luks.json      # LUKS2 root
│   ├── creds.json.example
│   └── README.md
└── tests/
    ├── test_helper.bash
    ├── log.bats  hw.bats  pkg.bats  dotfiles.bats  bootstrap.bats  pkg-audit.bats
```

Responsibilities are split so each library holds one concern and can be tested
without running an install: `hw.sh` reads hardware facts through overridable
paths, `pkg.sh` decides what is missing, `dotfiles.sh` owns the filesystem
mutations, `bootstrap.sh` only sequences phases.

---

### Task 1: Push the pending work so a clone is current

No script can help a laptop that clones stale config. Both repos have unpushed
work as of 2026-09-21: `Dotfiles` is 13 commits ahead with two modified Hyprland
files, and `nvim-config` has four modified Lua files.

**Files:**
- Modify: `~/.dotfiles/config/.config/hypr/hyprland.lua`, `~/.dotfiles/config/.config/hypr/hyprlock.conf` (commit as-is)
- Modify: `~/.nvim-config/.config/nvim/init.lua`, `lua/plugins.lua`, `lua/nv-tree/init.lua`, `lua/nv-treesitter/init.lua` (commit as-is)

**Interfaces:**
- Consumes: nothing
- Produces: `origin/main` on both repos containing every local change, so stage 1's clone is complete

- [ ] **Step 1: Review the pending Hyprland diff**

```bash
cd ~/.dotfiles && git diff -- config/.config/hypr/
```

Read it. If anything in it is experimental and should not land on the laptop, stash that hunk instead of committing it.

- [ ] **Step 2: Commit and push the Dotfiles changes**

```bash
cd ~/.dotfiles
git add config/.config/hypr/hyprland.lua config/.config/hypr/hyprlock.conf
git commit -m "config(hypr): sync current hyprland and hyprlock settings"
git push origin main
```

- [ ] **Step 3: Review the pending neovim diff**

```bash
cd ~/.nvim-config && git diff
```

- [ ] **Step 4: Commit and push the neovim changes**

```bash
cd ~/.nvim-config
git add -A
git commit -m "config(nvim): sync plugin, tree and treesitter settings"
git push origin main
```

- [ ] **Step 5: Verify both remotes are current**

Run:

```bash
cd ~/.dotfiles && git status -sb | head -1
cd ~/.nvim-config && git status -sb | head -1
```

Expected: both print `## main...origin/main` with no `ahead` or `behind` marker and no modified files.

- [ ] **Step 6: Create the working branch**

```bash
cd ~/.dotfiles && git checkout -b feat/install-bootstrap
```

---

### Task 2: Logging library and the bootstrap skeleton

The first runnable artifact: a script that parses arguments, prints a plan and
does nothing else. Everything later plugs into it.

**Files:**
- Create: `install/lib/log.sh`
- Create: `install/bootstrap.sh`
- Create: `install/tests/test_helper.bash`
- Test: `install/tests/log.bats`, `install/tests/bootstrap.bats`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `log_info <msg>`, `log_warn <msg>`, `log_error <msg>`, `log_step <msg>` — write to stderr, prefixed and coloured when stderr is a TTY
  - `run <cmd> [args...]` — executes the command, or prints `DRY-RUN: <cmd...>` and returns 0 when `DRY_RUN=1`
  - `die <msg>` — `log_error` then `exit 1`
  - `bootstrap.sh` globals: `DRY_RUN` (0/1), `GROUPS` (comma-separated string), `SKIP_DOTFILES` (0/1)

- [ ] **Step 1: Install the test tooling**

```bash
sudo pacman -S --needed bats shellcheck
```

- [ ] **Step 2: Write the test helper**

Create `install/tests/test_helper.bash`:

```bash
#!/usr/bin/env bash
# Shared helpers for the install test suite.

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export INSTALL_DIR

# Make a scratch directory that bats tears down after each test.
setup_tmpdir() {
    TEST_TMPDIR="$(mktemp -d)"
    export TEST_TMPDIR
}

teardown_tmpdir() {
    [ -n "${TEST_TMPDIR:-}" ] && rm -rf "$TEST_TMPDIR"
}
```

- [ ] **Step 3: Write the failing tests for log.sh**

Create `install/tests/log.bats`:

```bash
#!/usr/bin/env bats

load test_helper

setup() {
    source "$INSTALL_DIR/lib/log.sh"
}

@test "log_info writes to stderr, not stdout" {
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; log_info hello 2>/dev/null"
    [ "$output" = "" ]
}

@test "log_info message reaches stderr" {
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; log_info hello 2>&1 >/dev/null"
    [[ "$output" == *"hello"* ]]
}

@test "run executes the command when DRY_RUN is 0" {
    setup_tmpdir
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; DRY_RUN=0 run touch '$TEST_TMPDIR/made'"
    [ -f "$TEST_TMPDIR/made" ]
    teardown_tmpdir
}

@test "run prints instead of executing when DRY_RUN is 1" {
    setup_tmpdir
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; DRY_RUN=1 run touch '$TEST_TMPDIR/made' 2>&1"
    [ ! -f "$TEST_TMPDIR/made" ]
    [[ "$output" == *"DRY-RUN"* ]]
    teardown_tmpdir
}

@test "run returns 0 in dry-run even for a command that would fail" {
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; DRY_RUN=1 run false"
    [ "$status" -eq 0 ]
}

@test "die exits non-zero" {
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; die 'boom'"
    [ "$status" -eq 1 ]
}
```

- [ ] **Step 4: Run the tests to verify they fail**

Run: `bats install/tests/log.bats`
Expected: every test fails, because `install/lib/log.sh` does not exist.

- [ ] **Step 5: Write lib/log.sh**

```bash
#!/usr/bin/env bash
# Logging and command execution helpers.
# Everything goes to stderr so callers can still capture stdout.

if [ -t 2 ]; then
    _C_RESET=$'\033[0m'; _C_BLUE=$'\033[1;34m'; _C_YELLOW=$'\033[1;33m'
    _C_RED=$'\033[1;31m'; _C_GREEN=$'\033[1;32m'
else
    _C_RESET=''; _C_BLUE=''; _C_YELLOW=''; _C_RED=''; _C_GREEN=''
fi

log_info()  { printf '%s==>%s %s\n' "$_C_BLUE"   "$_C_RESET" "$*" >&2; }
log_step()  { printf '%s::%s  %s\n' "$_C_GREEN"  "$_C_RESET" "$*" >&2; }
log_warn()  { printf '%swarn:%s %s\n' "$_C_YELLOW" "$_C_RESET" "$*" >&2; }
log_error() { printf '%serror:%s %s\n' "$_C_RED"  "$_C_RESET" "$*" >&2; }

die() { log_error "$*"; exit 1; }

# run <command> [args...] — honours DRY_RUN=1 by printing the command instead.
run() {
    if [ "${DRY_RUN:-0}" = "1" ]; then
        printf 'DRY-RUN: %s\n' "$*" >&2
        return 0
    fi
    "$@"
}
```

- [ ] **Step 6: Run the log tests to verify they pass**

Run: `bats install/tests/log.bats`
Expected: 6 tests, all passing.

- [ ] **Step 7: Write the failing tests for the bootstrap skeleton**

Create `install/tests/bootstrap.bats`:

```bash
#!/usr/bin/env bats

load test_helper

@test "--help exits 0 and documents the flags" {
    run bash "$INSTALL_DIR/bootstrap.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--dry-run"* ]]
    [[ "$output" == *"--groups"* ]]
    [[ "$output" == *"--skip-dotfiles"* ]]
}

@test "unknown flag exits non-zero" {
    run bash "$INSTALL_DIR/bootstrap.sh" --nonsense
    [ "$status" -ne 0 ]
}

@test "--groups sets the group list" {
    run bash "$INSTALL_DIR/bootstrap.sh" --dry-run --groups core,dev
    [[ "$output" == *"core,dev"* ]]
}

@test "default group list is core,dev,desktop,fonts,apps,laptop" {
    run bash "$INSTALL_DIR/bootstrap.sh" --dry-run
    [[ "$output" == *"core,dev,desktop,fonts,apps,laptop"* ]]
}

@test "--dry-run changes nothing on disk" {
    before="$(find "$HOME" -maxdepth 1 -newermt '-1 second' | wc -l)"
    run bash "$INSTALL_DIR/bootstrap.sh" --dry-run
    [ "$status" -eq 0 ]
    [ "$before" -eq "$(find "$HOME" -maxdepth 1 -newermt '-1 second' | wc -l)" ]
}
```

- [ ] **Step 8: Run to verify they fail**

Run: `bats install/tests/bootstrap.bats`
Expected: all fail, `bootstrap.sh` does not exist.

- [ ] **Step 9: Write the bootstrap skeleton**

Create `install/bootstrap.sh`, `chmod +x` it:

```bash
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
```

- [ ] **Step 10: Run both test files to verify they pass**

Run: `bats install/tests/`
Expected: 11 tests, all passing.

- [ ] **Step 11: Lint**

Run: `shellcheck -x install/bootstrap.sh install/lib/log.sh`
Expected: no output.

- [ ] **Step 12: Commit**

```bash
cd ~/.dotfiles
git add install/bootstrap.sh install/lib/log.sh install/tests/
git commit -m "feat(install): bootstrap skeleton with logging and dry-run"
```

---

### Task 3: Hardware detection library

The one thing the desktop's package list gets wrong for a laptop is hardware:
microcode, GPU driver, and whether power management applies at all. Detection
reads through overridable paths so it can be tested against fixtures.

**Files:**
- Create: `install/lib/hw.sh`
- Test: `install/tests/hw.bats`

**Interfaces:**
- Consumes: `lib/log.sh`
- Produces:
  - `hw_cpu_vendor()` → prints `intel`, `amd`, or `unknown`
  - `hw_microcode_package()` → prints `intel-ucode`, `amd-ucode`, or empty
  - `hw_gpu_vendor()` → prints `amd`, `intel`, `nvidia`, or `unknown`
  - `hw_has_battery()` → exit 0 when a battery exists, 1 otherwise
  - Overrides: `HW_CPUINFO` (default `/proc/cpuinfo`), `HW_POWER_SUPPLY_DIR` (default `/sys/class/power_supply`), `HW_LSPCI` (default `lspci`)

- [ ] **Step 1: Write the failing tests**

Create `install/tests/hw.bats`:

```bash
#!/usr/bin/env bats

load test_helper

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "hw_cpu_vendor detects intel" {
    printf 'processor\t: 0\nvendor_id\t: GenuineIntel\n' > "$TEST_TMPDIR/cpuinfo"
    run bash -c "source '$INSTALL_DIR/lib/hw.sh'; HW_CPUINFO='$TEST_TMPDIR/cpuinfo' hw_cpu_vendor"
    [ "$output" = "intel" ]
}

@test "hw_cpu_vendor detects amd" {
    printf 'processor\t: 0\nvendor_id\t: AuthenticAMD\n' > "$TEST_TMPDIR/cpuinfo"
    run bash -c "source '$INSTALL_DIR/lib/hw.sh'; HW_CPUINFO='$TEST_TMPDIR/cpuinfo' hw_cpu_vendor"
    [ "$output" = "amd" ]
}

@test "hw_cpu_vendor reports unknown for anything else" {
    printf 'vendor_id\t: SomeOtherCPU\n' > "$TEST_TMPDIR/cpuinfo"
    run bash -c "source '$INSTALL_DIR/lib/hw.sh'; HW_CPUINFO='$TEST_TMPDIR/cpuinfo' hw_cpu_vendor"
    [ "$output" = "unknown" ]
}

@test "hw_microcode_package maps intel to intel-ucode" {
    printf 'vendor_id\t: GenuineIntel\n' > "$TEST_TMPDIR/cpuinfo"
    run bash -c "source '$INSTALL_DIR/lib/hw.sh'; HW_CPUINFO='$TEST_TMPDIR/cpuinfo' hw_microcode_package"
    [ "$output" = "intel-ucode" ]
}

@test "hw_microcode_package maps amd to amd-ucode" {
    printf 'vendor_id\t: AuthenticAMD\n' > "$TEST_TMPDIR/cpuinfo"
    run bash -c "source '$INSTALL_DIR/lib/hw.sh'; HW_CPUINFO='$TEST_TMPDIR/cpuinfo' hw_microcode_package"
    [ "$output" = "amd-ucode" ]
}

@test "hw_microcode_package prints nothing for unknown vendors" {
    printf 'vendor_id\t: SomeOtherCPU\n' > "$TEST_TMPDIR/cpuinfo"
    run bash -c "source '$INSTALL_DIR/lib/hw.sh'; HW_CPUINFO='$TEST_TMPDIR/cpuinfo' hw_microcode_package"
    [ "$output" = "" ]
}

@test "hw_has_battery succeeds when a BAT device exists" {
    mkdir -p "$TEST_TMPDIR/power/BAT0"
    run bash -c "source '$INSTALL_DIR/lib/hw.sh'; HW_POWER_SUPPLY_DIR='$TEST_TMPDIR/power' hw_has_battery"
    [ "$status" -eq 0 ]
}

@test "hw_has_battery fails when only AC is present" {
    mkdir -p "$TEST_TMPDIR/power/AC"
    run bash -c "source '$INSTALL_DIR/lib/hw.sh'; HW_POWER_SUPPLY_DIR='$TEST_TMPDIR/power' hw_has_battery"
    [ "$status" -ne 0 ]
}

@test "hw_gpu_vendor detects intel from lspci output" {
    cat > "$TEST_TMPDIR/lspci" <<'FAKE'
#!/usr/bin/env bash
echo "00:02.0 VGA compatible controller: Intel Corporation Raptor Lake-P [Iris Xe Graphics]"
FAKE
    chmod +x "$TEST_TMPDIR/lspci"
    run bash -c "source '$INSTALL_DIR/lib/hw.sh'; HW_LSPCI='$TEST_TMPDIR/lspci' hw_gpu_vendor"
    [ "$output" = "intel" ]
}

@test "hw_gpu_vendor detects amd from lspci output" {
    cat > "$TEST_TMPDIR/lspci" <<'FAKE'
#!/usr/bin/env bash
echo "03:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Navi 33"
FAKE
    chmod +x "$TEST_TMPDIR/lspci"
    run bash -c "source '$INSTALL_DIR/lib/hw.sh'; HW_LSPCI='$TEST_TMPDIR/lspci' hw_gpu_vendor"
    [ "$output" = "amd" ]
}

@test "hw_gpu_vendor detects nvidia from lspci output" {
    cat > "$TEST_TMPDIR/lspci" <<'FAKE'
#!/usr/bin/env bash
echo "01:00.0 VGA compatible controller: NVIDIA Corporation AD107M [GeForce RTX 4060]"
FAKE
    chmod +x "$TEST_TMPDIR/lspci"
    run bash -c "source '$INSTALL_DIR/lib/hw.sh'; HW_LSPCI='$TEST_TMPDIR/lspci' hw_gpu_vendor"
    [ "$output" = "nvidia" ]
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `bats install/tests/hw.bats`
Expected: 11 failures, `lib/hw.sh` missing.

- [ ] **Step 3: Write lib/hw.sh**

```bash
#!/usr/bin/env bash
# Hardware facts. Every source path is overridable so the functions are testable.

HW_CPUINFO="${HW_CPUINFO:-/proc/cpuinfo}"
HW_POWER_SUPPLY_DIR="${HW_POWER_SUPPLY_DIR:-/sys/class/power_supply}"
HW_LSPCI="${HW_LSPCI:-lspci}"

hw_cpu_vendor() {
    local vendor
    vendor="$(awk -F': ' '/^vendor_id/ {print $2; exit}' "$HW_CPUINFO" 2>/dev/null || true)"
    case "$vendor" in
        GenuineIntel) echo intel ;;
        AuthenticAMD) echo amd ;;
        *)            echo unknown ;;
    esac
}

hw_microcode_package() {
    case "$(hw_cpu_vendor)" in
        intel) echo intel-ucode ;;
        amd)   echo amd-ucode ;;
        *)     : ;;
    esac
}

hw_gpu_vendor() {
    local out
    out="$("$HW_LSPCI" 2>/dev/null | grep -iE 'vga|3d controller' || true)"
    if   echo "$out" | grep -qi nvidia;            then echo nvidia
    elif echo "$out" | grep -qiE 'amd|ati|radeon'; then echo amd
    elif echo "$out" | grep -qi intel;             then echo intel
    else echo unknown
    fi
}

hw_has_battery() {
    compgen -G "$HW_POWER_SUPPLY_DIR/BAT*" > /dev/null
}
```

Note `compgen` needs bash, which the shebang already guarantees.

- [ ] **Step 4: Run to verify they pass**

Run: `bats install/tests/hw.bats`
Expected: 11 tests passing.

- [ ] **Step 5: Sanity-check against this machine**

Run: `bash -c "source install/lib/hw.sh; hw_cpu_vendor; hw_microcode_package; hw_gpu_vendor; hw_has_battery && echo battery || echo no-battery"`
Expected on this desktop: `amd`, `amd-ucode`, `amd`, `no-battery`.

- [ ] **Step 6: Lint and commit**

```bash
shellcheck -x install/lib/hw.sh
cd ~/.dotfiles
git add install/lib/hw.sh install/tests/hw.bats
git commit -m "feat(install): hardware detection for microcode, gpu and battery"
```

---

### Task 4: Package group files

Generated by classifying the live `pacman -Qqe` output of this desktop on
2026-09-21, not by copying the stale `Packages-Desktop`. Hardware-specific and
hobby packages are isolated so the laptop does not inherit them.

**Files:**
- Create: `install/packages/{core,dev,desktop,fonts,apps,laptop,aur}.txt`
- Create: `install/packages/{gpu-amd,gpu-intel,gpu-nvidia}.txt`
- Create: `install/packages/optional/{audio-prod,gaming,virt,media,x11,server,work,mobile}.txt`

**Interfaces:**
- Consumes: nothing
- Produces: one package name per line, `#` comments and blank lines allowed. Group name equals file basename; `bootstrap.sh --groups` and `pkg-audit.sh` both resolve names to these paths.

- [ ] **Step 1: Create the directories**

```bash
mkdir -p ~/.dotfiles/install/packages/optional
```

- [ ] **Step 2: Write core.txt**

```
# Base system, shell and command line. Installed on every machine.
base
base-devel
linux
linux-firmware
linux-lts
linux-lts-headers
efibootmgr
os-prober
sbctl
openssh
git
stow
zsh
zsh-autosuggestions
zsh-syntax-highlighting
zsh-history-substring-search
starship
neovim
vim
tmux
fzf
ripgrep
bat
jq
tree
tldr
man-db
nano
htop
ncdu
fastfetch
wget
rsync
unzip
unrar
trash-cli
inotify-tools
croc
yt-dlp
xclip
xsel
networkmanager
systemd-resolvconf
wpa_supplicant
iwd
wireless_tools
openvpn
wireguard-tools
firewalld
reflector
smartmontools
dmidecode
ntfs-3g
xdg-user-dirs
xdg-utils
terminus-font
```

- [ ] **Step 3: Write dev.txt**

```
# Development toolchains and CLIs.
docker
docker-buildx
docker-compose
go
rust
nodejs-lts-jod
npm
ruby
jdk17-openjdk
jre-openjdk
pyenv
python-pipx
python-pipenv
python-attrdict
github-cli
gitleaks
meson
tree-sitter-cli
minikube
mariadb-clients
postgresql-libs
aws-cli
jadx
geckodriver
sysbench
vegeta
swaks
nmap
arp-scan
logcli
rclone
pandoc-cli
zint
barcode
qmk
zed
```

- [ ] **Step 4: Write desktop.txt**

```
# Hyprland session, audio stack and portals.
hyprland
hyprlock
hyprpaper
waybar
wofi
rofi
rofi-emoji
dunst
cliphist
grim
slurp
swappy
xdg-desktop-portal-hyprland
xdg-desktop-portal-gtk
polkit-gnome
gnome-keyring
alacritty
kitty
pipewire-alsa
pipewire-jack
pipewire-pulse
pavucontrol
playerctl
alsa-utils
easyeffects
papirus-icon-theme
gtk2-compat
imagemagick
nvtop
```

- [ ] **Step 5: Write fonts.txt**

```
# Fonts, including the nerd fonts the waybar and terminal configs assume.
adobe-source-sans-fonts
noto-fonts-emoji
ttf-dejavu
ttf-droid
ttf-fira-mono
ttf-firacode-nerd
ttf-hack
ttf-hack-nerd
ttf-liberation
ttf-nerd-fonts-symbols
ttf-noto-nerd
ttf-opensans
ttf-roboto
ttf-sourcecodepro-nerd
woff2-font-awesome
```

- [ ] **Step 6: Write apps.txt**

```
# Graphical applications.
firefox
chromium
nemo
nemo-fileroller
gparted
vlc
obsidian
discord
libreoffice-fresh
syncthing
flatpak
flameshot
gcolor3
qalculate-gtk
blueman
network-manager-applet
proton-vpn-gtk-app
rqbit-desktop
speech-dispatcher
```

- [ ] **Step 7: Write laptop.txt**

```
# Power, thermal, input and radio. Only useful on a machine with a battery.
tlp
tlp-rdw
thermald
brightnessctl
zram-generator
bluez
bluez-utils
acpi
upower
libinput-gestures
```

- [ ] **Step 8: Write the GPU group files**

`gpu-amd.txt`:

```
# AMD graphics and compute.
xf86-video-amdgpu
xf86-video-ati
vulkan-radeon
lib32-vulkan-radeon
rocm-hip-sdk
rocm-opencl-sdk
clblast
```

`gpu-intel.txt`:

```
# Intel graphics.
vulkan-intel
lib32-vulkan-intel
intel-media-driver
libva-intel-driver
```

`gpu-nvidia.txt`:

```
# NVIDIA proprietary stack. Pairs with the linux and linux-lts kernels in core.
nvidia-dkms
nvidia-utils
lib32-nvidia-utils
nvidia-settings
```

- [ ] **Step 9: Write aur.txt**

```
# AUR packages installed with paru on every machine.
brave-bin
zen-browser-bin
visual-studio-code-bin
xwaylandvideobridge
```

- [ ] **Step 10: Write the optional group files**

`optional/audio-prod.txt`:

```
# Audio production. Desktop only unless the laptop grows a use for it.
ardour
guitarix
calf
mda.lv2
reaper
helvum
lib32-pipewire
lib32-pipewire-jack
```

`optional/gaming.txt`:

```
steam
lutris
gamescope
```

`optional/virt.txt`:

```
qemu-base
qemu-full
qemu-vhost-user-gpu
libvirt
virt-manager
dnsmasq
freerdp
```

`optional/media.txt`:

```
kdenlive
guvcview
v4l2loopback-dkms
perl-image-exiftool
```

`optional/x11.txt`:

```
# Legacy X11 session kept on the desktop. The laptop runs Hyprland only.
xorg-server
xorg-xinit
xorg-xrandr
xterm
arandr
awesome
vicious
i3lock
slock
xss-lock
xfce4-clipman-plugin
xdotool
feh
```

`optional/server.txt`:

```
apache
```

`optional/work.txt`:

```
wazuh-agent
wazuh-agent-debug
```

`optional/mobile.txt`:

```
android-studio
```

- [ ] **Step 11: Verify every file parses and names no duplicate**

Run:

```bash
cd ~/.dotfiles/install/packages
cat ./*.txt optional/*.txt | grep -vE '^\s*(#|$)' | sort | uniq -d
```

Expected: no output. A duplicate means one package sits in two groups, which breaks the audit's arithmetic — move it to the more specific group.

- [ ] **Step 12: Commit**

```bash
cd ~/.dotfiles
git add install/packages/
git commit -m "feat(install): curated package groups generated from live pacman state"
```

---

### Task 5: Package library and the drift audit

`Packages-Desktop` rotted for two years because nothing compared it to reality.
The audit closes that loop and doubles as the test that the group files are
honest.

**Files:**
- Create: `install/lib/pkg.sh`
- Create: `install/pkg-audit.sh`
- Test: `install/tests/pkg.bats`, `install/tests/pkg-audit.bats`

**Interfaces:**
- Consumes: `lib/log.sh`
- Produces:
  - `pkg_read_list <file>` — prints package names, stripping comments and blanks
  - `pkg_missing <pkg>...` — prints, one per line, the subset not installed
  - `pkg_install_file <file>` — installs the missing entries with `pacman -S --needed`; a failing package is logged and skipped, the function still returns 0 and appends to `PKG_FAILED`
  - `aur_install_file <file>` — the same via `paru -S --needed`
  - Override: `PKG_QUERY_CMD` (default `pacman -Qq`) so tests can fake installed state
  - `PKG_FAILED` — array of package names that failed, read by the final report

- [ ] **Step 1: Write the failing tests for pkg.sh**

Create `install/tests/pkg.bats`:

```bash
#!/usr/bin/env bats

load test_helper

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "pkg_read_list strips comments and blank lines" {
    printf '# a comment\n\nzsh\n  stow  \n' > "$TEST_TMPDIR/list.txt"
    run bash -c "source '$INSTALL_DIR/lib/pkg.sh'; pkg_read_list '$TEST_TMPDIR/list.txt'"
    [ "$output" = "zsh
stow" ]
}

@test "pkg_read_list dies on a missing file" {
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/pkg.sh'; pkg_read_list '$TEST_TMPDIR/nope.txt'"
    [ "$status" -ne 0 ]
}

@test "pkg_missing returns only packages absent from the query output" {
    cat > "$TEST_TMPDIR/query" <<'FAKE'
#!/usr/bin/env bash
printf 'zsh\nstow\n'
FAKE
    chmod +x "$TEST_TMPDIR/query"
    run bash -c "source '$INSTALL_DIR/lib/pkg.sh'; PKG_QUERY_CMD='$TEST_TMPDIR/query' pkg_missing zsh neovim stow"
    [ "$output" = "neovim" ]
}

@test "pkg_missing prints nothing when everything is installed" {
    cat > "$TEST_TMPDIR/query" <<'FAKE'
#!/usr/bin/env bash
printf 'zsh\nstow\n'
FAKE
    chmod +x "$TEST_TMPDIR/query"
    run bash -c "source '$INSTALL_DIR/lib/pkg.sh'; PKG_QUERY_CMD='$TEST_TMPDIR/query' pkg_missing zsh stow"
    [ "$output" = "" ]
}

@test "pkg_install_file is a no-op in dry-run and prints the pacman command" {
    printf 'neovim\n' > "$TEST_TMPDIR/list.txt"
    cat > "$TEST_TMPDIR/query" <<'FAKE'
#!/usr/bin/env bash
printf 'zsh\n'
FAKE
    chmod +x "$TEST_TMPDIR/query"
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/pkg.sh'; DRY_RUN=1 PKG_QUERY_CMD='$TEST_TMPDIR/query' pkg_install_file '$TEST_TMPDIR/list.txt' 2>&1"
    [[ "$output" == *"DRY-RUN"* ]]
    [[ "$output" == *"neovim"* ]]
}

@test "pkg_install_file skips the install entirely when nothing is missing" {
    printf 'zsh\n' > "$TEST_TMPDIR/list.txt"
    cat > "$TEST_TMPDIR/query" <<'FAKE'
#!/usr/bin/env bash
printf 'zsh\n'
FAKE
    chmod +x "$TEST_TMPDIR/query"
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/pkg.sh'; DRY_RUN=1 PKG_QUERY_CMD='$TEST_TMPDIR/query' pkg_install_file '$TEST_TMPDIR/list.txt' 2>&1"
    [[ "$output" != *"DRY-RUN"* ]]
    [[ "$output" == *"up to date"* ]]
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `bats install/tests/pkg.bats`
Expected: 6 failures.

- [ ] **Step 3: Write lib/pkg.sh**

```bash
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
        if ! run $installer --needed --noconfirm "$p"; then
            log_warn "failed to install: $p"
            PKG_FAILED+=("$p")
        fi
    done
    return 0
}

pkg_install_file() { _pkg_install_with "sudo pacman -S" "$1"; }
aur_install_file() { _pkg_install_with "paru -S" "$1"; }
```

The unquoted `$installer` expansion is deliberate — it carries multiple words.
Add `# shellcheck disable=SC2086` on that line with the reason in a comment.

- [ ] **Step 4: Run to verify they pass**

Run: `bats install/tests/pkg.bats`
Expected: 6 tests passing.

- [ ] **Step 5: Write the failing tests for pkg-audit.sh**

Create `install/tests/pkg-audit.bats`:

```bash
#!/usr/bin/env bats

load test_helper

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

make_groups() {
    mkdir -p "$TEST_TMPDIR/packages/optional"
    printf 'zsh\nstow\n' > "$TEST_TMPDIR/packages/core.txt"
}

fake_query() {
    cat > "$TEST_TMPDIR/query" <<FAKE
#!/usr/bin/env bash
printf '%s\n' $1
FAKE
    chmod +x "$TEST_TMPDIR/query"
}

@test "audit exits 0 when the group files match the live state" {
    make_groups
    fake_query "'zsh' 'stow'"
    run bash -c "PKG_AUDIT_DIR='$TEST_TMPDIR/packages' PKG_QUERY_CMD='$TEST_TMPDIR/query' bash '$INSTALL_DIR/pkg-audit.sh'"
    [ "$status" -eq 0 ]
}

@test "audit reports a package installed but unlisted" {
    make_groups
    fake_query "'zsh' 'stow' 'htop'"
    run bash -c "PKG_AUDIT_DIR='$TEST_TMPDIR/packages' PKG_QUERY_CMD='$TEST_TMPDIR/query' bash '$INSTALL_DIR/pkg-audit.sh' 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" == *"htop"* ]]
    [[ "$output" == *"unlisted"* ]]
}

@test "audit reports a package listed but not installed" {
    make_groups
    fake_query "'zsh'"
    run bash -c "PKG_AUDIT_DIR='$TEST_TMPDIR/packages' PKG_QUERY_CMD='$TEST_TMPDIR/query' bash '$INSTALL_DIR/pkg-audit.sh' 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" == *"stow"* ]]
    [[ "$output" == *"missing"* ]]
}
```

- [ ] **Step 6: Run to verify they fail**

Run: `bats install/tests/pkg-audit.bats`
Expected: 3 failures.

- [ ] **Step 7: Write pkg-audit.sh**

```bash
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

listed="$(mktemp)"; live="$(mktemp)"
trap 'rm -f "$listed" "$live"' EXIT

find "$PKG_AUDIT_DIR" -name '*.txt' -print0 \
    | xargs -0 -I{} sh -c 'sed -e "s/#.*//" -e "s/[[:space:]]//g" "$1"' _ {} \
    | grep -v '^$' | sort -u > "$listed"

$PKG_QUERY_CMD 2>/dev/null | sort -u > "$live"

unlisted="$(comm -13 "$listed" "$live")"
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
```

- [ ] **Step 8: Run to verify they pass**

Run: `bats install/tests/pkg-audit.bats`
Expected: 3 tests passing.

- [ ] **Step 9: Run the audit against this desktop**

Run: `bash install/pkg-audit.sh`
Expected: it lists as *missing* only the laptop-only and other-GPU packages
(`tlp`, `thermald`, `brightnessctl`, `acpi`, `upower`, `libinput-gestures`,
`zram-generator`, `tlp-rdw`, the `gpu-intel` and `gpu-nvidia` entries), and lists
as *unlisted* nothing at all. Any other name in the *unlisted* column is a
package Task 4 forgot — add it to the right group and re-run until that column
is empty.

- [ ] **Step 10: Lint and commit**

```bash
shellcheck -x install/lib/pkg.sh install/pkg-audit.sh
cd ~/.dotfiles
git add install/lib/pkg.sh install/pkg-audit.sh install/tests/pkg.bats install/tests/pkg-audit.bats
git commit -m "feat(install): package install helpers and group drift audit"
```

---

### Task 6: Dotfiles library — clone, back up conflicts, stow

The only phase that mutates `$HOME`. It must never destroy a file it did not
create, which is what the backup step buys.

**Files:**
- Create: `install/lib/dotfiles.sh`
- Test: `install/tests/dotfiles.bats`

**Interfaces:**
- Consumes: `lib/log.sh`
- Produces:
  - `df_clone_or_pull <https-url> <dest-dir>` — clones when absent, `git -C <dest> pull --ff-only` when present
  - `df_backup_conflicts <repo-dir> <target-home> <backup-dir>` — moves every real file in `<target-home>` that stow would collide with into `<backup-dir>`, preserving relative paths; symlinks already pointing into `<repo-dir>` are left alone
  - `df_stow_repo <repo-dir> <target-home>` — runs `stow --restow --target=<target-home> <every top-level package dir>`

- [ ] **Step 1: Write the failing tests**

Create `install/tests/dotfiles.bats`:

```bash
#!/usr/bin/env bats

load test_helper

setup() {
    setup_tmpdir
    FAKE_HOME="$TEST_TMPDIR/home"; mkdir -p "$FAKE_HOME"
    REPO="$TEST_TMPDIR/repo"
    mkdir -p "$REPO/home" "$REPO/config/.config/nvim"
    echo "from repo" > "$REPO/home/.zshrc"
    echo "repo nvim" > "$REPO/config/.config/nvim/init.lua"
}
teardown() { teardown_tmpdir; }

@test "df_backup_conflicts moves a colliding real file into the backup dir" {
    echo "pre-existing" > "$FAKE_HOME/.zshrc"
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        df_backup_conflicts '$REPO' '$FAKE_HOME' '$TEST_TMPDIR/backup'"
    [ "$status" -eq 0 ]
    [ ! -e "$FAKE_HOME/.zshrc" ]
    [ "$(cat "$TEST_TMPDIR/backup/.zshrc")" = "pre-existing" ]
}

@test "df_backup_conflicts preserves nested relative paths" {
    mkdir -p "$FAKE_HOME/.config/nvim"
    echo "old nvim" > "$FAKE_HOME/.config/nvim/init.lua"
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        df_backup_conflicts '$REPO' '$FAKE_HOME' '$TEST_TMPDIR/backup'"
    [ "$(cat "$TEST_TMPDIR/backup/.config/nvim/init.lua")" = "old nvim" ]
}

@test "df_backup_conflicts leaves symlinks that already point into the repo" {
    ln -s "$REPO/home/.zshrc" "$FAKE_HOME/.zshrc"
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        df_backup_conflicts '$REPO' '$FAKE_HOME' '$TEST_TMPDIR/backup'"
    [ -L "$FAKE_HOME/.zshrc" ]
    [ ! -e "$TEST_TMPDIR/backup/.zshrc" ]
}

@test "df_backup_conflicts never deletes anything" {
    echo "precious" > "$FAKE_HOME/.zshrc"
    bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        df_backup_conflicts '$REPO' '$FAKE_HOME' '$TEST_TMPDIR/backup'"
    [ "$(cat "$TEST_TMPDIR/backup/.zshrc")" = "precious" ]
}

@test "df_stow_repo links every package into the target home" {
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        df_stow_repo '$REPO' '$FAKE_HOME'"
    [ "$status" -eq 0 ]
    [ -L "$FAKE_HOME/.zshrc" ]
    [ "$(cat "$FAKE_HOME/.zshrc")" = "from repo" ]
    [ "$(cat "$FAKE_HOME/.config/nvim/init.lua")" = "repo nvim" ]
}

@test "df_stow_repo is idempotent" {
    bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; df_stow_repo '$REPO' '$FAKE_HOME'"
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; df_stow_repo '$REPO' '$FAKE_HOME'"
    [ "$status" -eq 0 ]
    [ -L "$FAKE_HOME/.zshrc" ]
}

@test "df_clone_or_pull clones when the destination is absent" {
    src="$TEST_TMPDIR/src"; mkdir -p "$src"
    git -C "$src" init -q; echo hi > "$src/f"; git -C "$src" add f
    git -C "$src" -c user.email=t@t -c user.name=t commit -qm init
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        df_clone_or_pull '$src' '$TEST_TMPDIR/clone'"
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMPDIR/clone/f" ]
}

@test "df_clone_or_pull pulls when the destination already exists" {
    src="$TEST_TMPDIR/src"; mkdir -p "$src"
    git -C "$src" init -q; echo hi > "$src/f"; git -C "$src" add f
    git -C "$src" -c user.email=t@t -c user.name=t commit -qm init
    git clone -q "$src" "$TEST_TMPDIR/clone"
    echo more > "$src/g"; git -C "$src" add g
    git -C "$src" -c user.email=t@t -c user.name=t commit -qm second
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        df_clone_or_pull '$src' '$TEST_TMPDIR/clone'"
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMPDIR/clone/g" ]
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `bats install/tests/dotfiles.bats`
Expected: 8 failures.

- [ ] **Step 3: Write lib/dotfiles.sh**

```bash
#!/usr/bin/env bash
# Cloning and stowing the dotfile repos. Requires lib/log.sh.

df_clone_or_pull() {
    local url="$1" dest="$2"
    if [ -d "$dest/.git" ]; then
        log_info "updating $dest"
        run git -C "$dest" pull --ff-only
    else
        log_step "cloning $url into $dest"
        run git clone "$url" "$dest"
    fi
}

# Every top-level directory of a stow repo is a stow package.
_df_packages() {
    local repo="$1"
    find "$repo" -maxdepth 1 -mindepth 1 -type d -not -name '.*' -printf '%f\n' | sort
}

# Move aside anything stow would refuse to overwrite.
df_backup_conflicts() {
    local repo="$1" target="$2" backup="$3"
    local pkg src rel dst
    for pkg in $(_df_packages "$repo"); do
        while IFS= read -r src; do
            rel="${src#"$repo/$pkg/"}"
            dst="$target/$rel"
            # A symlink already pointing into the repo is our own work; leave it.
            if [ -L "$dst" ] && [[ "$(readlink -f "$dst")" == "$repo"* ]]; then
                continue
            fi
            [ -e "$dst" ] || continue
            [ -L "$dst" ] && continue
            log_warn "backing up existing $dst"
            run mkdir -p "$(dirname "$backup/$rel")"
            run mv "$dst" "$backup/$rel"
        done < <(find "$repo/$pkg" -type f)
    done
}

df_stow_repo() {
    local repo="$1" target="$2"
    local -a pkgs
    mapfile -t pkgs < <(_df_packages "$repo")
    [ "${#pkgs[@]}" -gt 0 ] || { log_warn "no stow packages in $repo"; return 0; }
    log_step "stowing ${#pkgs[@]} package(s) from $repo"
    run stow --restow --dir="$repo" --target="$target" "${pkgs[@]}"
}
```

- [ ] **Step 4: Run to verify they pass**

Run: `bats install/tests/dotfiles.bats`
Expected: 8 tests passing. If the symlink test fails, check that `readlink -f`
is comparing against the resolved repo path — `mktemp -d` returns a path under
`/tmp` that may itself be a symlink on some systems; resolve `repo` with
`readlink -f` at the top of `df_backup_conflicts` if so.

- [ ] **Step 5: Lint and commit**

```bash
shellcheck -x install/lib/dotfiles.sh
cd ~/.dotfiles
git add install/lib/dotfiles.sh install/tests/dotfiles.bats
git commit -m "feat(install): dotfile clone, conflict backup and stow helpers"
```

---

### Task 7: Wire the phases into bootstrap.sh

Now the skeleton grows its nine phases. Each is a function; `main` calls them in
order.

**Files:**
- Modify: `install/bootstrap.sh`
- Test: `install/tests/bootstrap.bats` (extend)

**Interfaces:**
- Consumes: `log_*`, `run`, `die`, `pkg_install_file`, `aur_install_file`, `pkg_missing`, `hw_*`, `df_*`
- Produces: phase functions `phase_preflight`, `phase_microcode`, `phase_paru`, `phase_packages`, `phase_dotfiles`, `phase_shell`, `phase_services`, `phase_version_managers`, `phase_report`

- [ ] **Step 1: Write the failing tests**

Append to `install/tests/bootstrap.bats`:

```bash
@test "preflight fails when not on Arch" {
    run bash -c "BOOTSTRAP_ARCH_RELEASE='/nonexistent' bash '$INSTALL_DIR/bootstrap.sh' --dry-run 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Arch"* ]]
}

@test "preflight refuses to run as root" {
    run bash -c "BOOTSTRAP_FAKE_EUID=0 bash '$INSTALL_DIR/bootstrap.sh' --dry-run 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" == *"root"* ]]
}

@test "dry-run names every phase it would run" {
    run bash -c "bash '$INSTALL_DIR/bootstrap.sh' --dry-run 2>&1"
    [ "$status" -eq 0 ]
    for phase in preflight microcode paru packages dotfiles shell services report; do
        [[ "$output" == *"$phase"* ]]
    done
}

@test "an unknown group name is rejected before anything is installed" {
    run bash -c "bash '$INSTALL_DIR/bootstrap.sh' --dry-run --groups nosuchgroup 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" == *"nosuchgroup"* ]]
}

@test "--skip-dotfiles omits the dotfiles phase" {
    run bash -c "bash '$INSTALL_DIR/bootstrap.sh' --dry-run --skip-dotfiles 2>&1"
    [[ "$output" != *"cloning"* ]]
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `bats install/tests/bootstrap.bats`
Expected: the five new tests fail; the original five still pass.

- [ ] **Step 3: Extend bootstrap.sh with the phases**

Replace `main` and add the phase functions. The constants at the top:

```bash
readonly DOTFILES_URL="https://github.com/PieroNarciso/Dotfiles.git"
readonly DOTFILES_DIR="$HOME/.dotfiles"
readonly NVIM_URL="https://github.com/PieroNarciso/nvim-config.git"
readonly NVIM_DIR="$HOME/.nvim-config"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
```

```bash
phase_preflight() {
    log_step "preflight"
    [ -f "${BOOTSTRAP_ARCH_RELEASE:-/etc/arch-release}" ] || die "this is not Arch Linux"
    [ "${BOOTSTRAP_FAKE_EUID:-$EUID}" -ne 0 ] || die "do not run as root; it uses sudo where needed"
    command -v sudo >/dev/null || die "sudo is not installed"
    ping -c1 -W3 archlinux.org >/dev/null 2>&1 || die "no network connectivity"
    # Validate the group names before touching the system.
    local g
    for g in ${GROUPS//,/ }; do
        [ -f "$INSTALL_DIR/packages/$g.txt" ] || [ -f "$INSTALL_DIR/packages/optional/$g.txt" ] \
            || die "unknown package group: $g"
    done
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

phase_paru() {
    log_step "paru"
    if command -v paru >/dev/null; then log_info "paru already present"; return 0; fi
    run sudo pacman -S --needed --noconfirm base-devel git
    local tmp; tmp="$(mktemp -d)"
    run git clone https://aur.archlinux.org/paru.git "$tmp/paru"
    ( cd "$tmp/paru" && run makepkg -si --noconfirm )
    run rm -rf "$tmp"
}

phase_packages() {
    log_step "packages"
    local g file
    for g in ${GROUPS//,/ }; do
        file="$INSTALL_DIR/packages/$g.txt"
        [ -f "$file" ] || file="$INSTALL_DIR/packages/optional/$g.txt"
        pkg_install_file "$file"
    done
    local gpu; gpu="$(hw_gpu_vendor)"
    if [ -f "$INSTALL_DIR/packages/gpu-$gpu.txt" ]; then
        log_info "gpu detected: $gpu"
        pkg_install_file "$INSTALL_DIR/packages/gpu-$gpu.txt"
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
    if [ "${SHELL:-}" = "$want" ]; then log_info "login shell already zsh"; return 0; fi
    [ -x "$want" ] || { log_warn "zsh not installed; skipping chsh"; return 0; }
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

    log_info "groups: $GROUPS"
    phase_preflight
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bats install/tests/`
Expected: all tests across the six files pass. From this task onward the
`--dry-run` tests written in Task 2 exercise `phase_preflight`, so they need
working network connectivity — a failure reading `no network connectivity` means
the machine is offline, not that the code is broken.

- [ ] **Step 5: Dry-run against this desktop**

Run: `bash install/bootstrap.sh --dry-run`
Expected: it names every phase, reports the already-installed groups as "up to
date", would install only the laptop-only packages (this desktop has no
battery, so `tlp`/`thermald` are not enabled), and creates nothing. Confirm with
`ls -d ~/.dotfiles-backup-* 2>/dev/null` returning nothing.

- [ ] **Step 6: Lint and commit**

```bash
shellcheck -x install/bootstrap.sh
cd ~/.dotfiles
git add install/bootstrap.sh install/tests/bootstrap.bats
git commit -m "feat(install): wire preflight, packages, dotfiles and services phases"
```

---

### Task 8: archinstall configs, plain and encrypted

Stage 0. The destructive half, so it is deliberately thin: it delegates to
`archinstall` and hardcodes no disk.

**Files:**
- Create: `install/archinstall/laptop.json`
- Create: `install/archinstall/laptop-luks.json`
- Create: `install/archinstall/creds.json.example`
- Create: `install/archinstall/README.md`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: nothing
- Produces: two configs consumed as `archinstall --config <file> --creds creds.json`

- [ ] **Step 1: Record the archinstall version being targeted**

```bash
sudo pacman -S --needed archinstall
archinstall --version
```

Write the reported version into the README in Step 5. The config schema differs
between releases; this is the number a future reader checks first when a config
stops loading.

- [ ] **Step 2: Capture this desktop's locale settings to copy**

```bash
localectl status
timedatectl show --property=Timezone --value
```

Use the reported keymap, locale and timezone in both configs below in place of
the values shown, if they differ.

- [ ] **Step 3: Write laptop.json**

```json
{
  "archinstall-language": "English",
  "bootloader": "Systemd-boot",
  "hostname": "laptop",
  "kernels": ["linux", "linux-lts"],
  "locale_config": {
    "kb_layout": "us",
    "sys_enc": "UTF-8",
    "sys_lang": "en_US.UTF-8"
  },
  "network_config": { "type": "nm" },
  "ntp": true,
  "packages": ["git", "stow", "zsh", "sudo", "openssh", "vim"],
  "parallel downloads": 5,
  "profile_config": {
    "gfx_driver": null,
    "greeter": null,
    "profile": { "main": "Minimal" }
  },
  "swap": true,
  "timezone": "America/Lima",
  "disk_config": {
    "config_type": "default_layout",
    "device_modifications": []
  }
}
```

`"device_modifications": []` leaves the disk unset, so `archinstall` prompts for
it. This is intentional and must not be filled in.

- [ ] **Step 4: Write laptop-luks.json**

Identical to `laptop.json` plus the encryption block:

```json
{
  "archinstall-language": "English",
  "bootloader": "Systemd-boot",
  "hostname": "laptop",
  "kernels": ["linux", "linux-lts"],
  "locale_config": {
    "kb_layout": "us",
    "sys_enc": "UTF-8",
    "sys_lang": "en_US.UTF-8"
  },
  "network_config": { "type": "nm" },
  "ntp": true,
  "packages": ["git", "stow", "zsh", "sudo", "openssh", "vim"],
  "parallel downloads": 5,
  "profile_config": {
    "gfx_driver": null,
    "greeter": null,
    "profile": { "main": "Minimal" }
  },
  "swap": true,
  "timezone": "America/Lima",
  "disk_config": {
    "config_type": "default_layout",
    "device_modifications": []
  },
  "disk_encryption": {
    "encryption_type": "luks",
    "partitions": []
  }
}
```

`"partitions": []` means archinstall asks which partition to encrypt — it will
offer root. The passphrase never appears here; it comes from the credentials
file.

- [ ] **Step 5: Write creds.json.example**

```json
{
  "!users": [
    {
      "username": "piero",
      "!password": "CHANGE-ME",
      "sudo": true
    }
  ],
  "!root-password": "CHANGE-ME",
  "!encryption-password": "CHANGE-ME-ONLY-FOR-THE-LUKS-CONFIG"
}
```

- [ ] **Step 6: Gitignore the real credentials file**

Append to `.gitignore`:

```
# archinstall credentials — never commit real passwords
install/archinstall/creds.json
```

- [ ] **Step 7: Write install/archinstall/README.md**

````markdown
# Stage 0 — installing Arch from the ISO

Tested against archinstall **<version from Step 1>**. If a config fails to
load, compare it against `archinstall --dry-run` on the current release; the
schema changes between versions.

## Before you start

Pick the config:

- `laptop.json` — plain ext4 root. Use on machines that never leave the house.
- `laptop-luks.json` — LUKS2-encrypted root, unencrypted `/boot`. Use on the
  laptop.

**The LUKS passphrase cannot be recovered. If you forget it the data is gone.**
Put it in your password manager *before* you start the install. After the first
boot, back up the LUKS header:

```bash
sudo cryptsetup luksHeaderBackup /dev/nvme0n1p2 --header-backup-file luks-header.img
```

Keep that file somewhere other than the laptop. Anyone holding it plus the
passphrase can decrypt the disk.

## Running it

Boot the Arch ISO, connect to the network (`iwctl` for wifi), then:

```bash
pacman -Sy archinstall
curl -LO https://raw.githubusercontent.com/PieroNarciso/Dotfiles/main/install/archinstall/laptop-luks.json
curl -LO https://raw.githubusercontent.com/PieroNarciso/Dotfiles/main/install/archinstall/creds.json.example
mv creds.json.example creds.json
# edit creds.json: set the user password, root password and encryption passphrase
archinstall --config laptop-luks.json --creds creds.json
```

archinstall prompts for the target disk. **Check it against `lsblk` before
confirming — the wrong answer erases the wrong disk.** No device path is stored
in these configs for exactly this reason.

Reboot when it finishes, log in as your user, then run stage 1:

```bash
git clone https://github.com/PieroNarciso/Dotfiles.git ~/.dotfiles
~/.dotfiles/install/bootstrap.sh --dry-run   # read what it plans to do
~/.dotfiles/install/bootstrap.sh
```

## Known limitations

- `/boot` is unencrypted, because systemd-boot reads the kernel and initramfs
  from it. This protects against a stolen disk, not against someone who tampers
  with the machine and returns it. Secure Boot with `sbctl` plus a TPM2
  enrollment with a PIN is the answer to that, and it is not set up here.
- Swap is zram, so **hibernate does not work**. Adding it means a swap
  partition inside the LUKS container plus a `resume` hook in the initramfs.
````

- [ ] **Step 8: Validate both configs are well-formed JSON**

Run:

```bash
jq empty install/archinstall/laptop.json && jq empty install/archinstall/laptop-luks.json && \
jq empty install/archinstall/creds.json.example && echo "all valid"
```

Expected: `all valid`.

- [ ] **Step 9: Confirm no disk path and no secret leaked in**

Run:

```bash
grep -rnE '/dev/(sd|nvme|vd)' install/archinstall/ && echo "FAIL: device path present" || echo "ok: no device paths"
git -C ~/.dotfiles check-ignore -v install/archinstall/creds.json
```

Expected: `ok: no device paths`, and `check-ignore` reporting the rule that
ignores `creds.json`.

- [ ] **Step 10: Commit**

```bash
cd ~/.dotfiles
git add install/archinstall/ .gitignore
git commit -m "feat(install): archinstall configs for plain and LUKS2 layouts"
```

---

### Task 9: Retire Packages-Desktop and document the new entrypoint

**Files:**
- Delete: `Packages-Desktop`
- Modify: `README.md`

**Interfaces:**
- Consumes: everything built above
- Produces: a repo whose README describes the actual install path

- [ ] **Step 1: Confirm nothing references the old file**

Run: `grep -rn "Packages-Desktop" ~/.dotfiles --exclude-dir=.git`
Expected: only `README.md` and the spec/plan under `docs/`. If a script
references it, update that script first.

- [ ] **Step 2: Delete it**

```bash
cd ~/.dotfiles && git rm Packages-Desktop
```

- [ ] **Step 3: Rewrite the README's requirements and install sections**

Replace the `# Requirements` and `# Dotfiles Install` sections with:

```markdown
# Install

Full machine setup, from the Arch ISO onwards, lives in `install/`:

- `install/archinstall/` — stage 0, the base system. Two configs, one plain and
  one with an encrypted root. See `install/archinstall/README.md`.
- `install/bootstrap.sh` — stage 1, everything after the first login: packages,
  dotfiles, services, version managers. Run `--dry-run` first.
- `install/packages/` — the package groups, one file per group.
- `install/pkg-audit.sh` — reports drift between the group files and what is
  actually installed. Run it after installing something new.

Design notes: `docs/superpowers/specs/2026-09-21-arch-laptop-bootstrap-design.md`

## Just the dotfiles, on a machine that already exists

```bash
git clone https://github.com/PieroNarciso/Dotfiles.git ~/.dotfiles
cd ~/.dotfiles && stow --restow --target="$HOME" */
```

The neovim config is a separate repo:

```bash
git clone https://github.com/PieroNarciso/nvim-config.git ~/.nvim-config
cd ~/.nvim-config && stow --restow --target="$HOME" */
```
```

Keep the existing X11 keyboard and mouse-acceleration sections; they still apply
to the desktop.

- [ ] **Step 4: Commit**

```bash
cd ~/.dotfiles
git add README.md
git commit -m "docs: point the README at install/ and drop Packages-Desktop"
```

---

### Task 10: Validate in a VM before touching laptop hardware

Stage 0 erases a disk. It gets proven in a VM first. This task changes no files
in the repo unless it finds a bug — in which case the fix goes back into the
relevant task's files and gets its own commit.

**Files:**
- Modify (only if bugs are found): whichever `install/` file is at fault

**Interfaces:**
- Consumes: everything above
- Produces: evidence that both stages work end to end

- [ ] **Step 1: Push the branch so the VM can clone it**

```bash
cd ~/.dotfiles && git push -u origin feat/install-bootstrap
```

- [ ] **Step 2: Create the VM**

```bash
sudo pacman -S --needed libvirt virt-manager qemu-base
sudo systemctl enable --now libvirtd
# Download the current ISO into ~/Downloads first.
sudo virt-install --name arch-laptop-test --memory 4096 --vcpus 2 \
  --disk size=40 --cdrom ~/Downloads/archlinux-x86_64.iso \
  --os-variant archlinux --boot uefi --graphics spice
```

UEFI boot is required — systemd-boot will not install otherwise.

- [ ] **Step 3: Run stage 0 with the encrypted config**

Inside the VM, follow `install/archinstall/README.md`, using the raw URL of the
`feat/install-bootstrap` branch rather than `main`. Use the LUKS config.

Expected: the install completes, the VM reboots, and boot stops at a passphrase
prompt. Entering the passphrase reaches a login prompt.

- [ ] **Step 4: Verify the encrypted layout**

Inside the VM:

```bash
lsblk -f
sudo cryptsetup status root
```

Expected: `lsblk -f` shows a `crypto_LUKS` partition with an ext4 filesystem
mapped above it, and a separate unencrypted FAT32 `/boot`. `cryptsetup status`
reports `type: LUKS2` and `cipher: aes-xts-plain64`.

- [ ] **Step 5: Run stage 1 as a dry-run**

```bash
git clone -b feat/install-bootstrap https://github.com/PieroNarciso/Dotfiles.git ~/.dotfiles
~/.dotfiles/install/bootstrap.sh --dry-run
```

Expected: exit 0, every phase named, no file created anywhere. Verify with
`ls -a ~`.

- [ ] **Step 6: Run stage 1 for real**

```bash
~/.dotfiles/install/bootstrap.sh
```

Expected: it finishes, prints the manual-steps report, and lists no failed
packages. The VM has no battery, so `tlp` and `thermald` are correctly skipped —
that part is verified on the real laptop instead.

- [ ] **Step 7: Verify the result inside the VM**

```bash
ls -l ~/.zshrc ~/.config/nvim ~/.config/hypr    # all symlinks into the repos
echo "$SHELL"                                    # /usr/bin/zsh after re-login
systemctl is-enabled NetworkManager              # enabled
Hyprland                                         # from a TTY: the session starts
```

Expected: the symlinks point into `~/.dotfiles` and `~/.nvim-config`, the login
shell is zsh, and Hyprland starts with waybar running.

- [ ] **Step 8: Run stage 1 a second time to prove idempotency**

```bash
~/.dotfiles/install/bootstrap.sh
```

Expected: every group reports "up to date", no backup directory is created, the
run exits 0, and `ls -d ~/.dotfiles-backup-* 2>/dev/null` still returns nothing.
This is the single most important check in the plan — it is what makes the
script safe to re-run on the real laptop.

- [ ] **Step 9: Test the backup path deliberately**

```bash
rm ~/.zshrc && echo "hand written" > ~/.zshrc
~/.dotfiles/install/bootstrap.sh
cat ~/.dotfiles-backup-*/.zshrc
```

Expected: the hand-written file is printed from the backup directory, and
`~/.zshrc` is a symlink into the repo again. Nothing was destroyed.

- [ ] **Step 10: Fix anything that broke, then re-run from Step 5**

Any fix belongs in the `install/` file at fault, with its own commit and its own
test in `install/tests/`. Repeat until Steps 5 through 9 pass cleanly on a fresh
VM.

- [ ] **Step 11: Merge**

```bash
cd ~/.dotfiles
git checkout main
git merge --no-ff feat/install-bootstrap -m "feat: two-stage Arch install toolkit"
git push origin main
```

---

### Task 11: Install the laptop

Not a code task. The checklist that turns the toolkit into a working machine.

- [ ] **Step 1: Record the LUKS passphrase in your password manager before starting.** There is no recovery.
- [ ] **Step 2: Boot the Arch ISO on the laptop, connect to wifi with `iwctl`.**
- [ ] **Step 3: Run stage 0 with `laptop-luks.json`. Check the disk against `lsblk` before confirming.**
- [ ] **Step 4: Reboot, log in, run `~/.dotfiles/install/bootstrap.sh --dry-run`, read it, then run it for real.**
- [ ] **Step 5: Back up the LUKS header to another machine** (`cryptsetup luksHeaderBackup`).
- [ ] **Step 6: Verify the laptop-only phases actually fired:**

```bash
systemctl is-enabled tlp thermald
brightnessctl info
```

Expected: both services enabled, and `brightnessctl` reporting the panel's
backlight device. If `tlp` is not enabled, `hw_has_battery` failed — check
`ls /sys/class/power_supply/`.

- [ ] **Step 7: Work through the manual steps the report printed** (SSH keys, SSH remotes, GPG, `~/.aws`, `gh auth login`).
- [ ] **Step 8: Run `install/pkg-audit.sh` on the laptop.** Expected: the *unlisted* column is empty. Anything there is a package you installed by hand during setup — add it to a group file and commit, so the next machine gets it.

---

## Self-Review

**Spec coverage:** Stage 0 plain and LUKS → Task 8. Stage 1's nine phases →
Tasks 2, 3, 5, 6, 7. Curated groups → Task 4. GPU detection, which the spec
implied through microcode but did not spell out → Tasks 3 and 4, added as
`gpu-*.txt` because an AMD desktop's driver set is wrong on an Intel laptop.
Anti-rot audit → Task 5. Testing plan → Task 10. Blockers (unpushed repos) →
Task 1. README and `Packages-Desktop` retirement → Task 9. Risk mitigations
(no device path, gitignored creds, header backup) → Task 8 Steps 6, 7, 9.

**Known gaps, deliberate:** TPM2 auto-unlock, Secure Boot enrollment and
hibernate-on-LUKS are out of scope per the spec and appear only as documented
limitations in the archinstall README.
