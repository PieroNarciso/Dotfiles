#!/usr/bin/env bats

setup() {
    REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    GEN="$REPO/install/archinstall/make-disk-config.py"
}

@test "the generator exists and is executable" {
    [ -x "$GEN" ]
}

@test "confirm_device accepts the exact device path" {
    run python3 -c "
import importlib.util, sys
spec = importlib.util.spec_from_file_location('g', sys.argv[1])
g = importlib.util.module_from_spec(spec); spec.loader.exec_module(g)
print('YES' if g.confirm_device('/dev/nvme0n1', '/dev/nvme0n1') else 'NO')
" "$GEN"
    [ "$status" -eq 0 ]
    [ "$output" = "YES" ]
}

@test "confirm_device rejects a different device" {
    run python3 -c "
import importlib.util, sys
spec = importlib.util.spec_from_file_location('g', sys.argv[1])
g = importlib.util.module_from_spec(spec); spec.loader.exec_module(g)
print('YES' if g.confirm_device('/dev/sda', '/dev/nvme0n1') else 'NO')
" "$GEN"
    [ "$output" = "NO" ]
}

@test "confirm_device rejects surrounding whitespace only after stripping" {
    run python3 -c "
import importlib.util, sys
spec = importlib.util.spec_from_file_location('g', sys.argv[1])
g = importlib.util.module_from_spec(spec); spec.loader.exec_module(g)
print('YES' if g.confirm_device('  /dev/sda \n', '/dev/sda') else 'NO')
" "$GEN"
    [ "$output" = "YES" ]
}

@test "build_config without encryption carries no disk_encryption key" {
    run python3 -c "
import importlib.util, sys, json
spec = importlib.util.spec_from_file_location('g', sys.argv[1])
g = importlib.util.module_from_spec(spec); spec.loader.exec_module(g)
out = g.build_config({'hostname': 'laptop'}, {'config_type': 'default_layout'}, None)
print('ABSENT' if 'disk_encryption' not in out and 'disk_encryption' not in out['disk_config'] else 'PRESENT')
print(out['hostname'])
" "$GEN"
    [ "${lines[0]}" = "ABSENT" ]
    [ "${lines[1]}" = "laptop" ]
}

@test "build_config drops a stale disk_encryption inherited from the base" {
    # The test above passes a base that never had the key, so it cannot tell
    # "strips a stale block" from "does nothing at all" — deleting the pop()
    # would still pass it. Reusing a previously generated config as --base
    # without --encrypt is the real case: the inherited block would point at
    # partition ids the new layout does not contain.
    run python3 -c "
import importlib.util, sys
spec = importlib.util.spec_from_file_location('g', sys.argv[1])
g = importlib.util.module_from_spec(spec); spec.loader.exec_module(g)
base = {
    'hostname': 'laptop',
    'disk_encryption': {
        'encryption_type': 'luks',
        'partitions': ['stale-id-from-a-previous-run'],
        'lvm_volumes': [],
    },
}
out = g.build_config(base, {'config_type': 'default_layout', 'disk_encryption': {'partitions': ['stale']}}, None)
print('ABSENT' if 'disk_encryption' not in out and 'disk_encryption' not in out['disk_config'] else 'LEAKED')
print('BASE_INTACT' if 'disk_encryption' in base else 'BASE_MUTATED')
" "$GEN"
    [ "${lines[0]}" = "ABSENT" ]
    [ "${lines[1]}" = "BASE_INTACT" ]
}

@test "build_config puts encryption inside disk_config, not at the deprecated top level" {
    # archinstall 4.4 marks the top-level disk_encryption DEPRECATED
    # (args.py); DiskLayoutConfiguration.parse_arg reads disk_config's own.
    # A release that drops the old path would ignore a top-level block and
    # install without encryption, with no error.
    run python3 -c "
import importlib.util, sys, json
spec = importlib.util.spec_from_file_location('g', sys.argv[1])
g = importlib.util.module_from_spec(spec); spec.loader.exec_module(g)
enc = {'encryption_type': 'luks', 'partitions': ['abc-123'], 'lvm_volumes': []}
dc = {'config_type': 'default_layout'}
out = g.build_config({}, dc, enc)
print(out['disk_config']['disk_encryption']['partitions'][0])
print(out['disk_config']['disk_encryption']['encryption_type'])
print('TOPLEVEL' if 'disk_encryption' in out else 'NESTED_ONLY')
print('INPUT_MUTATED' if 'disk_encryption' in dc else 'INPUT_CLEAN')
" "$GEN"
    [ "${lines[0]}" = "abc-123" ]
    [ "${lines[1]}" = "luks" ]
    [ "${lines[2]}" = "NESTED_ONLY" ]
    [ "${lines[3]}" = "INPUT_CLEAN" ]
}

