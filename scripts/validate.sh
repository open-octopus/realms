#!/usr/bin/env bash
#
# validate.sh - Validate the structure and content of all realm packages.
#
# Checks:
#   1. Every realm directory contains a REALM.md file
#   2. REALM.md has YAML frontmatter with required fields: name, description, icon
#   3. Referenced soulFile paths in defaultEntities actually exist
#   4. Every realm has at least one agent, entity, and soul file
#
# Exit code 0 on success, 1 if any check fails.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

pass=0
fail=0
errors=()

pass_check() {
  pass=$((pass + 1))
}

fail_check() {
  fail=$((fail + 1))
  errors+=("  FAIL: $1")
}

# Discover realm directories: any top-level directory that contains a REALM.md
# or that contains agents/entities/souls subdirectories.
realm_dirs=()
for dir in "$REPO_ROOT"/*/; do
  realm="$(basename "$dir")"
  # Skip non-realm directories (e.g., docs, scripts, .github)
  if [ -f "$dir/REALM.md" ] || [ -d "$dir/agents" ] || [ -d "$dir/entities" ] || [ -d "$dir/souls" ]; then
    realm_dirs+=("$realm")
  fi
done

if [ ${#realm_dirs[@]} -eq 0 ]; then
  echo "ERROR: No realm directories found in $REPO_ROOT"
  exit 1
fi

echo "Validating ${#realm_dirs[@]} realms..."
echo ""

for realm in "${realm_dirs[@]}"; do
  realm_dir="$REPO_ROOT/$realm"
  realm_ok=true

  # --- Check 1: REALM.md exists ---
  if [ ! -f "$realm_dir/REALM.md" ]; then
    fail_check "$realm: missing REALM.md"
    realm_ok=false
  else
    pass_check

    # --- Check 2: YAML frontmatter has required fields ---
    # Extract frontmatter (between first --- and second ---)
    frontmatter=$(awk '/^---$/{n++; next} n==1{print} n==2{exit}' "$realm_dir/REALM.md")

    for field in name description icon; do
      if echo "$frontmatter" | grep -q "^${field}:"; then
        pass_check
      else
        fail_check "$realm: REALM.md missing required field '$field'"
        realm_ok=false
      fi
    done

    # --- Check 3: Referenced soulFile paths exist ---
    soul_refs=$(echo "$frontmatter" | grep 'soulFile:' | awk '{print $2}' || true)
    for ref in $soul_refs; do
      if [ -f "$realm_dir/$ref" ]; then
        pass_check
      else
        fail_check "$realm: soulFile '$ref' does not exist"
        realm_ok=false
      fi
    done
  fi

  # --- Check 4: At least one agent, entity, and soul file ---
  agent_count=$(find "$realm_dir/agents" -name '*.agent.yml' 2>/dev/null | wc -l | tr -d ' ')
  entity_count=$(find "$realm_dir/entities" -name '*.entity.yml' 2>/dev/null | wc -l | tr -d ' ')
  soul_count=$(find "$realm_dir/souls" -name '*.soul.md' 2>/dev/null | wc -l | tr -d ' ')

  if [ "$agent_count" -ge 1 ]; then
    pass_check
  else
    fail_check "$realm: no *.agent.yml files in agents/"
    realm_ok=false
  fi

  if [ "$entity_count" -ge 1 ]; then
    pass_check
  else
    fail_check "$realm: no *.entity.yml files in entities/"
    realm_ok=false
  fi

  if [ "$soul_count" -ge 1 ]; then
    pass_check
  else
    fail_check "$realm: no *.soul.md files in souls/"
    realm_ok=false
  fi

  # Per-realm status
  if $realm_ok; then
    echo "  OK  $realm"
  else
    echo "  ERR $realm"
  fi
done

# --- Summary ---
echo ""
echo "==============================="
echo " Results: $pass passed, $fail failed"
echo "==============================="

if [ $fail -gt 0 ]; then
  echo ""
  for err in "${errors[@]}"; do
    echo "$err"
  done
  echo ""
  exit 1
fi

echo ""
echo "All checks passed."
exit 0
