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

hw_gpu_vendor() {
    local out
    out="$("$HW_LSPCI" 2>/dev/null | grep -iE 'vga|3d controller' || true)"
    if   echo "$out" | grep -qi nvidia;            then echo nvidia
    elif echo "$out" | grep -qiE 'amd|ati|radeon'; then echo amd
    elif echo "$out" | grep -qi intel;             then echo intel
    else echo unknown
    fi
}

hw_has_battery() {
    compgen -G "$HW_POWER_SUPPLY_DIR/BAT*" > /dev/null
}
