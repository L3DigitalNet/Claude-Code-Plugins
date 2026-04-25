#!/usr/bin/env bats
# mutation-patterns.bats — Core source-able function exercised in isolation.
# is_mutation_command() is the discriminator that routes audit logging.
bats_require_minimum_version 1.5.0

PLUGIN_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
  # Source the function in test scope.
  # shellcheck source=plugins/github-repo-manager/scripts/mutation-patterns.sh
  source "$PLUGIN_ROOT/scripts/mutation-patterns.sh"
}

@test "issues close IS a mutation (MP1)" {
  is_mutation_command "node gh-manager.js issues close 42"
}

@test "issues list is NOT a mutation (MP2 read-only)" {
  ! is_mutation_command "node gh-manager.js issues list"
}

@test "releases draft IS a mutation (MP3)" {
  is_mutation_command "node gh-manager.js releases draft v1.0.0"
}

@test "files put IS a mutation (MP4)" {
  is_mutation_command "node gh-manager.js files put README.md"
}

@test "auth verify is NOT a mutation (MP5 read-only)" {
  ! is_mutation_command "node gh-manager.js auth verify"
}

@test "non-gh-manager command is NOT a mutation (MP6)" {
  ! is_mutation_command "ls -la"
}

@test "--dry-run flag short-circuits mutation detection (MP-dryrun)" {
  # Documented behavior in the script: dry-run calls never mutate.
  ! is_mutation_command "node gh-manager.js issues close 42 --dry-run"
}
