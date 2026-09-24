#!/usr/bin/env python3
"""Generate a complete archinstall disk config for one named device.

archinstall 4.4 can only express encryption against partitions that are
themselves declared (DiskEncryption.__post_init__ raises on an empty
partitions list), so a config that encrypts must also lay out the disk. This
script produces that config for a device the user names on the ISO, which
keeps the device path out of the repository while still emitting something
fully declarative.

Run it on the Arch ISO, where archinstall is installed.
"""

import argparse
import asyncio
import json
import sys

# archinstall is imported inside main() so the pure helpers below stay
# importable — and testable — on a machine that does not have it.


def confirm_device(typed: str, expected: str) -> bool:
    """True when the user retyped the device path they are about to erase."""
    return typed.strip() == expected.strip()


def build_config(base: dict, disk_config: dict, enc: dict | None) -> dict:
    """Merge a generated layout into a base config without touching the base."""
    out = dict(base)
    out["disk_config"] = disk_config
    if enc is not None:
        out["disk_encryption"] = enc
    else:
        out.pop("disk_encryption", None)
    return out


async def _generate(device_path: str, encrypt: bool) -> tuple[dict, dict | None]:
    from archinstall.lib.disk.device_handler import device_handler
    from archinstall.lib.disk.disk_menu import suggest_single_disk_layout
    from archinstall.lib.models.device import (
        DiskLayoutConfiguration,
        DiskLayoutType,
        FilesystemType,
    )

    device_handler.load_devices()
    try:
        dev = next(
            d for d in device_handler.devices
            if str(d.device_info.path) == device_path
        )
    except StopIteration:
        raise SystemExit(f"no such block device: {device_path}")

    mod = await suggest_single_disk_layout(
        dev, FilesystemType.EXT4, separate_home=False
    )
    layout = DiskLayoutConfiguration(
        config_type=DiskLayoutType.Default, device_modifications=[mod]
    )

    enc = None
    if encrypt:
        roots = [p for p in mod.partitions if str(p.mountpoint) == "/"]
        if not roots:
            raise SystemExit("generated layout has no root partition to encrypt")
        enc = {
            "encryption_type": "luks",
            "partitions": [roots[0].obj_id],
            "lvm_volumes": [],
        }

    return layout.json(), enc


def _describe(disk_config: dict, encrypt: bool) -> str:
    lines = []
    for mod in disk_config.get("device_modifications", []):
        lines.append(f"  {mod['device']}  (wipe: {mod.get('wipe')})")
        for part in mod.get("partitions", []):
            size = part.get("size", {})
            enc_tag = ""
            if encrypt and part.get("mountpoint") == "/":
                enc_tag = "  [LUKS2]"
            lines.append(
                "    {:<8} {:>6} {:<6} {}{}".format(
                    part.get("status", ""),
                    f"{size.get('value', '?')}{size.get('unit', '')}",
                    part.get("fs_type", ""),
                    part.get("mountpoint") or "-",
                    enc_tag,
                )
            )
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--device", required=True, help="target block device, e.g. /dev/nvme0n1")
    ap.add_argument("--encrypt", action="store_true", help="LUKS2-encrypt the root partition")
    ap.add_argument("--base", default=None, help="base config JSON to merge into")
    ap.add_argument("-o", "--output", required=True, help="where to write the config")
    ap.add_argument(
        "--no-confirm",
        action="store_true",
        help="skip the retype confirmation (for automated validation runs only)",
    )
    args = ap.parse_args()

    disk_config, enc = asyncio.run(_generate(args.device, args.encrypt))

    print(f"\nThis will ERASE {args.device} and lay it out as:\n")
    print(_describe(disk_config, args.encrypt))
    print()

    if not args.no_confirm:
        typed = input(f"Retype {args.device} to confirm, or anything else to abort: ")
        if not confirm_device(typed, args.device):
            print("aborted; nothing written", file=sys.stderr)
            return 1

    base = {}
    if args.base:
        with open(args.base) as fh:
            base = json.load(fh)

    out = build_config(base, disk_config, enc)
    with open(args.output, "w") as fh:
        json.dump(out, fh, indent=2)
        fh.write("\n")

    print(f"wrote {args.output}")
    if args.encrypt:
        print("remember: the passphrase goes in creds.json under 'encryption_password'")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
