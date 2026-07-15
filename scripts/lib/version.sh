# Pure version helpers for distribute.sh / release.sh. Source, don't execute.

# parse_and_bump_version "version: X.Y.Z+N" <bump_patch:true|false>
# Echoes "OLD<TAB>NEW"; returns 1 with a message on malformed input.
parse_and_bump_version() {
  local line="$1" bump_patch="${2:-false}"
  local ver="${line#version:}"
  ver="${ver//[[:space:]]/}"   # strip all whitespace incl. a trailing CR from CRLF files
  if ! [[ "$ver" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)\+([0-9]+)$ ]]; then
    echo "ERROR: version must be X.Y.Z+N, got: '$ver'" >&2
    return 1
  fi
  local major="${BASH_REMATCH[1]}" minor="${BASH_REMATCH[2]}"
  local patch="${BASH_REMATCH[3]}" build="${BASH_REMATCH[4]}"
  local new_patch="$patch"
  # 10# forces base-10 so a leading zero (e.g. 09) isn't parsed as octal in $((…)).
  [[ "$bump_patch" == true ]] && new_patch=$((10#$patch + 1))
  printf '%s\t%s\n' "${major}.${minor}.${patch}+${build}" \
                    "${major}.${minor}.${new_patch}+$((10#$build + 1))"
}

# read_pubspec_version <pubspec_path> — echoes the version value (X.Y.Z+N),
# CR-stripped and validated. Returns 1 with a message when absent/malformed.
read_pubspec_version() {
  local file="$1" line ver
  line=$(grep '^version:' "$file" | head -1 || true)
  if [[ -z "$line" ]]; then
    echo "ERROR: no 'version:' line in $file" >&2
    return 1
  fi
  ver="${line#version:}"
  ver="${ver//[[:space:]]/}"   # strips a trailing CR from CRLF files too
  if ! [[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$ ]]; then
    echo "ERROR: pubspec version must be X.Y.Z+N, got: '$ver'" >&2
    return 1
  fi
  printf '%s\n' "$ver"
}

# validate_semver "X.Y.Z"  — release version, no build suffix. Returns non-zero if invalid.
validate_semver() {
  local v="$1"
  if ! [[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: version must be X.Y.Z (semver, no build suffix), got: '$v'" >&2
    return 1
  fi
  return 0
}

# parse_release_args <args...>  — order-independent. Echoes "VERSION<TAB>DRY_RUN".
# Returns non-zero (with message) on missing/invalid version or unknown flag.
parse_release_args() {
  local version="" dry_run=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) dry_run=true; shift ;;
      -*) echo "ERROR: unknown flag: $1" >&2; return 1 ;;
      *)
        if [[ -n "$version" ]]; then
          echo "ERROR: unexpected extra argument: $1" >&2; return 1
        fi
        version="$1"; shift ;;
    esac
  done
  if [[ -z "$version" ]]; then
    echo "ERROR: version is required (usage: release.sh <X.Y.Z> [--dry-run])" >&2
    return 1
  fi
  validate_semver "$version" || return 1
  printf '%s\t%s\n' "$version" "$dry_run"
}
