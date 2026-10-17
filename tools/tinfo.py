#!/usr/bin/env python3
"""Decode a single-file .torrent and verify a payload against its piece hashes.

The infohash is a hash of the metainfo's `info` dictionary, so it names the payload
without naming a server. That is the property worth keeping: it still identifies what
was held after the origin moves the file.

usage: tinfo.py <torrent> [payload]
       with a payload, also checks every piece and reports length agreement.
"""
import hashlib
import sys


def parse(data, i=0):
    c = chr(data[i])
    if c == "i":
        j = data.index(b"e", i)
        return int(data[i + 1 : j]), j + 1
    if c == "l":
        i += 1
        out = []
        while data[i : i + 1] != b"e":
            v, i = parse(data, i)
            out.append(v)
        return out, i + 1
    if c == "d":
        i += 1
        out = {}
        while data[i : i + 1] != b"e":
            k, i = parse(data, i)
            v, i = parse(data, i)
            out[k] = v
        return out, i + 1
    j = data.index(b":", i)
    n = int(data[i:j])
    return data[j + 1 : j + 1 + n], j + 1 + n


def locate_info(data):
    """Return the raw bencoded bytes of the top-level 'info' dict."""
    key = b"4:info"
    start = data.index(key) + len(key)
    if chr(data[start]) != "d":
        raise ValueError("info is not a dict")
    depth, i = 0, start
    while True:
        ch = chr(data[i])
        if ch in "dl":
            depth += 1
            i += 1
        elif ch == "e":
            depth -= 1
            i += 1
            if depth == 0:
                return data[start:i]
        elif ch == "i" or ch.isdigit():
            # An integer or a length-prefixed string: both self-delimiting, so let
            # the value parser carry us to the next byte.
            _, i = parse(data, i)
        else:
            raise ValueError(f"unexpected byte {ch!r} at {i}")


def verify(data, meta, payload):
    info = meta[b"info"]
    want_len = info[b"length"]
    blob = open(payload, "rb").read()
    if len(blob) != want_len:
        print(f"  pieces       LENGTH MISMATCH: {len(blob)} on disk, {want_len} in torrent")
        return False
    plen = info[b"piece length"]
    hashes = info[b"pieces"]
    bad = [
        n
        for n in range(len(hashes) // 20)
        if hashes[n * 20 : n * 20 + 20]
        != hashlib.sha1(blob[n * plen : (n + 1) * plen]).digest()
    ]
    total = len(hashes) // 20
    if bad:
        print(f"  pieces       MISMATCH in {len(bad)} of {total} pieces: {bad[:8]}")
        return False
    print(f"  pieces       OK, all {total} pieces match the torrent")
    return True


def main(torrent_path, payload_path=None):
    data = open(torrent_path, "rb").read()
    meta, _ = parse(data)
    infohash = hashlib.sha1(locate_info(data)).hexdigest()
    print(f"  infohash     {infohash}")
    print(f"  announce     {meta.get(b'announce', b'(none)').decode()}")
    info = meta[b"info"]
    if b"files" in info:
        print(f"  layout       multi-file, {len(info[b'files'])} members")
    else:
        print(f"  name         {info[b'name'].decode()}")
        print(f"  length       {info[b'length']}")
    if payload_path:
        try:
            verify(data, meta, payload_path)
        except OSError as err:
            print(f"  payload      ABSENT ({err.strerror})")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)