# Weekly-retro age helper for verify-workflow.sh. Source, don't execute.

# retro_age_days <retro_md_file> <python_lib_dir>
# Echoes whole days since the most recent '### YYYY-MM-DD' entry heading in
# the file; echoes -1 when the file is missing (kb/ is local-only — absent on
# fresh checkouts/worktrees), has no dated entry, or the date is malformed
# (observation.py returns its safe sentinel rather than raising).
retro_age_days() {
  local file="$1" libdir="$2" last winlib
  if [[ ! -f "$file" ]]; then
    echo -1
    return 0
  fi
  last=$(grep -oE '^### [0-9]{4}-[0-9]{2}-[0-9]{2}' "$file" | tail -1 | awk '{print $2}')
  if [[ -z "$last" ]]; then
    echo -1
    return 0
  fi
  # Native Windows python can't open MSYS /c/... paths — hand it a Windows
  # path for sys.path (same pitfall class as the stage_cleanup log-read).
  winlib=$(cygpath -w "$libdir" 2>/dev/null || printf '%s' "$libdir")
  python -c "
import sys
sys.path.insert(0, sys.argv[1])
from observation import days_since
print(days_since(sys.argv[2]))
" "$winlib" "$last" 2>/dev/null || echo -1
}
