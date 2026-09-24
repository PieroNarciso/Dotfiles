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
import os
import sys

# archinstall is imported inside main() so the pure helpers below stay
# importable — and testable — on a machine that does not have it.


# The prompt must NOT contain the device path. A prompt that prints the answer
# turns "retype it" into "copy the line above", which catches a typo between
# reading and typing and nothing else. The layout dump above it is the part
# that can catch the wrong *disk*; this only confirms you read the dump.
CONFIRM_PROMPT = "Retype the target device path to confirm, or anything else to abort: "


# The release every archinstall import below was verified against. They reach
# into private modules (disk_menu, device_handler), so a different release can
# break them -- or, worse, silently generate a different config. The ISO's
# `pacman -Sy archinstall` installs whatever is current, not this.
TESTED_ARCHINSTALL = "4.4"


def version_problem(detected: str | None, accepted: str | None) -> str | None:
    """Why this archinstall must not be trusted, or None when it may be.

    `accepted` is the operator saying "I re-verified the keys against exactly
    this release"; it only counts when it names the version actually running.
    """
    if detected == TESTED_ARCHINSTALL:
        return None
    if detected is not None and accepted == detected:
        return None
    shown = detected or "an unknown version"
    return (
        f"this ISO has archinstall {shown}; this script was verified against "
        f"{TESTED_ARCHINSTALL}.\nRe-verify the config keys against that release "
        f"(install/archinstall/README.md), then re-run with "
        f"--archinstall-version-verified {detected or '<version>'}"
    )


def _archinstall_version() -> str | None:
    from importlib.metadata import PackageNotFoundError, version
    try:
        return version("archinstall")
    except PackageNotFoundError:
        return None


def confirm_device(typed: str, expected: str) -> bool:
    """True when the user retyped the device path they are about to erase."""
    return typed.strip() == expected.strip()


def build_config(base: dict, disk_config: dict, enc: dict | None) -> dict:
    """Merge a generated layout into a base config without touching the base."""
    out = dict(base)
    out["disk_config"] = dict(disk_config)
    # A top-level disk_encryption is 4.4's DEPRECATED location (args.py marks
    # it so); disk_config.disk_encryption is the one DiskLayoutConfiguration
    # parses itself. If a release drops the old path, a top-level block would
    # be ignored and the install would silently come out unencrypted. Strip
    # any the base carries -- a stale one names partition ids this layout
    # does not have.
    out.pop("disk_encryption", None)
    out["disk_config"].pop("disk_encryption", None)
    if enc is not None:
        out["disk_config"]["disk_encryption"] = enc
    return out


def _describe_device(info: dict) -> str:
    """What is on the disk now: the part that tells one disk from another.

    The planned layout is archinstall's fixed default (1GiB ESP, the rest as
    root), so two disks of similar size produce the same dump. The model,
    the transport and what is about to be destroyed are what differ -- and
    the live ISO's own USB stick is still offered as a target.
    """
    lines = [f"  {info['path']}  {info['model'] or '(no model)'}  {info['size']}"]
    if info.get("removable"):
        lines.append("  REMOVABLE -- is this the USB stick you booted from?")
    parts = info.get("partitions", [])
    if not parts:
        lines.append("    (no partitions)")
    for p in parts:
        mounts = ",".join(p["mountpoints"]) or "-"
        lines.append(f"    {p['path']:<18} {p['size']:>9} {p['fs_type'] or '?':<8} {mounts}")
    return "\n".join(lines)


def _device_facts(dev) -> dict:
    name = os.path.basename(str(dev.device_info.path))
    try:
        with open(f"/sys/block/{name}/removable") as fh:
            removable = fh.read().strip() == "1"
    except OSError:
        removable = False
    return {
        "path": str(dev.device_info.path),
        "model": dev.device_info.model,
        "size": dev.device_info.total_size.format_highest(),
        "removable": removable,
        "partitions": [
            {
                "path": str(p.path),
                "size": p.length.format_highest(),
                "fs_type": p.fs_type.value if p.fs_type else None,
                "mountpoints": [str(m) for m in p.mountpoints],
            }
            for p in dev.partition_infos
        ],
    }


async def _generate(device_path: str, encrypt: bool) -> tuple[dict, dict | None, dict]:
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

    return layout.json(), enc, _device_facts(dev)


