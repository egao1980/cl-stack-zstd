# cl-stack-zstd

MIT. Ships **Zstandard** (`libzstd`) as
[cl-repository](https://github.com/egao1980/cl-repository) platform overlays,
plus CFFI and [`compression-protocol`](https://github.com/egao1980/compression-protocol)
methods for `:zstd`. HTTP `Content-Encoding: zstd` is
[`http-encoding-zstd`](https://github.com/egao1980/http-encoding-zstd).

| | |
|--|--|
| ASDF | `cl-stack-zstd` |
| GHCR | `ghcr.io/egao1980/cl-systems/cl-stack-zstd:<zstd-ver>` |
| Tracks | [egao1980/cl-stack#46](https://github.com/egao1980/cl-stack/issues/46) |
| Upstream | [facebook/zstd](https://github.com/facebook/zstd) **v1.5.7** |

## Platforms

| OS | Arch | Runner |
|----|------|--------|
| linux | amd64 | `ubuntu-latest` |
| linux | arm64 | `ubuntu-24.04-arm` |
| darwin | arm64 | `macos-latest` |
| windows | amd64 | `windows-latest` |

## Consumer

```lisp
;; Lisp API is compression-protocol. CFFI stays internal.
(asdf:load-system "cl-stack-zstd")
(compression-protocol:decompress
 (compression-protocol:compress octets :algorithm :zstd)
 :algorithm :zstd)
```

Smoke (linux/amd64): `scripts/smoke-clean-container.sh` (no `LD_LIBRARY_PATH`).

## Build natives locally

```bash
./scripts/build-zstd.sh          # ZSTD_VERSION=1.5.7 by default
# → lib/<os>-<arch>/libzstd*
```
