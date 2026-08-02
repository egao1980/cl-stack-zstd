#!/usr/bin/env bash
# Rewrite ASDF :version and +zstd-version+ to match the published Zstd release.
# Usage: ./scripts/sync-package-version.sh <version>
set -euo pipefail

VERSION="${1:?version required}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

sed -i.bak 's/:version "[^"]*"/:version "'"${VERSION}"'"/' "$ROOT/cl-stack-zstd.asd"
sed -i.bak 's/(defparameter +zstd-version+ "[^"]*"/(defparameter +zstd-version+ "'"${VERSION}"'"/' "$ROOT/src/api.lisp"
rm -f "$ROOT/cl-stack-zstd.asd.bak" "$ROOT/src/api.lisp.bak"