@test "build_config never mutates the base dict it was given" {
    run python3 -c "
import importlib.util, sys
spec = importlib.util.spec_from_file_location('g', sys.argv[1])
g = importlib.util.module_from_spec(spec); spec.loader.exec_module(g)
base = {'hostname': 'laptop'}
g.build_config(base, {'config_type': 'default_layout'}, None)
print('CLEAN' if 'disk_config' not in base else 'MUTATED')
" "$GEN"
    [ "$output" = "CLEAN" ]
}

@test "the committed base config carries no encryption block at all" {
    REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    run python3 -c "
import json, sys
cfg = json.load(open(sys.argv[1]))
enc = cfg.get('disk_encryption')
print('EMPTY_PARTITIONS' if enc is not None and not enc.get('partitions') else 'OK')
" "$REPO/install/archinstall/laptop.json"
    [ "$output" = "OK" ]
}

@test "the retype prompt does not contain the answer it is asking for" {
    # A prompt that prints the device path makes "retyping" a copy from the
    # line above. Reverting to the f-string version means either this constant
    # disappears (error) or a device path appears in it (ECHOES).
    run python3 -c "
import importlib.util, sys
spec = importlib.util.spec_from_file_location('g', sys.argv[1])
g = importlib.util.module_from_spec(spec); spec.loader.exec_module(g)
p = g.CONFIRM_PROMPT
print('ECHOES' if ('/dev' in p or '{' in p) else 'PLAIN')
" "$GEN"
    [ "$status" -eq 0 ]
    [ "$output" = "PLAIN" ]
}

@test "_describe tags the encrypted root and prints every partition" {
    run python3 -c "
import importlib.util, sys
spec = importlib.util.spec_from_file_location('g', sys.argv[1])
g = importlib.util.module_from_spec(spec); spec.loader.exec_module(g)
cfg = {'device_modifications': [{'device': '/dev/testdisk', 'wipe': True, 'partitions': [
    {'status': 'create', 'size': {'value': 1, 'unit': 'GiB'}, 'fs_type': 'fat32', 'mountpoint': '/boot'},
    {'status': 'create', 'size': {'value': 40, 'unit': 'GiB'}, 'fs_type': 'ext4', 'mountpoint': '/'},
]}]}
print(g._describe(cfg, True))
" "$GEN"
    [ "$status" -eq 0 ]
    [[ "$output" == *"/dev/testdisk"* ]]
    [[ "$output" == *"/boot"* ]]
    [[ "$output" == *"[LUKS2]"* ]]
    # The tag belongs to the root line, not the ESP line.
    [[ "$(grep -F '[LUKS2]' <<< "$output")" == *" /"* ]]
    [[ "$(grep -F '/boot' <<< "$output")" != *"[LUKS2]"* ]]
}

@test "_describe says so when it cannot find the root it was asked to tag" {
    # _describe reads the serialized dict while _generate picks the root off
    # live archinstall objects. If that key ever serializes differently the
    # dump would silently drop the tag -- the operator's only pre-erase view
    # degrading without a word. Simulated here by a renamed key.
    run python3 -c "
import importlib.util, sys
spec = importlib.util.spec_from_file_location('g', sys.argv[1])
g = importlib.util.module_from_spec(spec); spec.loader.exec_module(g)
cfg = {'device_modifications': [{'device': '/dev/testdisk', 'wipe': True, 'partitions': [
    {'status': 'create', 'size': {'value': 40, 'unit': 'GiB'}, 'fs_type': 'ext4', 'mount_point': '/'},
]}]}
print(g._describe(cfg, True))
" "$GEN"
    [ "$status" -eq 0 ]
    [[ "$output" == *"no root partition to tag"* ]]
}

@test "_describe stays quiet about LUKS when encryption was not asked for" {
    run python3 -c "
import importlib.util, sys
spec = importlib.util.spec_from_file_location('g', sys.argv[1])
g = importlib.util.module_from_spec(spec); spec.loader.exec_module(g)
cfg = {'device_modifications': [{'device': '/dev/testdisk', 'wipe': True, 'partitions': [
    {'status': 'create', 'size': {'value': 40, 'unit': 'GiB'}, 'fs_type': 'ext4', 'mountpoint': '/'},
]}]}
print(g._describe(cfg, False))
" "$GEN"
    [ "$status" -eq 0 ]
    [[ "$output" != *"LUKS"* ]]
}

