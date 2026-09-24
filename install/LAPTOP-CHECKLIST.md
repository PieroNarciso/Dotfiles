# Laptop install checklist

This is the ordered checklist for installing a new laptop with this toolkit:
stage 0 (`install/archinstall/`) lays down the base system, stage 1
(`install/bootstrap.sh`) does everything after first login. Work through the
steps in order.

- [ ] **Step 1: Gate — the VM validation run must pass before stage 0 touches the laptop.**
  This is not a suggestion: the design makes it a hard gate ("Stage 0 is not
  run on laptop hardware until the VM run passes",
  `docs/superpowers/specs/2026-09-21-arch-laptop-bootstrap-design.md`). Install
  the same configs end to end in a UEFI VM on a machine you already have —
  systemd-boot needs UEFI, so a BIOS VM proves nothing:

  ```bash
  virt-install --name arch-bootstrap-vm --memory 4096 --vcpus 2 \
    --disk size=40 --cdrom ~/Downloads/archlinux-x86_64.iso --boot uefi
  ```

  The run passes when stage 0 finishes, the VM reboots unaided into the
  installed system, and `install/bootstrap.sh --dry-run` followed by a real
  run both exit 0. Anything that fails there fails on the laptop too, where
  the disk is not disposable. Do not start Step 2 until it passes.
- [ ] **Step 2: Record the LUKS passphrase in your password manager before starting.** There is no recovery.
- [ ] **Step 3: Boot the Arch ISO on the laptop, connect to wifi with `iwctl`.**
- [ ] **Step 4: Run stage 0.** Read the target disk off `lsblk`, generate the
  disk config against it, retype the device path when the generator asks to
  confirm, then hand the result to archinstall:

  ```bash
  lsblk
  python make-disk-config.py --device /dev/nvme0n1 --encrypt \
      --base laptop-luks.json -o install-config.json
  archinstall --config install-config.json --creds creds.json --silent
  ```

  Before you do, run `archinstall --version` on the ISO and write the number
  down — on paper or in your phone. The repo is not cloned yet at this point
  and you are on a ramdisk, so you cannot record it here; Step 13 compares it
  against the version pinned in `install/archinstall/README.md`.
- [ ] **Step 5: Verify no credentials leaked into the installed system before rebooting.**
  `creds.json` holds the LUKS passphrase and both account passwords in
  plaintext. It lives on the ISO's ramdisk, so it dies when the machine
  reboots. archinstall 4.4 copies only `install.log` — no credentials — into
  the *installed* system under `/mnt/var/log/archinstall/`, but that is worth
  checking rather than trusting silently, since the passphrase is what
  protects the disk and a copy stored on that disk would defeat the
  encryption entirely. Before you reboot:

  ```bash
  ls -la /mnt/var/log/archinstall/
  grep -rl 'password\|passphrase' /mnt/var/log/archinstall/ 2>/dev/null
  ```

  Expected: the `grep` finds nothing. If a future archinstall release ever
  does copy a credential here, `shred -u` the matching files, or take the log
  directory wholesale — nothing after the install needs it:

  ```bash
  find /mnt/var/log/archinstall -type f -exec shred -u {} + \
    && rm -rf /mnt/var/log/archinstall
  ```

  Then check the ramdisk path as a second belt, because it costs nothing:
  `ls /mnt/creds.json`.

  `install/archinstall/creds.json` is gitignored so it cannot be committed by
  accident, but that is a safety net, not a reason to keep the file around —
  if a `creds.json` is ever created inside the repo checkout, `shred -u` it
  instead of deleting it normally.
- [ ] **Step 6: Reboot, log in, clone the dotfiles repo.** The reboot after
  stage 0 leaves a bare system — nothing has cloned the repo yet, so do it
  before running anything else:

  ```bash
  git clone https://github.com/PieroNarciso/Dotfiles.git ~/.dotfiles
  ```

- [ ] **Step 7: Verify the disk actually came out encrypted.** Do this before
  running anything else. Step 4 ran `make-disk-config.py` against the device
  read off `lsblk`, made you retype it to confirm, and only then handed
  archinstall a config that declares LUKS2 encryption against the root
  partition it just laid out. This step confirms that declaration actually
  took effect — the failure mode is a laptop you believe is encrypted and is
  not.

  ```bash
  lsblk -f
  sudo cryptsetup status root   # 'root' is the mapper name — use yours from lsblk
  ```

  Expected: the root device's FSTYPE is `crypto_LUKS`, and `cryptsetup status`
  reports an active LUKS2 device. **If root is not `crypto_LUKS` the install
  was not encrypted. The only fix is to reinstall — a disk cannot be encrypted
  in place.** Stop here and redo stage 0 rather than carrying on onto an
  unencrypted laptop.
- [ ] **Step 8: Run `~/.dotfiles/install/bootstrap.sh --dry-run`, read it, then run it for real.**
  Stage 1 moves any pre-existing dotfile that conflicts with the repo into a
  timestamped `~/.dotfiles-backup-*` directory instead of deleting it — if
  something looks missing after the first run, check there first.
- [ ] **Step 9: Back up the LUKS header to another machine** (`cryptsetup luksHeaderBackup`).
- [ ] **Step 10: Verify the laptop-only phases actually fired:**

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
- [ ] **Step 11: Verify GPU detection picked the right driver group.** This
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
- [ ] **Step 12: Work through the manual steps the report printed** (SSH keys, SSH remotes, GPG, `~/.aws`, `gh auth login`). `phase_report` in `install/bootstrap.sh` prints the full list at the end of the run — work through everything it names.
- [ ] **Step 13: Reconcile the repo with what you actually installed.** Run
  `install/pkg-audit.sh` on the laptop. Expected: the *unlisted* column is
  empty. Anything there is a package you installed by hand during setup — add
  it to a group file so the next machine gets it. Compare the archinstall
  version you noted in Step 4 against the version pinned in
  `install/archinstall/README.md`; if it differs, update the pinned version
  there. Commit both changes together.
