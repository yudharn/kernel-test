#!/usr/bin/env bash
# env: MB_DIR (Melt-Blessing-Patches checkout), PORT_DIR (this repo's patches/melt-blessing),
#      MB_MODE (all|zblock-mglru|reverts|off), HELPERS, GITHUB_ENV
# shellcheck source=scripts/patch-helpers.sh
source "${HELPERS}"
MB_ZBLOCK=false; MB_MGLRU=false; MB_KCOMPRESSD=false; MB_KGSL=false; MB_KSHRINK=false
want_feat() { [[ "$MB_MODE" == all ]] || [[ "$MB_MODE" == "$1" ]]; }

if want_feat zblock-mglru; then
  # 0005 upstream targets a newer zblock.c than 0001 provides; fall back to the port shipped in this repo.
  Z5="$MB_DIR/features/ZBlock/0005-mm-refine-ZBlock-to-avoid-broken-handle-and-pool-leak.patch"
  if apply_series "Melt-Blessing ZBlock" "$MB_DIR"/features/ZBlock/000{1,2,3,4}-*.patch; then
    if apply_first "Melt-Blessing ZBlock 0005 (handle/pool-leak fix)" "$Z5" "$PORT_DIR/0005-zblock-refine-ported.patch"; then
      MB_ZBLOCK=true
    else
      zb=("$MB_DIR"/features/ZBlock/000{1,2,3,4}-*.patch)
      for (( i=${#zb[@]}-1; i>=0; i-- )); do patch -p1 -R --batch --no-backup-if-mismatch < "${zb[$i]}" > /dev/null; done
      echo "::warning::Melt-Blessing ZBlock: rolled back, 0005 fix could not be applied"
    fi
  fi
  apply_first "Melt-Blessing MG-LRU-lite" \
    "$(ls "$MB_DIR"/features/MG-LRU-lite/mglru_lite_backup_*.patch | sort | tail -n1)" \
    "$PORT_DIR/mglru-lite-ported.patch" && MB_MGLRU=true
fi

if want_feat reverts; then
  apply_first "Melt-Blessing remove KCompressd" \
    "$PORT_DIR/remove-kcompressd-ported.patch" && MB_KCOMPRESSD=true
  # KShrink is shipped as prebuilt kshrink_*.ko in AnyKernel3: it is dropped from the module package
  # in "Make AnyKernel3" (0002 only edits =m lines in marble_defconfig, which do not reach Image).
  MB_KSHRINK=true
  apply_first "Melt-Blessing kgsl __GFP_NORETRY" "$MB_DIR"/Reverts/GFP_NORETRY/0001-*.patch && MB_KGSL=true
fi

{
  echo "MB_ZBLOCK=${MB_ZBLOCK}"
  echo "MB_MGLRU=${MB_MGLRU}"
  echo "MB_KCOMPRESSD=${MB_KCOMPRESSD}"
  echo "MB_KSHRINK=${MB_KSHRINK}"
  echo "MB_KGSL=${MB_KGSL}"
} >> "${GITHUB_ENV}"
echo "==> Melt-Blessing: zblock=${MB_ZBLOCK} mglru=${MB_MGLRU} kcompressd_removed=${MB_KCOMPRESSD} kshrink_removed=${MB_KSHRINK} kgsl_noretry=${MB_KGSL}"
