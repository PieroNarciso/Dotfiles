# Arch Laptop Bootstrap — Design

Date: 2026-09-21
Status: approved design, pending implementation plan
Repo: `github.com/PieroNarciso/Dotfiles`

## Goal

Reproduce this desktop's Arch Linux environment (zsh, neovim, Hyprland, dev
tooling) on a new laptop, starting from the Arch ISO, with as few manual steps
as possible and with an option for full-disk encryption.

## Non-goals

- Replacing GNU stow with another dotfile manager (chezmoi, yadm).
- Managing more than two machines. If a third appears, revisit Ansible.
- Syncing secrets (SSH keys, GPG keys, `~/.aws`, `~/.gitconfig-bsale`). Those
  are transferred by hand.
- Syncing application state or data (browser profiles, Obsidian vaults, music
  projects).

## Current state (audited 2026-09-21)

- `~/.dotfiles` is a GNU stow tree: `config/`, `home/`, `tmux/`, `vim/`,
  `scripts/`, `Xresources/`, `local/`. Remote is HTTPS.
- Neovim config is a **separate** repo, `~/.nvim-config`, remote
  `git@github.com:PieroNarciso/nvim-config.git` (SSH), stowed from
  `nvim-config/.config/nvim`.
- 200 explicitly-installed native packages, 10 AUR packages, AUR helper `paru`.
- Compositor is Hyprland; shell is zsh with no framework (plain zsh plus the
  distro's `zsh-autosuggestions`, `zsh-syntax-highlighting`,
  `zsh-history-substring-search` packages, plus starship).
- `Packages-Desktop` in the repo root is stale: last touched January 2024, 233
  entries, and contains desktop-only packages (`amd-ucode`, `apache`,
  VirtualBox, audio-production tooling).

### Blockers to clear before the laptop is built

1. `Dotfiles` is 12 commits ahead of `origin/main`, with uncommitted changes in
   `config/.config/hypr/hyprland.lua` and `config/.config/hypr/hyprlock.conf`.
2. `nvim-config` has uncommitted changes in `init.lua`, `lua/plugins.lua`,
   `lua/nv-tree/init.lua`, `lua/nv-treesitter/init.lua`.

A clone on the laptop only sees pushed commits, so both repos must be committed
and pushed first. The implementation plan makes this its first step.

## Decisions

| Decision | Choice | Reason |
| --- | --- | --- |
| Install method | `archinstall` with a JSON config, then a userland script | The partitioning and bootloader path is the destructive part; use the upstream-maintained tool for it rather than a hand-rolled `sgdisk`/`pacstrap` script. |
| Script location | `install/` inside the existing Dotfiles repo | One repo to clone; the script and the configs it installs version together. |
| Script language | Bash, idempotent, re-runnable | No extra runtime to install first. |
| Package selection | Curated groups, generated from live `pacman -Qqe` | The desktop has hardware- and hobby-specific packages the laptop does not need. |
| Disk encryption | Optional, selected by which archinstall config is used | Laptops get stolen; the desktop does not need the boot-time passphrase. |
| Version managers | `nvm` and `pyenv` only | `.zshrc` already guards every other manager (`rbenv`, `rvm`, `gvm`, `encore`, gcloud SDK) behind existence checks, so their absence is silent. |

## Architecture

Two stages with a reboot between them.

```
Arch ISO
  └─ stage 0: archinstall --config install/archinstall/laptop[-luks].json
       ├─ disk layout, LUKS (optional), filesystem, systemd-boot
       ├─ locale, keymap, timezone, hostname
       ├─ NetworkManager, user account, sudo
       └─ minimal package set
  reboot, log in as the user
  └─ stage 1: install/bootstrap.sh
       ├─ preflight, microcode, paru
       ├─ package groups
       ├─ dotfiles (stow) + nvim config
       ├─ shell, services, version managers
       └─ report of remaining manual steps
```

### Repository layout