@test "the layout dump prints sizes a human can check against lsblk" {
    # Found by the live VM run: archinstall sizes the ESP in GiB but the
    # "rest of the disk" root partition in raw bytes, so the dump read
    # "1GiB" beside "41873833984B". That dump is the operator's main defence
    # against erasing the wrong disk, and an 11-digit byte count is skimmed,
    # not checked.
    run python3 -c "
import importlib.util, sys
spec = importlib.util.spec_from_file_location('g', sys.argv[1])
g = importlib.util.module_from_spec(spec); spec.loader.exec_module(g)
cfg = {'device_modifications': [{'device': '/dev/vda', 'wipe': True, 'partitions': [
    {'status': 'create', 'size': {'value': 1, 'unit': 'GiB'}, 'fs_type': 'fat32', 'mountpoint': '/boot'},
    {'status': 'create', 'size': {'value': 41873833984, 'unit': 'B'}, 'fs_type': 'ext4', 'mountpoint': '/'},
]}]}
print(g._describe(cfg, True))
" "$GEN"
    [ "$status" -eq 0 ]
    [[ "$output" == *"39.0GiB"* ]]
    [[ "$output" != *"41873833984"* ]]
    # A size already in sensible units is left exactly as it was.
    [[ "$output" == *"1GiB"* ]]
}

@test "_human_size leaves units it cannot convert alone" {
    run python3 -c "
import importlib.util, sys
spec = importlib.util.spec_from_file_location('g', sys.argv[1])
g = importlib.util.module_from_spec(spec); spec.loader.exec_module(g)
print(g._human_size({'value': 2048, 'unit': 'sectors'}))
print(g._human_size({'value': 512, 'unit': 'B'}))
print(g._human_size({}))
" "$GEN"
    [ "${lines[0]}" = "2048sectors" ]
    [ "${lines[1]}" = "512B" ]
    [ "${lines[2]}" = "?" ]
}

# A stand-in archinstall 4.4 on PYTHONPATH, shaped like the real objects the
# generator touches, so main() runs end to end without a real disk or root.
# The dist-info is what importlib.metadata reads the version from.
_stub_archinstall() { # <version>
    local root="$BATS_TEST_TMPDIR/stub"
    mkdir -p "$root/archinstall/lib/disk" "$root/archinstall/lib/models" "$root/archinstall-$1.dist-info"
    printf 'Metadata-Version: 2.1\nName: archinstall\nVersion: %s\n' "$1" > "$root/archinstall-$1.dist-info/METADATA"
    touch "$root/archinstall/__init__.py" "$root/archinstall/lib/__init__.py" \
          "$root/archinstall/lib/disk/__init__.py" "$root/archinstall/lib/models/__init__.py"
    cat > "$root/archinstall/lib/models/device.py" <<'PY'
from enum import Enum
class FilesystemType(Enum):
    EXT4 = "ext4"
    FAT32 = "fat32"
class DiskLayoutType(Enum):
    Default = "default_layout"
class Size:
    def __init__(self, text): self.text = text
    def format_highest(self): return self.text
class _Info:
    def __init__(self, **kw): self.__dict__.update(kw)
class _Part:
    def __init__(self, obj_id, mountpoint, fs, size):
        self.obj_id, self.mountpoint, self.fs, self.size = obj_id, mountpoint, fs, size
    def json(self):
        return {"obj_id": self.obj_id, "status": "create", "size": self.size,
                "fs_type": self.fs, "mountpoint": self.mountpoint}
class _Mod:
    def __init__(self, device, parts): self.device, self.partitions = device, parts
class DiskLayoutConfiguration:
    def __init__(self, config_type, device_modifications):
        self.t, self.mods = config_type, device_modifications
    def json(self):
        return {"config_type": self.t.value, "device_modifications": [
            {"device": m.device, "wipe": True, "partitions": [p.json() for p in m.partitions]}
            for m in self.mods]}
PY
    cat > "$root/archinstall/lib/disk/device_handler.py" <<'PY'
from pathlib import Path
from archinstall.lib.models.device import _Info, Size, FilesystemType
class _Dev:
    def __init__(self, path, model):
        self.device_info = _Info(path=Path(path), model=model, total_size=Size("476.9 GiB"))
        self.partition_infos = [_Info(path=Path(path + "p1"), length=Size("512.0 MiB"),
                                      fs_type=FilesystemType.FAT32, mountpoints=[])]
class _Handler:
    devices = []
    def load_devices(self):
        self.devices = [_Dev("/dev/testdisk", "STUB NVMe 512GB")]
device_handler = _Handler()
PY
    cat > "$root/archinstall/lib/disk/disk_menu.py" <<'PY'
from archinstall.lib.models.device import _Mod, _Part
async def suggest_single_disk_layout(dev, fs, separate_home=False):
    return _Mod(str(dev.device_info.path), [
        _Part("esp-id", "/boot", "fat32", {"value": 1, "unit": "GiB"}),
        _Part("root-id", "/", "ext4", {"value": 41873833984, "unit": "B"})])
PY
    STUB_PATH="$root"
}

