#!/bin/bash
# SessionStart hook for linux-sysadmin plugin.
# Detects sysadmin working directories and injects a context reminder
# to consult linux-sysadmin skills before running service commands.

# Read cwd from stdin JSON
CWD=$(python3 -c "import sys,json; print(json.load(sys.stdin).get('cwd',''))" 2>/dev/null)

# Sysadmin working directories — sessions here involve server work
# Exact: match only when cwd IS this directory
# Prefix: match this directory and all subdirectories
SYSADMIN_EXACT=( "/home/chris" )
SYSADMIN_PREFIX=( "/home/chris/git-luminous3d/homelab" )

is_sysadmin_dir=false
for dir in "${SYSADMIN_EXACT[@]}"; do
  [[ "$CWD" == "$dir" ]] && is_sysadmin_dir=true && break
done
if [[ "$is_sysadmin_dir" == "false" ]]; then
  for dir in "${SYSADMIN_PREFIX[@]}"; do
    [[ "$CWD" == "$dir" || "$CWD" == "$dir/"* ]] && is_sysadmin_dir=true && break
  done
fi

if [[ "$is_sysadmin_dir" == "true" ]]; then
  # Emit context that gets injected into the AI's conversation
  cat <<'CONTEXT'
[linux-sysadmin] Sysadmin working directory detected. Before installing, configuring, or troubleshooting any Linux service, invoke Skill("linux-sysadmin:sysadmin"). It contains a topic index of 163 service guides and will load the right one.
CONTEXT
fi
