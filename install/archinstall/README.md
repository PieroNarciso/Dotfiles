# Stage 0 — installing Arch from the ISO

Verified against **archinstall 4.4** (Arch ISO 2026.09.01). Run
`archinstall --version` on your ISO; if it differs, re-verify the config keys
against that release before trusting them.

## Before you start

**Gate: the VM validation run must pass before stage 0 is run on laptop
hardware.** Install these same configs end to end in a UEFI VM first — see
Step 1 of [`install/LAPTOP-CHECKLIST.md`](../LAPTOP-CHECKLIST.md).

There is one base config, `laptop.json`. It carries everything that is not
disk layout: hostname, locale, kernels, packages, bootloader.

**Encryption is not in that file.** It comes from the `--encrypt` flag you pass
to `make-disk-config.py`, which is what writes the `disk_encryption` block
against the partition it just declared. There used to be a second file named
`laptop-luks.json`; it was removed because it had become byte-identical to this
one, and a name ending in `-luks` that does not itself encrypt anything is the
worst kind of documentation — you would have trusted it and got a plaintext
disk. Pass `--encrypt`, or you get plain ext4.

**The LUKS passphrase cannot be recovered. If you forget it the data is gone.**
Put it in your password manager *before* you start the install. After the first
boot, back up the LUKS header:

```bash
sudo cryptsetup luksHeaderBackup /dev/nvme0n1p2 --header-backup-file luks-header.img
```

Keep that file somewhere other than the laptop. Anyone holding it plus the
passphrase can decrypt the disk.

**Verify the encryption after the first boot, before anything else.** The
config declares the encryption up front — the generator writes
`disk_encryption.partitions` against the root partition it just laid out — so
this step confirms the declaration was actually applied, not that it happened
at all:

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
curl -LO https://raw.githubusercontent.com/PieroNarciso/Dotfiles/main/install/archinstall/laptop.json
curl -LO https://raw.githubusercontent.com/PieroNarciso/Dotfiles/main/install/archinstall/creds.json.example
curl -LO https://raw.githubusercontent.com/PieroNarciso/Dotfiles/main/install/archinstall/make-disk-config.py
mv creds.json.example creds.json
# edit creds.json: set the user password, root password and encryption_password

lsblk    # find the target disk and read it twice
python make-disk-config.py --device /dev/nvme0n1 --encrypt \
    --base laptop.json -o install-config.json

archinstall --config install-config.json --creds creds.json --silent
```

The generator prints the partition layout it is about to write, then asks you
to retype the device path. **Read the layout, not the prompt.** The prompt no
longer names the device — retyping it catches a slip between reading `lsblk`
and typing, and nothing more; it cannot catch a wrong decision about which
disk to erase. The layout dump, with its sizes and mountpoints, is what tells
you whether this is the right disk.

That dump is also the last thing you see. `archinstall --silent` suppresses
every confirmation archinstall would otherwise show, so nothing after this
point asks again before the partitions are written.

Reboot when it finishes and log in as your user. **You will have no wifi.**
`network_config: {"type": "nm"}` installs and enables NetworkManager but
carries no credentials, and the ISO's `iwctl` association died with the
ramdisk. `iwd` itself arrives in stage 1, which needs the network first, so
reconnect with `nmcli` before anything else:

```bash
sudo nmcli --ask device wifi connect "YOUR-SSID"
ping -c3 archlinux.org
```

`--ask` is a global option and must come before `device`, and `sudo` is
required because polkit — what lets a non-root user control networking — is
only an optional dependency of networkmanager and is not installed by
stage 0.

Then run stage 1:

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
- The generator uses archinstall's own default single-disk layout (1G FAT32
  ESP at `/boot`, ext4 root over the rest, no separate `/home`). Change it by
  editing the generated JSON before running archinstall, not by editing the
  base config.