```
install/
├── bootstrap.sh                   # stage 1 entrypoint
├── pkg-audit.sh                   # drift check, see "Anti-rot"
├── archinstall/
│   ├── laptop.json                # plain layout
│   ├── laptop-luks.json           # LUKS2-encrypted root
│   └── README.md                  # how to run each, and the credentials file
├── lib/
│   ├── log.sh                     # info/warn/error/step, --dry-run aware
│   ├── pkg.sh                     # pacman/paru wrappers, always --needed
│   └── hw.sh                      # CPU vendor, GPU, battery, LUKS detection
└── packages/
    ├── core.txt                   # zsh, starship, fzf, ripgrep, bat, tmux,
    │                              # neovim, stow, git, the zsh plugin packages
    ├── dev.txt                    # language toolchains, docker, gh, ...
    ├── desktop.txt                # hyprland, waybar, dunst, rofi, alacritty,
    │                              # kitty, pipewire stack, portals, fonts deps
    ├── fonts.txt
    ├── laptop.txt                 # tlp, thermald, brightnessctl,
    │                              # libinput-gestures, bluez, bluez-utils
    ├── aur.txt                    # brave-bin, visual-studio-code-bin,
    │                              # zen-browser-bin, ...
    └── optional/
        ├── audio-prod.txt         # ardour, guitarix, yabridge, ...
        ├── gaming.txt
        └── virt.txt               # libvirt, virtualbox, ...
```

Group files are generated during implementation by classifying the live
`pacman -Qqe` and `pacman -Qqem` output, not by copying `Packages-Desktop`.
Every explicit package must land in exactly one group, and the classification
gets reviewed before it is committed. `Packages-Desktop` is deleted in the same
change, with the README updated to point at `install/`.

## Stage 0 — installation from the ISO

Two configs, identical except for encryption. Both are run the same way:

```bash
# on the booted Arch ISO, after connecting to the network
pacman -Sy archinstall
curl -LO https://raw.githubusercontent.com/PieroNarciso/Dotfiles/main/install/archinstall/laptop-luks.json
archinstall --config laptop-luks.json
```

### Disk selection is interactive, always

Neither config hardcodes a disk device. `archinstall` prompts for the target
disk, and the operator confirms it against `lsblk`. A repo file that names
`/dev/nvme0n1` is a repo file that eventually wipes the wrong machine.

### Layout, unencrypted (`laptop.json`)

| Partition | Size | Filesystem | Mount |
| --- | --- | --- | --- |
| EFI system | 1 GiB | FAT32 | `/boot` |
| root | rest of disk | ext4 | `/` |

### Layout, encrypted (`laptop-luks.json`)

| Partition | Size | Contents | Mount |
| --- | --- | --- | --- |
| EFI system | 1 GiB | FAT32, **unencrypted** | `/boot` |
| root | rest of disk | LUKS2 container, ext4 inside | `/` |

- `/boot` cannot be encrypted with systemd-boot, so kernel and initramfs stay
  readable on disk. This is the standard tradeoff and it is accepted here; it
  means the setup resists disk theft, not an attacker who can tamper with the
  machine and hand it back (an "evil maid" attack). Secure Boot plus a TPM2
  enrollment with a PIN is the mitigation, and it is an optional post-step, not
  part of this design.
- The LUKS passphrase is supplied through `archinstall`'s credentials file
  (`--creds`), never through the config committed to the repo. The repo ships
  `creds.json.example` with empty values and `.gitignore`s `creds.json`.
- Swap: both configs use **zram**, not a swap partition. This keeps the
  encrypted layout to a single container and avoids a second keyslot. It also
  means **hibernate (suspend-to-disk) does not work**. If hibernate turns out to
  matter on the laptop, the fix is a swap partition inside the LUKS container
  plus a `resume` hook, and that is a follow-up change, not part of this one.
- `archinstall`'s config schema changes between releases. The implementation
  step pins the `archinstall` version the configs were written for in
  `install/archinstall/README.md`, and validates both configs in a VM before
  either is trusted on hardware.

Everything else both configs set: `systemd-boot`, `en_US.UTF-8` locale, the
keymap and timezone taken from this machine, hostname prompted, NetworkManager
enabled, the user account created with sudo via `wheel`, and the `minimal`
profile — no desktop environment, because stage 1 installs Hyprland.

## Stage 1 — `bootstrap.sh`

```bash
git clone https://github.com/PieroNarciso/Dotfiles.git ~/.dotfiles
~/.dotfiles/install/bootstrap.sh            # default groups
~/.dotfiles/install/bootstrap.sh --dry-run  # print every action, change nothing
```

Flags: `--dry-run`, `--groups core,dev,desktop,laptop`, `--skip-dotfiles`,
`--help`. Default group set is `core,dev,desktop,laptop`; the optional groups
are opt-in.

### Phases

1. **Preflight.** Refuse to run if: not Arch (`/etc/arch-release` missing), run
   as root, no network, no `sudo`. Ask for sudo once up front and keep the
   timestamp alive for the duration.
2. **Microcode.** Read `vendor_id` from `/proc/cpuinfo`, install `intel-ucode`
   or `amd-ucode` accordingly, and regenerate the boot entry. This is the one
   package the desktop's list gets wrong for a laptop.
