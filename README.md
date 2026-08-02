# cl-stack-zstd

MIT. Ships **Zstandard** (`libzstd`) as
[cl-repository](https://github.com/egao1980/cl-repository) platform overlays,
plus a thin CFFI `compress` / `decompress` API for HTTP `Content-Encoding: zstd`.

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
;; cl-repository install writes cl-repo-init.lisp (pushes native/ + absolute preload).
;; Local/ASDF: ensure-zstd pushes system native/ and lib/<os>-<arch>/ onto
;; cffi:*foreign-library-directories* — do not set LD_LIBRARY_PATH.
(asdf:load-system "cl-stack-zstd")
(cl-stack-zstd:ensure-zstd) ; => T, "1.5.7"
(cl-stack-zstd:decompress (cl-stack-zstd:compress octets))
```

Smoke (linux/amd64): `scripts/smoke-clean-container.sh` (no `LD_LIBRARY_PATH`).

## Build natives locally

```bash
./scripts/build-zstd.sh          # ZSTD_VERSION=1.5.7 by default
# → lib/<os>-<arch>/libzstd*
```
