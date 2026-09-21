# Laptop install checklist

This is the ordered checklist for installing a new laptop with this toolkit:
stage 0 (`install/archinstall/`) lays down the base system, stage 1
(`install/bootstrap.sh`) does everything after first login. Work through the
steps in order.

- [ ] **Step 1: Record the LUKS passphrase in your password manager before starting.** There is no recovery.
- [ ] **Step 2: Boot the Arch ISO on the laptop, connect to wifi with `iwctl`.**
- [ ] **Step 3: Run stage 0 with `laptop-luks.json`. Check the disk against `lsblk` before confirming.**
  Before you do, run `archinstall --version` on the ISO and write the number
  down — on paper or in your phone. The repo is not cloned yet at this point
  and you are on a ramdisk, so you cannot record it here; Step 11 puts it in
  `install/archinstall/README.md`, where the version is not pinned yet.
- [ ] **Step 4: Destroy the credentials file before rebooting.** `creds.json`
  holds the LUKS passphrase and both account passwords in plaintext. It lives
  on the ISO's ramdisk, so it dies when the machine reboots — but confirm
  that yourself rather than trusting it: check `ls /mnt/creds.json` before
  rebooting and make sure nothing put a copy on the installed disk.
  `install/archinstall/creds.json` is gitignored so it cannot be committed by
  accident, but that is a safety net, not a reason to keep the file around —
  if a `creds.json` is ever created inside the repo checkout, `shred -u` it
  instead of deleting it normally.
- [ ] **Step 5: Reboot, log in, clone the dotfiles repo.** The reboot after
  stage 0 leaves a bare system — nothing has cloned the repo yet, so do it
  before running anything else:

  ```bash
  git clone https://github.com/PieroNarciso/Dotfiles.git ~/.dotfiles
  ```

- [ ] **Step 6: Run `~/.dotfiles/install/bootstrap.sh --dry-run`, read it, then run it for real.**
  Stage 1 moves any pre-existing dotfile that conflicts with the repo into a
  timestamped `~/.dotfiles-backup-*` directory instead of deleting it — if
  something looks missing after the first run, check there first.
- [ ] **Step 7: Back up the LUKS header to another machine** (`cryptsetup luksHeaderBackup`).
- [ ] **Step 8: Verify the laptop-only phases actually fired:**

  ```bash
  systemctl is-enabled tlp thermald
  brightnessctl info
  ```

  Expected: both services enabled, and `brightnessctl` reporting the panel's
  backlight device. If `tlp` is not enabled, `hw_has_battery` failed — check
  `ls /sys/class/power_supply/`. `thermald` is Intel-only: it ships in
  `install/packages/laptop.txt` and gets enabled on any machine with a
  battery, Intel or AMD alike, but on an AMD laptop it has nothing to manage.
  An AMD laptop showing `thermald` enabled but otherwise idle is expected,
  not a failure.
- [ ] **Step 9: Verify GPU detection picked the right driver group.** This
  laptop is likely Intel or AMD, where the desktop this toolkit was built on
  is AMD — confirm the installer's guess matches the real hardware:

  ```bash
  lspci | grep -iE 'vga|3d controller'
  pacman -Qq | grep -E 'xf86-video|mesa|nvidia'
  ```

  An earlier defect in `hw_gpu_vendor` matched `ati` inside the string "VGA
  compatible controller" and mislabelled every Intel GPU as AMD, so treat
  this as a real check, not a formality. What to expect, per
  `install/packages/gpu-*.txt`:
  - **Intel** (`gpu-intel.txt`): `vulkan-intel` installed; no
    `xf86-video-amdgpu`/`xf86-video-ati` and no `nvidia*` packages.
  - **AMD** (`gpu-amd.txt`): `xf86-video-amdgpu` installed (the distinguishing
    package — `xf86-video-ati` is the older KMS-less driver, also listed but
    not the signal to look for).
  - **NVIDIA** (`gpu-nvidia.txt`): `nvidia-open-dkms` installed.
- [ ] **Step 10: Work through the manual steps the report printed** (SSH keys, SSH remotes, GPG, `~/.aws`, `gh auth login`). `phase_report` in `install/bootstrap.sh` prints the full list at the end of the run — work through everything it names.
- [ ] **Step 11: Reconcile the repo with what you actually installed.** Run
  `install/pkg-audit.sh` on the laptop. Expected: the *unlisted* column is
  empty. Anything there is a package you installed by hand during setup — add
  it to a group file so the next machine gets it. Write the archinstall
  version you noted in Step 3 into `install/archinstall/README.md`, replacing
  the "Version not pinned" paragraph. Commit both changes together.
