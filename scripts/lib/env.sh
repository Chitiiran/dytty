# .env reader helper. Source, don't execute.

# read_env_var <VAR_NAME> <env_file>
# Echoes the value of an assignment line (anchored at ^VAR=), ignoring commented
# lines and preserving '=' characters in the value. Empty output if absent.
read_env_var() {
  local var="$1" file="$2"
  [[ -f "$file" ]] || return 0
  grep "^${var}=" "$file" | head -1 | cut -d= -f2- || true
}
