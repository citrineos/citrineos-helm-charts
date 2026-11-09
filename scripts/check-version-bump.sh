#!/usr/bin/env bash
# Fails if a chart changed but its Chart.yaml version did not go up.
# Usage: check-version-bump.sh <base-ref>   (e.g. origin/main)
set -euo pipefail
base="$1"; fail=0
ver() { grep -E '^version:' | awk '{print $2}' | tr -d "\"'"; }
for dir in $(git diff --name-only "$base"...HEAD -- charts/ | cut -d/ -f2 | sort -u); do
  [ -f "charts/$dir/Chart.yaml" ] || { echo "$dir: removed"; continue; }
  new=$(ver < "charts/$dir/Chart.yaml")
  old=$(git show "$base:charts/$dir/Chart.yaml" 2>/dev/null | ver || true)
  if [ -z "$old" ]; then
    echo "$dir: new chart at $new"
  elif [ "$old" = "$new" ]; then
    echo "::error file=charts/$dir/Chart.yaml::$dir changed but version is still $new"; fail=1
  elif [ "$(printf '%s\n%s\n' "$old" "$new" | sort -V | tail -1)" != "$new" ]; then
    echo "::error file=charts/$dir/Chart.yaml::$dir version went down ($old -> $new)"; fail=1
  else
    echo "$dir: $old -> $new"
  fi
done
exit $fail
