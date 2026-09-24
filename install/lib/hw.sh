#!/usr/bin/env bash
# Hardware facts. Every source path is overridable so the functions are testable.

HW_CPUINFO="${HW_CPUINFO:-/proc/cpuinfo}"
HW_POWER_SUPPLY_DIR="${HW_POWER_SUPPLY_DIR:-/sys/class/power_supply}"
HW_LSPCI="${HW_LSPCI:-lspci}"

hw_cpu_vendor() {
    local vendor
    vendor="$(awk -F': ' '/^vendor_id/ {print $2; exit}' "$HW_CPUINFO" 2>/dev/null || true)"
    case "$vendor" in
        GenuineIntel) echo intel ;;
        AuthenticAMD) echo amd ;;
        *)            echo unknown ;;
    esac
}

hw_microcode_package() {
    case "$(hw_cpu_vendor)" in
        intel) echo intel-ucode ;;
        amd)   echo amd-ucode ;;
        *)     : ;;
    esac
}

# Every GPU vendor present, one per line, or "unknown". A hybrid laptop has
# two: an Intel or AMD iGPU driving the internal panel plus an NVIDIA "3D
# controller", and picking one left the panel's GPU with no drivers.
hw_gpu_vendors() {
    local out found=0
    out="$("$HW_LSPCI" 2>/dev/null | grep -iE 'vga|3d controller|display controller' || true)"
    # -w matters: without word boundaries, 'ati' matches inside "VGA
    # compatible controller", so every GPU would be detected as AMD.
    if echo "$out" | grep -qi nvidia;             then echo nvidia; found=1; fi
    if echo "$out" | grep -qiEw 'amd|ati|radeon'; then echo amd;    found=1; fi
    if echo "$out" | grep -qi intel;              then echo intel;  found=1; fi
    [ "$found" = 1 ] || echo unknown
}

hw_has_battery() {
    compgen -G "$HW_POWER_SUPPLY_DIR/BAT*" > /dev/null
}