3. **paru.** If absent, clone `https://aur.archlinux.org/paru.git` into a temp
   directory and `makepkg -si`. Requires `base-devel` and `git`, installed in
   the preceding step.
4. **Packages.** For each selected group, `pacman -S --needed --noconfirm` the
   native list; AUR entries go through `paru -S --needed`. `--needed` makes
   re-runs cheap. A failing package is reported and skipped rather than
   aborting the run; the summary at the end lists every failure.
5. **Dotfiles.** Clone both repos over **HTTPS** — a fresh laptop has no SSH
   key yet:
   - `Dotfiles` → `~/.dotfiles` (already there if the user cloned it to get
     this script; the phase then just pulls)
   - `nvim-config` → `~/.nvim-config`

   Then `stow -t "$HOME" */` in each. Before stowing, any existing real file
   that stow would collide with is **moved** to
   `~/.dotfiles-backup-<timestamp>/` preserving its relative path, and the move
   is logged. Nothing is ever deleted or overwritten in place.
6. **Shell.** `chsh -s /usr/bin/zsh` if the login shell is not already zsh.
7. **Services.** Enable and start: `NetworkManager`, `bluetooth`, and — when
   the `laptop` group is selected and a battery is present — `tlp` and
   `thermald`. `tlp` conflicts with `power-profiles-daemon`; the script
   installs only `tlp` and asserts the other is absent.
8. **Version managers.** `nvm` into `$NVM_DIR` (`~/.nvm`) and
   `pyenv` into `~/.pyenv`, each skipped if the directory already exists. Both
   are already guarded in `.zshrc`, so no shell config changes are needed.
9. **Report.** Print what is left to do by hand, because none of it can be
   automated safely: transfer SSH and GPG keys, then switch both repo remotes
   from HTTPS to SSH; copy `~/.aws`, `~/.gitconfig-bsale`, `~/.gitconfig-pws`;
   authenticate `gh` and gcloud; install any optional group that was skipped.

### Idempotency rules

Every phase must be safe to run twice. Concretely: package installs use
`--needed`; clones check for an existing repo and pull instead; `stow` is run
with `--restow`; `chsh` is conditional on the current shell; `systemctl enable
--now` is naturally idempotent; version-manager installs check for their
target directory. `--dry-run` must exercise the same code path, printing each
command instead of running it.

## Anti-rot: `pkg-audit.sh`

`Packages-Desktop` drifted for two years because nothing compared it to
reality. `install/pkg-audit.sh` prints the two-way difference between the live
`pacman -Qqe` / `pacman -Qqem` output and the union of the group files:

- **Unlisted** — installed explicitly but in no group file. Either add it to a
  group or mark it deliberately local.
- **Missing** — listed in a group file but not installed here.

It exits non-zero when either set is non-empty, so it can be wired into a
pre-push hook later if that proves useful. Running it is a manual habit for
now.

## Testing

1. `bootstrap.sh --dry-run` on this desktop. Expected: no changes, and the
   printed plan matches what is already installed.
2. `pkg-audit.sh` on this desktop. Expected: empty diff once the group files
   are generated.
3. Both archinstall configs in a VM (`virt-install` against the current Arch
   ISO), including a full reboot and, for `laptop-luks.json`, a passphrase
   unlock at boot. **Stage 0 is not run on laptop hardware until the VM run
   passes**, because a wrong disk layout destroys the target disk.
4. `bootstrap.sh` for real inside the VM after stage 0, then a second run of it
   to confirm idempotency: the second run should install nothing and report no
   changes.

## Risks

| Risk | Mitigation |
| --- | --- |
| Stage 0 wipes the wrong disk | Disk is chosen interactively in archinstall and confirmed against `lsblk`; no device path in the repo. |
| Lost LUKS passphrase means lost data | The README states plainly that there is no recovery; recommends recording the passphrase in a password manager before the install, and `cryptsetup luksHeaderBackup` after it. |
| `archinstall` schema drift breaks the configs | Pin the tested version in the README; the VM run is the gate. |
| Laptop clone is stale | Push both repos first; this is step one of the plan. |
| Group classification misplaces a package | The generated groups are reviewed before commit, and `pkg-audit.sh` catches anything dropped. |

## Out of scope, noted for later

- TPM2 auto-unlock with a PIN (`systemd-cryptenroll`) and Secure Boot.
- Hibernate on the encrypted layout (swap partition inside LUKS plus `resume`).
- Per-machine config divergence in the dotfiles (monitor layouts in Hyprland
  will differ between desktop and laptop). If that becomes painful, it is the
  argument for revisiting chezmoi templating.
