#!/usr/bin/env bash
# Build shared libzstd into lib/<os>-<arch>/.
# Usage: ./scripts/build-zstd.sh
# Env: ZSTD_VERSION (default 1.5.7), DEST_DIR (optional override)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ZSTD_VERSION="${ZSTD_VERSION:-1.5.7}"
JOBS="$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)"

uname_s="$(uname -s)"
uname_m="$(uname -m)"
case "$uname_s" in
  Linux) os=linux ;;
  Darwin) os=darwin ;;
  *) echo "unsupported OS: $uname_s (Windows: use build-zstd.ps1)" >&2; exit 1 ;;
esac
case "$uname_m" in
  x86_64|amd64) arch=amd64 ;;
  aarch64|arm64) arch=arm64 ;;
  *) echo "unsupported arch: $uname_m" >&2; exit 1 ;;
esac

OUT="${DEST_DIR:-$ROOT/lib/${os}-${arch}}"
BUILD="$ROOT/build/zstd-${ZSTD_VERSION}-${os}-${arch}"
SRC_TGZ="$ROOT/build/zstd-${ZSTD_VERSION}.tar.gz"
SRC_URL="https://github.com/facebook/zstd/releases/download/v${ZSTD_VERSION}/zstd-${ZSTD_VERSION}.tar.gz"

mkdir -p "$ROOT/build" "$OUT"
if [[ ! -f "$SRC_TGZ" ]]; then
  echo "==> download $SRC_URL"
  curl -fsSL "$SRC_URL" -o "$SRC_TGZ"
fi

rm -rf "$BUILD"
mkdir -p "$BUILD"
tar -xzf "$SRC_TGZ" -C "$BUILD" --strip-components=1

echo "==> cmake/build zstd ${ZSTD_VERSION} -> $OUT"
# Prefer build/cmake entry (stable across zstd releases).
CMAKE_SRC="$BUILD/build/cmake"
if [[ ! -f "$CMAKE_SRC/CMakeLists.txt" ]]; then
  CMAKE_SRC="$BUILD"
fi
cmake -S "$CMAKE_SRC" -B "$BUILD/build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$BUILD/prefix" \
  -DZSTD_BUILD_SHARED=ON \
  -DZSTD_BUILD_STATIC=OFF \
  -DZSTD_BUILD_PROGRAMS=OFF \
  -DZSTD_BUILD_TESTS=OFF \
  -DBUILD_SHARED_LIBS=ON
cmake --build "$BUILD/build" -j"$JOBS"
cmake --install "$BUILD/build"

rm -rf "$OUT"
mkdir -p "$OUT"
shopt -s nullglob
libs=(
  "$BUILD/prefix/lib"/libzstd.so*
  "$BUILD/prefix/lib"/libzstd*.dylib
  "$BUILD/prefix/lib64"/libzstd.so*
)
if ((${#libs[@]} == 0)); then
  echo "libzstd shared library not found under $BUILD/prefix" >&2
  ls -la "$BUILD/prefix/lib" "$BUILD/prefix/lib64" 2>/dev/null || true
  exit 1
fi
cp -a "${libs[@]}" "$OUT/"

if [[ "$os" == "linux" ]]; then
  if [[ ! -e "$OUT/libzstd.so" ]]; then
    cand="$(ls -1 "$OUT"/libzstd.so.* 2>/dev/null | head -1 || true)"
    [[ -n "$cand" ]] && ln -sfn "$(basename "$cand")" "$OUT/libzstd.so"
  fi
  if command -v patchelf >/dev/null; then
    for f in "$OUT"/libzstd.so*; do
      [[ -f "$f" && ! -L "$f" ]] || continue
      patchelf --set-rpath '$ORIGIN' "$f"
    done
  fi
elif [[ "$os" == "darwin" ]]; then
  if [[ ! -e "$OUT/libzstd.dylib" ]]; then
    cand="$(ls -1 "$OUT"/libzstd.*.dylib 2>/dev/null | head -1 || true)"
    [[ -n "$cand" ]] && ln -sfn "$(basename "$cand")" "$OUT/libzstd.dylib"
  fi
  if command -v install_name_tool >/dev/null; then
    for f in "$OUT"/libzstd*.dylib; do
      [[ -f "$f" && ! -L "$f" ]] || continue
      install_name_tool -id "@loader_path/$(basename "$f")" "$f" 2>/dev/null || true
    done
  fi
fi

echo "==> staged:"
ls -la "$OUT"
echo "OK: zstd ${ZSTD_VERSION} -> ${os}/${arch}"
