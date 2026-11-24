#!/usr/bin/env bash
# Adjust the prebuilt module package shipped in AnyKernel3 (_modules_hyperos.7z) so it matches
# what the Melt-Blessing patches changed in this kernel.
#   usage: ak3-modules.sh <AnyKernel3 dir>
#   env:   ZRAM_BUILTIN  true -> zram/zsmalloc are built into Image (ZBlock): drop zram.ko + zsmalloc.ko
#          MB_KSHRINK    true -> drop kshrink_slabd.ko + kshrink_lruvecd.ko
#          KGSL_KO       path to a rebuilt msm_kgsl.ko (kgsl __GFP_NORETRY revert) -> replace the prebuilt one
set -euo pipefail

AK3="$(realpath "$1")"
PKG="${AK3}/_modules_hyperos.7z"
[[ -f "$PKG" ]] || { echo "::warning::${PKG} not found, module package left unchanged"; exit 0; }

WORK="$(mktemp -d)"
7z x -y -bd -o"${WORK}" "$PKG" > /dev/null
BOOT="${WORK}/_vendor_boot_modules"
DLKM="${WORK}/_vendor_dlkm_modules"

drop_module() {  # drop_module <name without .ko>
  local name="$1" dir
  for dir in "$BOOT" "$DLKM"; do
    rm -f "${dir}/${name}.ko"
    for list in modules.load modules.load.recovery; do
      [[ -f "${dir}/${list}" ]] && sed -i "/^${name}\.ko\$/d" "${dir}/${list}"
    done
    [[ -f "${dir}/modules.dep" ]] && sed -i "\#/${name}\.ko:#d" "${dir}/modules.dep"
  done
  echo "==> AK3 modules: dropped ${name}.ko"
}

if [[ "${ZRAM_BUILTIN:-false}" == true ]]; then
  drop_module zram
  drop_module zsmalloc
  rm -f "${WORK}/_alt/MI-zram.ko" "${WORK}/_alt/MI-zsmalloc.ko"
  # The installer offers to swap in Xiaomi's zram.ko on MIUI/HyperOS; zram is built in now, so never do that.
  sed -i '/^# OSS zram.ko & zsmalloc.ko/{n;s/^if \${is_miui_rom}; then/if false; then  # zram is built into this kernel (ZBlock)/}' "${AK3}/anykernel.sh"
  grep -q 'zram is built into this kernel' "${AK3}/anykernel.sh" \
    || echo "::warning::anykernel.sh: could not disable the MI zram.ko option (script layout changed?)"
fi

if [[ "${MB_KSHRINK:-false}" == true ]]; then
  drop_module kshrink_slabd
  drop_module kshrink_lruvecd
fi

if [[ -n "${KGSL_KO:-}" && -f "${KGSL_KO}" ]]; then
  for dir in "$BOOT" "$DLKM"; do
    [[ -f "${dir}/msm_kgsl.ko" ]] && cp -f "${KGSL_KO}" "${dir}/msm_kgsl.ko"
  done
  echo "==> AK3 modules: replaced msm_kgsl.ko with the one built from this tree"
fi

rm -f "$PKG"
(cd "$WORK" && 7z a -t7z -mx=9 -bd "$PKG" . > /dev/null)
rm -rf "$WORK"
echo "==> AK3 modules: repacked $(basename "$PKG")"
