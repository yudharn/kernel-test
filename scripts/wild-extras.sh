#!/usr/bin/env bash
# env: KP_DIR (WildKernels/kernel_patches checkout), PERF (true|false), GITHUB_ENV. Kernel 5.10 only.
# shellcheck source=scripts/patch-helpers.sh
source "${HELPERS}"
KP="${KP_DIR}/common"

PTRACE_FIX=false; UNICODE_FIX=false
apply_patch "${KP_DIR}/gki_ptrace.patch" "Ptrace leak fix (gki_ptrace.patch)" 3; [[ $? -ne 1 ]] && PTRACE_FIX=true
apply_patch "${KP}/unicode_bypass_fix_6.1-.patch" "Unicode bypass fix" 0; [[ $? -ne 1 ]] && UNICODE_FIX=true
echo "PTRACE_FIX=${PTRACE_FIX}" >> "${GITHUB_ENV}"
echo "UNICODE_FIX=${UNICODE_FIX}" >> "${GITHUB_ENV}"

if [[ "${PERF}" == true ]]; then
  PERF_OK=0; PERF_FAILED=()
  perf() {  # perf <file> [fuzz] [file-with-equivalent-change regex-of-equivalent-change]
    local rc name; name=$(basename "$1" .patch)
    if [[ -n "${3:-}" ]] && grep -Eq "$4" "$3" 2>/dev/null; then
      echo "==> Perf: ${name}: equivalent change already in this tree, skipped"
      PERF_OK=$((PERF_OK+1)); return
    fi
    apply_patch "$1" "Perf: ${name}" "${2:-2}"; rc=$?
    if [[ $rc -eq 1 ]]; then PERF_FAILED+=("${name}"); else PERF_OK=$((PERF_OK+1)); fi
  }

  perf "${KP}/optimized_mem_operations.patch"
  perf "${KP}/file_struct_8bytes_align.patch"
  perf "${KP}/reduce_cache_pressure.patch"
  perf "${KP}/mem_opt_prefetch.patch"
  # optimise_memcmp.patch is skipped: WildKernels only applies it on 5.11+.
  perf "${KP}/minimise_wakeup_time.patch" 2 kernel/time/alarmtimer.c 'pm_wakeup_event\(dev, ktime_to_ms\(min\) \+'
  perf "${KP}/int_sqrt.patch"
  perf "${KP}/reduce_gc_thread_sleep_time.patch"
  perf "${KP}/add_timeout_wakelocks_globally.patch"
  perf "${KP}/f2fs_reduce_congestion.patch"
  perf "${KP}/reduce_freeze_timeout.patch" 2 kernel/power/process.c 'CONFIG_ANDROID\) \? MSEC_PER_SEC'
  perf "${KP}/clear_page_16bytes_align.patch"
  FILE=drivers/base/power/wakeup.c
  if grep -q '^void pm_system_wakeup(void)' "$FILE" && \
     sed -n '/^void pm_system_wakeup(void)/,/^}/p' "$FILE" | grep -q 'suspend_abort_fs_sync();'; then
    sed -i '/^void pm_system_wakeup(void)/,/^}/{/suspend_abort_fs_sync();/d}' "$FILE"
  fi
  perf "${KP}/avoid_extra_s2idle_wake_attempts.patch" 3
  perf "${KP}/disable_cache_hot_buddy.patch" 3
  perf "${KP}/f2fs_enlarge_min_fsync_blocks.patch" 3
  perf "${KP}/increase_ext4_default_commit_age.patch" 3
  perf "${KP}/increase_sk_mem_packets.patch" 3
  perf "${KP}/reduce_pci_pme_wakeups.patch" 3
  perf "${KP}/silence_irq_cpu_logspam.patch" 3
  perf "${KP}/silence_system_logspam.patch" 3

  echo "PERF_OK=${PERF_OK}" >> "${GITHUB_ENV}"
  echo "PERF_FAILED=${PERF_FAILED[*]}" >> "${GITHUB_ENV}"
  echo "==> Performance patches: ${PERF_OK} applied/present, ${#PERF_FAILED[@]} skipped: ${PERF_FAILED[*]:-none}"
fi
