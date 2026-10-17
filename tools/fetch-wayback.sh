#!/bin/bash
# Refetch the one artifact that did not come from a torrent: iCafe 100.50, which
# AMD published at a URL that is now dead and which survives only in the Wayback
# Machine. Two captures exist and are byte-identical.
#
#   original   http://www2.ati.com/drivers/windows-xp-amd-catalyst-9.00.300.3005-dec9.exe
#   captures   20150510011138 and 20150525015957
#
# It is handled separately because it needs an archive URL rather than a mirror, and
# because its provenance matters more than its size: this is an AMD-published driver
# preserved by an archive, not a third-party repack. The `id_` suffix asks the Wayback
# Machine for the archived bytes rather than its replay wrapper.
set -u
ROOT=/home/dconnolly/xp64-corpus
ORIG="http://www2.ati.com/drivers/windows-xp-amd-catalyst-9.00.300.3005-dec9.exe"
NAME=icafe-100.50-xp64-9.00.300.3005.exe
F="$ROOT/drivers/$NAME"
WANT=$(grep -v '^#' "$ROOT/MANIFEST.tsv" | grep -F "$NAME" | cut -f4)

if [ -z "$WANT" ]; then echo "no manifest row for $NAME" >&2; exit 1; fi

if [ -s "$F" ] && [ "$(sha256sum "$F" | cut -d' ' -f1)" = "$WANT" ]; then
  echo "  $NAME: already present and hash-verified"
  exit 0
fi

# Prefer the later capture; the two are byte-identical, so either proves the same bytes.
for TS in 20150525015957 20150510011138; do
  echo "  trying capture $TS"
  curl -sS --http1.1 -L --max-time 1800 -o "$F" \
    "https://web.archive.org/web/${TS}id_/$ORIG" 2>&1 | tail -1
  if [ -s "$F" ]; then
    GOT=$(sha256sum "$F" | cut -d' ' -f1)
    if [ "$GOT" = "$WANT" ]; then
      echo "  $NAME: OK $(stat -c%s "$F") bytes from capture $TS, sha256 matches the manifest"
      7z t "$F" >/dev/null 2>&1 && echo "  archive integrity: OK" || echo "  archive integrity: FAIL"
      exit 0
    fi
    echo "  sha256 mismatch from $TS (got $GOT), trying the next capture"
  fi
done

echo "  $NAME: NOT RECOVERED from either capture" >&2
exit 1