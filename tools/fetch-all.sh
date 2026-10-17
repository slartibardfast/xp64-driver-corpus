#!/bin/bash
# Rebuild the driver corpus from this repository's corpus-v1 release and verify
# every artifact against the sha256 recorded in MANIFEST.tsv. A refetch that
# hashes differently is a finding, not a nuisance, so this reports rather than
# retries silently.
#
# Two properties inherited from the original corpus tooling, both learned the
# hard way:
#
#   * Every manifest row is accounted for. A bare `while read` silently drops a
#     final line with no trailing newline; the `|| [ -n "$line" ]` below is the
#     whole point, and the reconciliation pass at the end is authoritative for
#     the exit code, never the branch counters.
#
#   * The summary is never the verdict. Counting only the branches the code
#     happened to reach is how a missing artifact once printed "failed: 0".
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DRV=$ROOT/drivers
TAG=corpus-v1
REPO=slartibardfast/xp64-driver-corpus
pass=0; fail=0; skipped=0

note() { printf '  %s\n' "$*"; }

manifest_rows() {
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|\#*) continue ;; esac
    printf '%s\n' "$line"
  done < "$ROOT/MANIFEST.tsv"
}

field() { printf '%s' "$1" | cut -f"$2"; }

fetch_release() {
  local name="$1" want_sha="$2"
  local f="$DRV/$name"

  if [ -s "$f" ] && [ "$(sha256sum "$f" | cut -d' ' -f1)" = "$want_sha" ]; then
    note "$name: already present and matching"; skipped=$((skipped+1)); return
  fi
  mkdir -p "$DRV"
  local url="https://github.com/$REPO/releases/download/$TAG/$name"
  curl -sS -L --max-time 3600 -o "$f" "$url" || { note "$name: FETCH FAILED"; fail=$((fail+1)); return; }
  local got
  got=$(sha256sum "$f" | cut -d' ' -f1)
  [ "$got" = "$want_sha" ] || { note "$name: SHA256 MISMATCH (got $got)"; fail=$((fail+1)); return; }
  note "$name: OK $(stat -c%s "$f") bytes, sha256 matches the manifest"
  pass=$((pass+1))
}

echo "=== corpus release rebuild (tag $TAG) ==="
while IFS= read -r row; do
  fetch_release "$(field "$row" 1)" "$(field "$row" 4)"
done < <(manifest_rows)

echo
echo "=== reconciliation: this is the verdict, not the counters ==="
total=0; bad=0
while IFS= read -r row; do
  total=$((total+1))
  name=$(field "$row" 1); sha=$(field "$row" 4)
  f="$DRV/$name"
  if [ ! -s "$f" ]; then note "MISSING   $name"; bad=$((bad+1)); continue; fi
  got=$(sha256sum "$f" | cut -d' ' -f1)
  if [ "$got" = "$sha" ]; then note "ok        $name"
  else note "MISMATCH  $name"; bad=$((bad+1)); fi
done < <(manifest_rows)

echo
note "fetched fresh    : $pass"
note "already correct  : $skipped"
note "fetch failures   : $fail"
note "manifest rows    : $total"
note "rows unverified  : $bad"
echo "=== rebuild done ==="

if [ "$bad" -ne 0 ]; then
  echo "VERDICT: INCOMPLETE, $bad of $total artifacts are not verified" >&2
  exit 1
fi
echo "VERDICT: all $total artifacts present and hash-verified"
