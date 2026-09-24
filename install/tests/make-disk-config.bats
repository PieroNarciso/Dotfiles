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

@test "the committed laptop-luks.json no longer carries an empty encryption block" {
    REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    run python3 -c "
import json, sys
cfg = json.load(open(sys.argv[1]))
enc = cfg.get('disk_encryption')
print('EMPTY_PARTITIONS' if enc is not None and not enc.get('partitions') else 'OK')
" "$REPO/install/archinstall/laptop-luks.json"
    [ "$output" = "OK" ]
}
