#!/usr/bin/env bats

load test_helper

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "hw_cpu_vendor detects intel" {
    printf 'processor\t: 0\nvendor_id\t: GenuineIntel\n' > "$TEST_TMPDIR/cpuinfo"
    run bash -c "source '$INSTALL_DIR/lib/hw.sh'; HW_CPUINFO='$TEST_TMPDIR/cpuinfo' hw_cpu_vendor"
    [ "$output" = "intel" ]
}

@test "hw_cpu_vendor detects amd" {
    printf 'processor\t: 0\nvendor_id\t: AuthenticAMD\n' > "$TEST_TMPDIR/cpuinfo"
    run bash -c "source '$INSTALL_DIR/lib/hw.sh'; HW_CPUINFO='$TEST_TMPDIR/cpuinfo' hw_cpu_vendor"
    [ "$output" = "amd" ]
}

@test "hw_cpu_vendor reports unknown for anything else" {
    printf 'vendor_id\t: SomeOtherCPU\n' > "$TEST_TMPDIR/cpuinfo"
    run bash -c "source '$INSTALL_DIR/lib/hw.sh'; HW_CPUINFO='$TEST_TMPDIR/cpuinfo' hw_cpu_vendor"
    [ "$output" = "unknown" ]
}

@test "hw_microcode_package maps intel to intel-ucode" {
    printf 'vendor_id\t: GenuineIntel\n' > "$TEST_TMPDIR/cpuinfo"
    run bash -c "source '$INSTALL_DIR/lib/hw.sh'; HW_CPUINFO='$TEST_TMPDIR/cpuinfo' hw_microcode_package"
    [ "$output" = "intel-ucode" ]
}

@test "hw_microcode_package maps amd to amd-ucode" {
    printf 'vendor_id\t: AuthenticAMD\n' > "$TEST_TMPDIR/cpuinfo"
    run bash -c "source '$INSTALL_DIR/lib/hw.sh'; HW_CPUINFO='$TEST_TMPDIR/cpuinfo' hw_microcode_package"
    [ "$output" = "amd-ucode" ]
}

@test "hw_microcode_package prints nothing for unknown vendors" {
    printf 'vendor_id\t: SomeOtherCPU\n' > "$TEST_TMPDIR/cpuinfo"
    run bash -c "source '$INSTALL_DIR/lib/hw.sh'; HW_CPUINFO='$TEST_TMPDIR/cpuinfo' hw_microcode_package"
    [ "$output" = "" ]
}

@test "hw_has_battery succeeds when a BAT device exists" {
    mkdir -p "$TEST_TMPDIR/power/BAT0"
    run bash -c "source '$INSTALL_DIR/lib/hw.sh'; HW_POWER_SUPPLY_DIR='$TEST_TMPDIR/power' hw_has_battery"
    [ "$status" -eq 0 ]
}

@test "hw_has_battery fails when only AC is present" {
    mkdir -p "$TEST_TMPDIR/power/AC"
    run bash -c "source '$INSTALL_DIR/lib/hw.sh'; HW_POWER_SUPPLY_DIR='$TEST_TMPDIR/power' hw_has_battery"
    [ "$status" -ne 0 ]
}

@test "hw_gpu_vendors detects intel from lspci output" {
    cat > "$TEST_TMPDIR/lspci" <<'FAKE'
#!/usr/bin/env bash
echo "00:02.0 VGA compatible controller: Intel Corporation Raptor Lake-P [Iris Xe Graphics]"
FAKE
    chmod +x "$TEST_TMPDIR/lspci"
    run bash -c "source '$INSTALL_DIR/lib/hw.sh'; HW_LSPCI='$TEST_TMPDIR/lspci' hw_gpu_vendors"
    [ "$output" = "intel" ]
}

@test "hw_gpu_vendors detects amd from lspci output" {
    cat > "$TEST_TMPDIR/lspci" <<'FAKE'
#!/usr/bin/env bash
echo "03:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Navi 33"
FAKE
    chmod +x "$TEST_TMPDIR/lspci"
    run bash -c "source '$INSTALL_DIR/lib/hw.sh'; HW_LSPCI='$TEST_TMPDIR/lspci' hw_gpu_vendors"
    [ "$output" = "amd" ]
}

@test "hw_gpu_vendors detects nvidia from lspci output" {
    cat > "$TEST_TMPDIR/lspci" <<'FAKE'
#!/usr/bin/env bash
echo "01:00.0 VGA compatible controller: NVIDIA Corporation AD107M [GeForce RTX 4060]"
FAKE
    chmod +x "$TEST_TMPDIR/lspci"
    run bash -c "source '$INSTALL_DIR/lib/hw.sh'; HW_LSPCI='$TEST_TMPDIR/lspci' hw_gpu_vendors"
    [ "$output" = "nvidia" ]
}

@test "hw_gpu_vendors reports both GPUs of a hybrid laptop" {
    # NVIDIA was checked first and returned alone, so the Intel iGPU that
    # drives the internal panel got no vulkan/VA-API drivers.
    cat > "$TEST_TMPDIR/lspci" <<'FAKE'
#!/usr/bin/env bash
echo "00:02.0 VGA compatible controller: Intel Corporation Raptor Lake-P [Iris Xe Graphics]"
echo "01:00.0 3D controller: NVIDIA Corporation AD107M [GeForce RTX 4060 Max-Q / Mobile]"
FAKE
    chmod +x "$TEST_TMPDIR/lspci"
    run bash -c "source '$INSTALL_DIR/lib/hw.sh'; HW_LSPCI='$TEST_TMPDIR/lspci' hw_gpu_vendors"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
    [[ "$output" == *nvidia* ]]
    [[ "$output" == *intel* ]]
}