_gen() { # <stdin> <args...>
    local input="$1"; shift
    printf '%s' "$input" | PYTHONPATH="$STUB_PATH" python3 "$GEN" "$@"
}

@test "main writes an encrypted config after the device is retyped" {
    _stub_archinstall 4.4
    cd "$BATS_TEST_TMPDIR"
    echo '{"hostname": "laptop"}' > base.json
    run _gen $'/dev/testdisk\n' --device /dev/testdisk --encrypt --base base.json -o out.json
    [ "$status" -eq 0 ]
    [[ "$output" == *"STUB NVMe 512GB"* ]]
    [[ "$output" == *"/dev/testdiskp1"* ]]
    [[ "$output" == *"[LUKS2]"* ]]
    python3 -c "
import json; c = json.load(open('out.json'))
assert c['hostname'] == 'laptop'
assert c['disk_config']['disk_encryption']['partitions'] == ['root-id']
assert 'disk_encryption' not in c
"
}

@test "an aborted run removes the config an earlier run left behind" {
    # The Step 4 block runs archinstall --silent on install-config.json right
    # after the generator. An abort that left the previous file in place
    # handed archinstall a config for whatever disk the previous run named.
    _stub_archinstall 4.4
    cd "$BATS_TEST_TMPDIR"
    echo '{"PREVIOUS RUN": "/dev/sda"}' > out.json
    run _gen $'/dev/wrong\n' --device /dev/testdisk --encrypt -o out.json
    [ "$status" -eq 1 ]
    [[ "$output" == *"aborted; nothing written"* ]]
    [ ! -e out.json ]
}

@test "EOF at the confirmation prompt aborts cleanly and leaves no config" {
    _stub_archinstall 4.4
    cd "$BATS_TEST_TMPDIR"
    echo '{"PREVIOUS RUN": "/dev/sda"}' > out.json
    run _gen '' --device /dev/testdisk -o out.json
    [ "$status" -eq 1 ]
    [[ "$output" == *"aborted; nothing written"* ]]
    [[ "$output" != *"Traceback"* ]]
    [ ! -e out.json ]
}

@test "an archinstall other than the verified release is refused before the dump" {
    _stub_archinstall 4.5
    cd "$BATS_TEST_TMPDIR"
    echo '{"PREVIOUS RUN": "/dev/sda"}' > out.json
    run _gen $'/dev/testdisk\n' --device /dev/testdisk -o out.json
    [ "$status" -eq 1 ]
    [[ "$output" == *"archinstall 4.5"* ]]
    [[ "$output" == *"--archinstall-version-verified 4.5"* ]]
    [[ "$output" != *"ERASE"* ]]
    [ ! -e out.json ]
}

@test "the version override only counts for the version actually running" {
    _stub_archinstall 4.5
    cd "$BATS_TEST_TMPDIR"
    run _gen $'/dev/testdisk\n' --device /dev/testdisk -o out.json --archinstall-version-verified 4.6
    [ "$status" -eq 1 ]
    [ ! -e out.json ]
    run _gen $'/dev/testdisk\n' --device /dev/testdisk -o out.json --archinstall-version-verified 4.5
    [ "$status" -eq 0 ]
    [ -f out.json ]
}

@test "a removable target is called out in the dump" {
    run python3 -c "
import importlib.util, sys
spec = importlib.util.spec_from_file_location('g', sys.argv[1])
g = importlib.util.module_from_spec(spec); spec.loader.exec_module(g)
print(g._describe_device({'path': '/dev/sdb', 'model': 'SanDisk', 'size': '28.6 GiB',
    'removable': True, 'partitions': [{'path': '/dev/sdb1', 'size': '1.2 GiB',
    'fs_type': 'iso9660', 'mountpoints': ['/run/archiso/bootmnt']}]}))
" "$GEN"
    [ "$status" -eq 0 ]
    [[ "$output" == *"REMOVABLE"* ]]
    [[ "$output" == *"/run/archiso/bootmnt"* ]]
}

@test "--base and -o naming the same file is refused before it is deleted" {
    _stub_archinstall 4.4
    cd "$BATS_TEST_TMPDIR"
    echo '{"hostname": "laptop"}' > laptop.json
    run _gen $'/dev/testdisk\n' --device /dev/testdisk --base laptop.json -o laptop.json
    [ "$status" -ne 0 ]
    [ "$(cat laptop.json)" = '{"hostname": "laptop"}' ]
}

@test "there is no flag that skips the confirmation" {
    run python3 "$GEN" --help
    [[ "$output" != *"no-confirm"* ]]
}