def _human_size(size: dict) -> str:
    """Render a serialized partition size so a human can check it against lsblk.

    archinstall sizes the ESP in GiB but the "rest of the disk" root partition
    in raw bytes, so the layout dump printed `1GiB` beside `41873833984B`.
    That dump is the operator's main defence against erasing the wrong disk,
    and an eleven-digit byte count is not something anyone checks against
    `lsblk` -- it just gets skimmed.
    """
    value = size.get("value")
    unit = size.get("unit", "")
    if value is None:
        return "?"
    if unit == "B" and isinstance(value, (int, float)):
        for suffix, factor in (("TiB", 1 << 40), ("GiB", 1 << 30),
                               ("MiB", 1 << 20), ("KiB", 1 << 10)):
            if value >= factor:
                return f"{value / factor:.1f}{suffix}"
    return f"{value}{unit}"


def _describe(disk_config: dict, encrypt: bool) -> str:
    """Render the serialized layout for the operator to read before erasing.

    Reads `layout.json()`, a plain dict, while _generate() picks the root
    partition off the live archinstall objects. The two accessors can drift:
    if a future archinstall serializes `mountpoint` differently this walk
    silently prints blanks and drops the [LUKS2] tag while the generated
    config stays correct. The trailing note below makes that drift visible
    rather than letting the one pre-erase view degrade in silence.
    """
    lines = []
    tagged = 0
    for mod in disk_config.get("device_modifications", []):
        lines.append(f"  {mod['device']}  (wipe: {mod.get('wipe')})")
        for part in mod.get("partitions", []):
            size = part.get("size", {})
            enc_tag = ""
            if encrypt and part.get("mountpoint") == "/":
                enc_tag = "  [LUKS2]"
                tagged += 1
            lines.append(
                "    {:<8} {:>9} {:<6} {}{}".format(
                    part.get("status", ""),
                    _human_size(size),
                    part.get("fs_type", ""),
                    part.get("mountpoint") or "-",
                    enc_tag,
                )
            )
    if encrypt and tagged == 0:
        lines.append(
            "  NOTE: this dump found no root partition to tag [LUKS2]. The config"
        )
        lines.append(
            "  is built from the live disk objects and is unaffected -- but read"
        )
        lines.append(
            "  the layout above carefully, and verify encryption after first boot."
        )
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--device", required=True, help="target block device, e.g. /dev/nvme0n1")
    ap.add_argument("--encrypt", action="store_true", help="LUKS2-encrypt the root partition")
    ap.add_argument("--base", default=None, help="base config JSON to merge into")
    ap.add_argument("-o", "--output", required=True, help="where to write the config")
    ap.add_argument(
        "--archinstall-version-verified",
        metavar="VERSION",
        default=None,
        help=f"run on an archinstall other than {TESTED_ARCHINSTALL}, after re-verifying the keys against it",
    )
    args = ap.parse_args()

    if args.base and os.path.exists(args.output) and os.path.samefile(args.base, args.output):
        raise SystemExit("--base and -o are the same file; the base would be lost")

    # Remove any config an earlier run left behind BEFORE anything can fail.
    # Otherwise an abort here leaves the old one in place, and the archinstall
    # line after it -- which runs with --silent, no prompt -- erases whatever
    # disk that old config named.
    if os.path.lexists(args.output):
        os.remove(args.output)
        print(f"removed {args.output} from an earlier run")

    problem = version_problem(_archinstall_version(), args.archinstall_version_verified)
    if problem:
        print(problem, file=sys.stderr)
        return 1

    disk_config, enc, facts = asyncio.run(_generate(args.device, args.encrypt))

    print("\nThis disk, as it is now -- everything on it will be destroyed:\n")
    print(_describe_device(facts))
    print("\nIt will be ERASED and laid out as:\n")
    print(_describe(disk_config, args.encrypt))
    print()

    try:
        typed = input(CONFIRM_PROMPT)
    except (EOFError, KeyboardInterrupt):
        typed = ""
        print()
    if not confirm_device(typed, args.device):
        print("aborted; nothing written", file=sys.stderr)
        return 1

    base = {}
    if args.base:
        with open(args.base) as fh:
            base = json.load(fh)

    out = build_config(base, disk_config, enc)
    # Written whole or not at all: a partial file is a config archinstall
    # might half-parse.
    tmp = f"{args.output}.tmp"
    with open(tmp, "w") as fh:
        json.dump(out, fh, indent=2)
        fh.write("\n")
    os.replace(tmp, args.output)

    print(f"wrote {args.output}")
    if args.encrypt:
        print("remember: the passphrase goes in creds.json under 'encryption_password'")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
