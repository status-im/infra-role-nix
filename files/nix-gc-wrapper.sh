#!/usr/bin/env bash
# Wraps nix-collect-garbage so that "in use" GC races (a build holding a
# .drv) are non-fatal. Those paths get collected on the next run.
# See: https://github.com/status-im/infra-role-nix/issues/6
set -uo pipefail

GC="${NIX_GC_BIN:-/run/current-system/sw/bin/nix-collect-garbage}"

out="$("$GC" "$@" 2>&1)"
rc=$?
echo "$out"

[[ $rc -eq 0 ]] && exit 0

# Tolerate ONLY the in-use race: any error line that is NOT "cannot delete
# path" means a genuine failure
real="$(grep -E '^error:' <<<"$out" | grep -v 'cannot delete path')"
if [[ -z "$real" ]]; then
  echo "WARN: GC hit in-use paths (build running); treating as non-fatal"
  exit 0
fi

exit $rc