# xp64-driver-corpus

The AMD driver packages behind the Windows XP x64 / R9 290X work in the
`agentic-winxp-x64-r290x` host: the full XP x64 lineage from Catalyst 9.3
through 14.4, the two iCafe channel builds, and the Win7 14.4 desktop
pair that donates the Hawaii SMC firmware. Fourteen packages, roughly
2.4 GB.

## Where the bytes are

The packages are too large for a git tree (GitHub rejects anything over
100 MB), so they live as the assets of the [`corpus-v1`](releases/tag/corpus-v1)
release of this repository. `MANIFEST.tsv` is the contract: one row per
package, its sha256 recorded at acquisition, the torrent infohash where
the package was torrent-sourced, and the original acquisition source
(`mirror`, `wayback`, `archive`, `operator`). The `source` column is
history; the release is the re-fetch path for every row.

## Rebuild and verify

```sh
tools/fetch-all.sh
```

Downloads each asset from the release, verifies it against the manifest,
and exits non-zero on any miss. A refetch that hashes differently is a
finding, not a nuisance.

## What is deliberately absent

Microsoft media. The Windows XP x64 ISOs stay off GitHub and live only on
the acquisition machine; their hashes are recorded in that machine's
local corpus manifest, alongside the rig-built slipstream images. This
repository distributes AMD driver packages only, mirroring what driver
mirror sites have done for decades.

## Torrent provenance

`drivers/meta/` carries the original `.torrent` metainfo for the
torrent-sourced packages (tiny, committed). `tools/tinfo.py` reads an
infohash from a torrent file; `tools/fetch-wayback.sh` documents how the
Wayback-sourced packages were captured.
