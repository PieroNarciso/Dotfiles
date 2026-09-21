# Stage 0 — installing Arch from the ISO

Version not pinned. Run `archinstall --version` on the ISO before you start and
write the number here. If a config fails to load, compare it against the schema
of that release; keys change between versions.

## Before you start

**Gate: the VM validation run must pass before stage 0 is run on laptop
hardware.** Install these same configs end to end in a UEFI VM first — see
Step 1 of [`install/LAPTOP-CHECKLIST.md`](../LAPTOP-CHECKLIST.md).

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

**Verify the encryption after the first boot, before anything else.**
`laptop-luks.json` ships `disk_encryption.partitions: []`, so the encryption
target comes from the interactive selection during the install and nothing in
this repo can prove it was applied:

```bash
lsblk -f
sudo cryptsetup status root   # 'root' is the mapper name — use yours from lsblk
```

The root device's FSTYPE must be `crypto_LUKS` and `cryptsetup status` must
report an active LUKS2 device. If it is not, the install was not encrypted and
the only fix is to reinstall — a disk cannot be encrypted in place.

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

See [`install/LAPTOP-CHECKLIST.md`](../LAPTOP-CHECKLIST.md) for the full, ordered checklist from booting the ISO through the post-install verification steps.

## Known limitations

- `/boot` is unencrypted, because systemd-boot reads the kernel and initramfs
  from it. This protects against a stolen disk, not against someone who tampers
  with the machine and returns it. Secure Boot with `sbctl` plus a TPM2
  enrollment with a PIN is the answer to that, and it is not set up here.
- Swap is zram, so **hibernate does not work**. Adding it means a swap
  partition inside the LUKS container plus a `resume` hook in the initramfs.
