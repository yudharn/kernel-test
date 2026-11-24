# shellcheck shell=bash
# Sourced by the build steps. Run from the kernel tree root.
# apply_patch <file> <label> [fuzz]
#   0 = applied now, 2 = already present (reverse applies cleanly), 1 = does not apply (tree untouched)
apply_patch() {
  local file="$1" label="$2" fuzz="${3:-0}"
  if patch -p1 -N --batch --fuzz="$fuzz" --dry-run < "$file" > /tmp/patch_dry.log 2>&1; then
    patch -p1 -N --batch --fuzz="$fuzz" --no-backup-if-mismatch < "$file" > /dev/null
    echo "==> ${label}: applied"
    return 0
  elif patch -p1 -R --batch --fuzz=0 --dry-run < "$file" > /dev/null 2>&1; then
    echo "==> ${label}: already present in this tree, skipped"
    return 2
  else
    echo "::warning::${label}: does not apply cleanly, skipped"
    sed 's/^/    /' /tmp/patch_dry.log | head -n 20
    return 1
  fi
}

# apply_first <label> <file>... : try each candidate in order until one applies (or is already present)
apply_first() {
  local label="$1"; shift
  local f rc
  for f in "$@"; do
    [[ -f "$f" ]] || continue
    apply_patch "$f" "${label} [$(basename "$f")]" > /tmp/apply_first.log 2>&1; rc=$?
    if [[ $rc -ne 1 ]]; then cat /tmp/apply_first.log; return 0; fi
  done
  cat /tmp/apply_first.log
  echo "::warning::${label}: no candidate patch applies, skipped"
  return 1
}

# apply_series <label> <file>... : all-or-nothing, rolls back the whole group if one patch fails
apply_series() {
  local label="$1"; shift
  local done_list=() f rc
  for f in "$@"; do
    apply_patch "$f" "${label}: $(basename "$f")"; rc=$?
    if [[ $rc -eq 1 ]]; then
      local i
      for (( i=${#done_list[@]}-1; i>=0; i-- )); do
        patch -p1 -R --batch --no-backup-if-mismatch < "${done_list[$i]}" > /dev/null
      done
      echo "::warning::${label}: rolled back (a patch in the series failed)"
      return 1
    fi
    [[ $rc -eq 0 ]] && done_list+=("$f")
  done
  return 0
}
