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
print('ABSENT' if 'disk_encryption' not in out else 'PRESENT')
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
out = g.build_config(base, {'config_type': 'default_layout'}, None)
print('ABSENT' if 'disk_encryption' not in out else 'LEAKED')
print('BASE_INTACT' if 'disk_encryption' in base else 'BASE_MUTATED')
" "$GEN"
    [ "${lines[0]}" = "ABSENT" ]
    [ "${lines[1]}" = "BASE_INTACT" ]
}

@test "build_config with encryption keeps the partition id it was handed" {
    run python3 -c "
import importlib.util, sys, json
spec = importlib.util.spec_from_file_location('g', sys.argv[1])
g = importlib.util.module_from_spec(spec); spec.loader.exec_module(g)
enc = {'encryption_type': 'luks', 'partitions': ['abc-123'], 'lvm_volumes': []}
out = g.build_config({}, {'config_type': 'default_layout'}, enc)
print(out['disk_encryption']['partitions'][0])
print(out['disk_encryption']['encryption_type'])
" "$GEN"
    [ "${lines[0]}" = "abc-123" ]
    [ "${lines[1]}" = "luks" ]
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
