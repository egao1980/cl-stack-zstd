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
;; After cl-repository install (native/ on CFFI / loader path):
(asdf:load-system "cl-stack-zstd")
(cl-stack-zstd:ensure-zstd) ; => T, "1.5.7"
(cl-stack-zstd:decompress (cl-stack-zstd:compress octets))
```

```bash
export LD_LIBRARY_PATH="$HOME/.local/share/cl-systems/cl-stack-zstd-1.5.7/native${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
```

Smoke (linux/amd64): `scripts/smoke-clean-container.sh`.

## Build natives locally

```bash
./scripts/build-zstd.sh          # ZSTD_VERSION=1.5.7 by default
# → lib/<os>-<arch>/libzstd*
```
