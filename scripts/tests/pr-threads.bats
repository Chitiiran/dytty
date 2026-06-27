#!/usr/bin/env bats
# Tests the read-only pr-threads.sh thread formatter against canned graphql JSON.

setup() {
  load helpers
  source "$(scripts_dir)/pr-threads.sh"
}

# Two threads: one unresolved (gemini), one resolved. Only the unresolved should print.
CANNED='{"data":{"repository":{"pullRequest":{"reviewThreads":{"totalCount":2,"nodes":[
{"isResolved":false,"isOutdated":false,"comments":{"nodes":[{"author":{"login":"gemini-code-assist"},"body":"Potential null deref here\nsecond line"}]}},
{"isResolved":true,"isOutdated":false,"comments":{"nodes":[{"author":{"login":"gemini-code-assist"},"body":"resolved one"}]}}
]}}}}}'

@test "formats only unresolved threads with author + first line" {
  run format_threads "$CANNED"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "gemini-code-assist"
  echo "$output" | grep -q "Potential null deref here"
  # The resolved thread's body must NOT appear
  ! echo "$output" | grep -q "resolved one"
}

@test "reports count of unresolved threads" {
  run format_threads "$CANNED"
  echo "$output" | grep -qE "1 unresolved"
}

@test "all-resolved input prints a clean message and no thread bodies" {
  local allres='{"data":{"repository":{"pullRequest":{"reviewThreads":{"totalCount":1,"nodes":[
{"isResolved":true,"isOutdated":false,"comments":{"nodes":[{"author":{"login":"x"},"body":"done"}]}}
]}}}}}'
  run format_threads "$allres"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qiE "0 unresolved|all .*resolved|no unresolved"
  ! echo "$output" | grep -q "done"
}
