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
- [ ] **Step 4: Run stage 0.** Nothing you need is on the ISO yet — the repo is
  not cloned at this point — so fetch the installer and the three files first:

  ```bash
  pacman -Sy archinstall
  archinstall --version    # write this number down on paper or in your phone
  curl -LO https://raw.githubusercontent.com/PieroNarciso/Dotfiles/main/install/archinstall/laptop.json
  curl -LO https://raw.githubusercontent.com/PieroNarciso/Dotfiles/main/install/archinstall/creds.json.example
  curl -LO https://raw.githubusercontent.com/PieroNarciso/Dotfiles/main/install/archinstall/make-disk-config.py
  mv creds.json.example creds.json
  ```

  Edit `creds.json` and set all three secrets: the user password, the root
  password, and `encryption_password`. That last one is the LUKS passphrase
  from Step 2 and must match it exactly, or the disk will not unlock.

  Then read the target disk off `lsblk`, generate the disk config against it,
  retype the device path when the generator asks to confirm, and hand the
  result to archinstall:

  ```bash
  lsblk
  python make-disk-config.py --device /dev/nvme0n1 --encrypt \
      --base laptop.json -o install-config.json
  archinstall --config install-config.json --creds creds.json --silent
  ```

  The generator prints the layout it is about to write before it asks you to
  retype the device path. Read that layout — sizes and mountpoints against
  what `lsblk` showed. The retype prompt does not name the device, so it
  catches a typo between reading and typing; it cannot catch a wrong decision
  about which disk to erase. The layout dump can.

  It is also the last confirmation you get: `--silent` suppresses every
  prompt archinstall would otherwise show before writing partitions.

  Record the `archinstall --version` number off-machine: the repo is not
  cloned yet and you are on a ramdisk, so there is nowhere here to keep it.
  Step 13 compares it against the version pinned in
  `install/archinstall/README.md`.
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

  # Run this from the directory holding the creds.json you edited in Step 4.
  pass=$(python3 -c 'import json;print(json.load(open("creds.json"))["encryption_password"])')
  if [ -z "$pass" ]; then
      echo "STOP: could not read the passphrase -- this check did NOT run"
  elif printf '%s\n' "$pass" | grep -rlFf - /mnt 2>/dev/null; then
      echo "LEAK: the passphrase is on the installed disk (files listed above)"
  else
      echo "clean: passphrase not found anywhere under /mnt"
  fi
  unset pass
  ```

  Expected: the single line `clean: passphrase not found anywhere under /mnt`.

  Read that line, not the absence of output. An empty pattern makes GNU grep
  match nothing and exit 1 — identical to a clean result — so if the `python3`
  call fails (wrong directory, missing key) a silent version of this check
  would report success without having searched. That is why the passphrase is
  captured first and the empty case stops you explicitly. The value goes
  through a shell variable and `printf`, a builtin, so it never reaches any
  process's argv where `ps` could read it.

  Search for the passphrase itself, not for the word "password". On 4.4
  `install.log` carries two benign lines — `INFO - Setting password for
  piero` and the same for root — with no secret value anywhere. Grepping for
  the word matches those and reports a leak that did not happen, which is
  worse than not checking at all: the next time you see it you will wave it
  through.

  If a real credential ever does land here, `shred -u` the matching files, or
  take the log directory wholesale — nothing after the install needs it:

  ```bash
  find /mnt/var/log/archinstall -type f -exec shred -u {} + \
    && rm -rf /mnt/var/log/archinstall
  ```

  Then confirm no copy of `creds.json` landed on the installed disk, which is
  the thing that would actually matter — `/mnt` is the new system, not the
  ramdisk, so this is the search worth running:

  ```bash
  find /mnt -name 'creds*.json' -o -name 'install-config.json' 2>/dev/null
  ```

  Expected: nothing. The `creds.json` you edited lives in the ISO's own working
  directory and dies with the ramdisk at reboot; it is never copied to `/mnt`.

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

  **Exit 0 is not proof the run did everything.** Three steps warn and carry
  on rather than aborting — `chsh`, enabling a service, and the nvm installer
  — because a failure there used to kill the run before it printed the manual
  steps below. So read the output for `warn:` lines, and check the one that
  cannot be seen any other way:

  ```bash
  grep -c '^warn:' <(install/bootstrap.sh 2>&1)   # or just watch the run
  ```

  Then log out, log back in, and confirm the shell actually changed:

  ```bash
  echo "$SHELL"          # expect /usr/bin/zsh
  ```

  `chsh` asks for your password. If you mistyped it the run still exits 0 and
  you stay on bash. Fix it with `chsh -s /usr/bin/zsh` and log in again.
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
