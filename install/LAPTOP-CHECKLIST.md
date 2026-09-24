# Laptop install checklist

This is the ordered checklist for installing a new laptop with this toolkit:
stage 0 (`install/archinstall/`) lays down the base system, stage 1
(`install/bootstrap.sh`) does everything after first login. Work through the
steps in order.

- [ ] **Step 1: Gate — the VM validation run must pass before stage 0 touches the laptop.**
  This is not a suggestion: the design makes it a hard gate ("Stage 0 is not
  run on laptop hardware until the VM run passes").
  Install
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
  not cloned at this point — so fetch the three files first, and check the
  ISO's archinstall:

  ```bash
  curl -LO https://raw.githubusercontent.com/PieroNarciso/Dotfiles/main/install/archinstall/laptop.json
  curl -LO https://raw.githubusercontent.com/PieroNarciso/Dotfiles/main/install/archinstall/creds.json.example
  curl -LO https://raw.githubusercontent.com/PieroNarciso/Dotfiles/main/install/archinstall/make-disk-config.py
  mv creds.json.example creds.json
  archinstall --version    # the version the ISO ships; may be replaced below
  ```

  The generator only runs on the archinstall release it was verified against
  (see `install/archinstall/README.md`). If the version above is not that
  release, install it from the Arch archive — not `pacman -Sy archinstall`,
  which pulls whatever is current:

  ```bash
  pacman -U --noconfirm https://archive.archlinux.org/packages/a/archinstall/archinstall-4.4-1-any.pkg.tar.zst
  archinstall --version    # write THIS number down -- the final one the generator enforced
  ```

  If that archived build will not start (the ISO's Python has moved past
  it), boot an ISO from the month it was current instead:
  <https://archive.archlinux.org/iso/>. Do not reach for the generator's
  override flag until you have re-verified the config keys against the
  release you are on — on a spare machine or the VM, not by guessing.

  Edit `creds.json` and set all three secrets: the user password, the root
  password, and `encryption_password`. That last one is the LUKS passphrase
  from Step 2 and must match it exactly, or the disk will not unlock. The
  generator refuses to run while any of them is empty or still `CHANGE-ME…`:
  archinstall reads an empty passphrase as "do not encrypt", and the
  placeholder is published in the repository.

  Then read the target disk off `lsblk`, generate the disk config against it,
  retype the device path when the generator asks to confirm, and hand the
  result to archinstall. **Three separate commands — run them one at a
  time.** Pasted as one block, the generator reads the pasted archinstall
  line as your answer to its retype prompt and aborts.

  ```bash
  lsblk -o NAME,SIZE,MODEL,TRAN,RM,FSTYPE,MOUNTPOINTS
  ```

  The internal disk is the one with `TRAN` `nvme` (or `sata`). Anything with
  `TRAN` `usb` is external — the stick you booted from, or a USB SSD, which
  `RM` does not flag.

  ```bash
  python make-disk-config.py --device /dev/nvme0n1 --encrypt \
      --base laptop.json --creds creds.json -o install-config.json
  ```

  Before you retype anything, read what the generator printed:

  - First the disk as it is now — model, size, and every partition that is
    about to be destroyed. Match the model and size against `lsblk`. If it
    says `REMOVABLE`, you have almost certainly named the USB stick you
    booted from.
  - Then the layout it will write. Check sizes and mountpoints against what
    `lsblk` showed. The retype prompt does not name the device, so it
    catches a typo between reading and typing; it cannot catch a wrong
    decision about which disk to erase. The dump can.
  - **The root line must carry a `[LUKS2]` tag.** That tag is the only
    pre-erase evidence that `--encrypt` took effect — a dropped or mistyped
    flag produces a perfectly valid config for an *unencrypted* disk, and the
    next chance to notice is Step 7, where the only fix is to reinstall. If
    the generator prints `NOTE: this dump found no root partition to tag
    [LUKS2]`, stop and work out why before erasing anything.

  This is also the last confirmation you get: `--silent` suppresses every
  prompt archinstall would otherwise show before writing partitions.

  Run archinstall only if the generator ended with `wrote install-config.json`.
  It deletes any `install-config.json` from an earlier run before it starts,
  so after an abort there is nothing for archinstall to find — but do not
  plug or unplug a USB device between the two commands: the config names the
  disk by its kernel name, and `/dev/sda` can become a different disk.

  ```bash
  archinstall --config install-config.json --creds creds.json --silent
  ```

  Record the `archinstall --version` number off-machine: the repo is not
  cloned yet and you are on a ramdisk, so there is nowhere here to keep it.
  The generator already enforced it before erasing anything; Step 13 is
  where you note it in `install/archinstall/README.md` if it was a new
  release you verified.
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
  canary="creds-check-canary-$$"
  printf '%s\n' "$canary" > /mnt/root/.creds-check-canary
  if [ -z "$pass" ]; then
      echo "STOP: could not read the passphrase -- this check did NOT run"
  elif ! printf '%s\n' "$canary" | grep -rlFf - /mnt >/dev/null 2>&1; then
      echo "STOP: the search cannot find its own canary -- /mnt is not searchable"
      echo "      (not mounted? wrong path? grep erroring?) this check did NOT run"
  elif printf '%s\n' "$pass" | grep -rlFf - /mnt 2>/dev/null; then
      echo "LEAK: the passphrase is on the installed disk (files listed above)"
  else
      echo "clean: passphrase not found anywhere under /mnt"
  fi
  rm -f /mnt/root/.creds-check-canary
  unset pass canary
  ```

  Expected: the single line `clean: passphrase not found anywhere under /mnt`.

  Read that line, not the absence of output. This check has two ways to look
  clean without having run, and both are guarded:

  - **Empty pattern.** GNU grep given an empty pattern file matches nothing
    and exits 1 — indistinguishable from a clean result. So if the `python3`
    call fails (wrong directory, missing key), the passphrase is captured
    first and the empty case stops you explicitly.
  - **Empty haystack.** A `/mnt` that is not mounted, is the wrong path, or
    that grep cannot read returns exactly the same "no match". So a canary
    file is planted first and searched for: if the search cannot find a string
    it just wrote, it has proved nothing about the passphrase either. The
    canary is removed on the line after.

  The passphrase goes through a shell variable and `printf`, a builtin, so it
  never reaches any process's argv where `ps` could read it.

  **If you get a STOP, do not reboot.** `creds.json` lives on the ramdisk and
  dies with it, and this check can never be run again afterwards. Fix the
  cause and re-run the block:

  - *Wrong directory* — `ls creds.json`; the block must run where you edited it.
  - *`/mnt` not mounted* — archinstall unmounts on completion in some
    versions. Re-mount it (use YOUR devices from `lsblk`):

    ```bash
    cryptsetup open /dev/nvme0n1p2 root   # the passphrase from Step 2
    mount /dev/mapper/root /mnt
    mount /dev/nvme0n1p1 /mnt/boot
    ```

  If you cannot make the check run, that is not the same as passing it. Reboot
  knowing it never ran, and treat Step 7 as the only encryption evidence you have.

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
  ramdisk, so this is the search worth running. **Run it in the same block, so
  it inherits the canary's proof that `/mnt` is searchable at all**; on its own
  its "Expected: nothing" is exactly what an unmounted `/mnt` produces:

  ```bash
  canary="creds-check-canary-$$"
  printf '%s\n' "$canary" > /mnt/root/.creds-check-canary
  if ! printf '%s\n' "$canary" | grep -rlFf - /mnt >/dev/null 2>&1; then
      echo "STOP: /mnt is not searchable — this check did NOT run"
  else
      found=$(find /mnt -name 'creds*.json' -o -name 'install-config.json' -o -name 'user_credentials.json' 2>/dev/null)
      [ -z "$found" ] && echo "clean: no config or credential file on the disk" \
                      || { echo "LEAK: shred these:"; echo "$found"; }
  fi
  rm -f /mnt/root/.creds-check-canary
  unset canary found
  ```

  Expected: `clean: no config or credential file on the disk`. The `creds.json`
  you edited lives in the ISO's own working directory and dies with the
  ramdisk at reboot; it is never copied to `/mnt`.

  `install/archinstall/creds.json` is gitignored so it cannot be committed by
  accident, but that is a safety net, not a reason to keep the file around —
  if a `creds.json` is ever created inside the repo checkout, `shred -u` it
  instead of deleting it normally.
- [ ] **Step 6: Reboot, log in, and get back onto the network.** The `iwctl`
  association from Step 3 lived on the ISO's ramdisk and died with it. Stage 0
  installs NetworkManager (`network_config: {"type": "nm"}` in `laptop.json`)
  and enables it, but it carries **no wifi credentials** — nothing was ever
  told your SSID or password. On a wifi-only laptop you are offline at this
  point, and every step from here on needs the network.

  `iwctl` is not available: `iwd` ships in `install/packages/core.txt`, which
  stage 1 installs, and stage 1 needs the network first. Use `nmcli`:

  ```bash
  systemctl status NetworkManager     # must be active; if not: sudo systemctl enable --now NetworkManager
  sudo nmcli device wifi list
  sudo nmcli --ask device wifi connect "YOUR-SSID"
  ping -c3 archlinux.org
  ```

  Two details that both matter here, because this is the one recipe standing
  between you and an offline laptop:

  - **`--ask` goes before `device`.** `nmcli [OPTIONS] OBJECT { COMMAND }` —
    it is a global option, and in an argument position nmcli rejects it. It is
    what keeps the wifi password out of your shell history, so the natural
    retry after a syntax error is the one that leaks it.
  - **`sudo` on the `connect`.** Reading (`device status`, `wifi list`) works
    as your user; *changing* anything does not, and fails with
    `Error: ... Insufficient privileges`. polkit itself happens to be on the
    system — pulled in as a dependency of `pcsclite`, not deliberately — but
    nothing is running a polkit *authentication agent* to answer the prompt:
    that arrives with `polkit-gnome` in stage 1, which needs the network this
    step is creating. Verified on a real install, not assumed.

  Do not continue until `ping` succeeds. On ethernet this is usually already
  done for you, but check rather than assume.
- [ ] **Step 6b: Clone the dotfiles repo.** The reboot leaves a bare system —
  nothing has cloned the repo yet, so do it before running anything else:

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

  Run it once, to a log you can read afterwards — do not run it a second time
  just to count warnings, and do not wrap it in `<(...)`: that swallows the
  manual steps Step 12 depends on, and hides the password prompts `chsh` and
  `sudo` will ask you for.

  ```bash
  ~/.dotfiles/install/bootstrap.sh 2>&1 | tee ~/bootstrap.log
  grep -c '^warn:' ~/bootstrap.log     # how many steps warned
  grep '^warn:' ~/bootstrap.log        # and which ones
  ```

  Then log out, log back in, and confirm the shell actually changed:

  ```bash
  echo "$SHELL"          # expect /usr/bin/zsh
  ```

  `chsh` asks for your password. If you mistyped it the run still exits 0 and
  you stay on bash. Fix it with `chsh -s /usr/bin/zsh` and log in again.
- [ ] **Step 8b: Reboot, and confirm the machine still boots.** Stage 1 is the
  only thing in this toolkit that rewrites the systemd-boot loader entries —
  `phase_microcode` adds the `initrd /amd-ucode.img` (or `intel-`) line. An
  entry naming an initrd that is not on the ESP does not boot, and you will
  not find that out at any other point in this checklist.

  **Every read here needs `sudo`.** archinstall mounts the ESP `dmask=0077`,
  so `/boot` is mode 700 and root-owned on the machine you just installed —
  an unprivileged `cat` returns "Permission denied", not the file. (`lib/boot.sh`
  puts `sudo` in front of every ESP read for exactly this reason. A desktop
  mounted `dmask=0022` reads it fine as the user, which is how this was
  wrong here in the first place.)

  The glob has to be expanded by the *privileged* shell, not yours. `sudo cat
  /boot/loader/entries/*.conf` fails: your shell tries to expand the pattern
  first, cannot read the directory, and never reaches sudo — silently under
  bash, and with `zsh: no matches found` under the zsh that Step 8 just made
  your login shell.

  ```bash
  sudo sh -c 'cat /boot/loader/entries/*.conf'   # microcode initrd must come FIRST
  sudo sh -c 'ls -la /boot/*.img'                # the image it names must exist
  ```

  Expected: every entry has `initrd /amd-ucode.img` (or `intel-`) *above* its
  `initrd /initramfs-...` line, and that `.img` appears in the listing.

  Check the two against each other by hand: for every `initrd /X.img` line,
  `X.img` must appear in the `ls`. systemd-boot will not boot an entry naming
  an initrd that is not there. Then:

  ```bash
  sudo reboot
  ```

  **The reboot is the verification.** If it comes back up, the entries are
  good. Do not go looking for a confirming line in the journal: on a machine
  whose firmware already carries microcode newer than the package, the kernel
  prints only `microcode: Current revision: 0x...` and no update line at all,
  and that is correct, not a failure. (`journalctl -b | grep -i microcode`
  matches that `Current revision` line on every machine, so it passes whether
  or not the microcode was loaded — it proves nothing.) If you want the real
  signal, it is `microcode: Updated early from:`, and its absence is not a
  fault.

  **If it does not boot**, the entry is on the *unencrypted* ESP, so you do
  not need to unlock the root filesystem to fix it. At the systemd-boot menu
  `e` only edits the kernel command line — it cannot remove an `initrd` line —
  so recover from the Arch ISO instead:

  ```bash
  # boot the ISO, then (use YOUR device from lsblk):
  mount /dev/nvme0n1p1 /mnt          # the ESP alone, no LUKS unlock needed
  grep -H initrd /mnt/loader/entries/*.conf
  sed -i -E '/^initrd[[:space:]]+\/(amd|intel)-ucode\.img$/d' /mnt/loader/entries/*.conf
  grep -H initrd /mnt/loader/entries/*.conf   # only the initramfs lines left
  umount /mnt
  ```

  There is no `arch.conf`: archinstall names its entries
  `<install-time>_linux.conf` and `<install-time>_linux-lts.conf`, and stage 1
  edited both, so both need the line removed. The glob is safe here — the ISO
  shell is root, so it can read the ESP.

  Stage 1 also copied each original entry to
  `~/.dotfiles-backup-*/loader-entries/` before editing it, but that path is
  on the LUKS root — reachable only after `cryptsetup open`, so it is the
  slower route, not the first one.
- [ ] **Step 9: Back up the LUKS header to another machine.** Use your root
  partition from `lsblk` (the `crypto_LUKS` one):

  ```bash
  sudo cryptsetup luksHeaderBackup /dev/nvme0n1p2 --header-backup-file ~/luks-header.img
  sudo chown "$USER": ~/luks-header.img   # cryptsetup writes it root-owned, mode 0400
  ```

  Copy `~/luks-header.img` off the laptop, then delete it here. A header
  backup plus the passphrase opens the disk, so keep it with the same care.
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
  pacman -Qqe | grep -E 'vulkan|xf86-video|nvidia|mesa|intel-media|libva'
  ```

  Two things about that command:

  - The pattern has to cover all three groups. An earlier version matched only
    `xf86-video|mesa|nvidia`, which cannot match a single package in
    `gpu-intel.txt` — it reported nothing on exactly the hardware it was
    written to check.
  - `-Qqe` (**e**xplicitly installed), not `-Qq`. `linux-firmware` in
    `core.txt` hard-depends on `linux-firmware-nvidia`, so a plain `-Qq`
    reports an nvidia package on every machine including yours, flatly
    contradicting the "no `nvidia*` packages" expectation below. Driver
    packages are installed explicitly by the toolkit; firmware split-packages
    are pulled in as dependencies and `-Qqe` leaves them out.

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
  - **Hybrid** (an Intel or AMD iGPU plus an NVIDIA "3D controller" in
    `lspci`): both lists' signal packages installed. The iGPU usually drives
    the internal panel, so missing `vulkan-intel` there is the defect to look
    for.
- [ ] **Step 12: Work through the manual steps the report printed** (SSH keys, SSH remotes, GPG, `~/.aws`, `gh auth login`). `phase_report` in `install/bootstrap.sh` prints the full list at the end of the run — work through everything it names.
- [ ] **Step 13: Reconcile the repo with what you actually installed.** Run
  `~/.dotfiles/install/pkg-audit.sh` on the laptop. It prints two columns and they mean
  different things:

  - ***unlisted*** — installed here, recorded in no group file. Each one is a
    package you installed by hand during setup; add it to a group file so the
    next machine gets it.
  - ***missing*** — listed in a group that applies to this machine, not
    installed. Usually a package that failed during stage 1; cross-check it
    against the `warn:` lines in `~/bootstrap.log` from Step 8.

  The audit skips what cannot apply: `optional/` (opt-in by definition), the
  `gpu-*.txt` for hardware this machine does not have, and `laptop.txt` when
  there is no battery. It says which ones it skipped. If Step 4 ran on a
  newer archinstall that you verified and let through with
  `--archinstall-version-verified`, bump all four places the version is
  pinned: `TESTED_ARCHINSTALL` in `make-disk-config.py`, the "Verified
  against" line in `install/archinstall/README.md`, the archive URL in that
  same README, and the archive URL in Step 4 of this checklist. Commit the
  four changes together.
