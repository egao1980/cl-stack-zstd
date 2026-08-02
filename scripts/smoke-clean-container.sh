#!/usr/bin/env bash
# Clean ubuntu:24.04 linux/amd64 smoke against GHCR cl-stack-zstd.
set -euo pipefail

VERSION="${1:-1.5.7}"
IMAGE="ghcr.io/egao1980/cl-systems/cl-stack-zstd:${VERSION}"
CACHE="${CACHE:-/tmp/cl-stack-zstd-smoke-cache}"
PKG="$CACHE/pkg/cl-stack-zstd-${VERSION}"
QL="$CACHE/quicklisp"

mkdir -p "$CACHE/pull" "$CACHE/pkg"
if [[ ! -f "$PKG/native/libzstd.so" ]]; then
  command -v oras >/dev/null || { echo "need oras" >&2; exit 1; }
  rm -rf "${CACHE}/pull/"* "${CACHE}/pkg/"*
  oras pull --platform linux/amd64 "$IMAGE" -o "$CACHE/pull/"
  for f in "$CACHE/pull"/*.tar.gz; do tar -xzf "$f" -C "$CACHE/pkg/"; done
fi

SMOKE_LISP="$CACHE/smoke.lisp"
cat >"$SMOKE_LISP" <<'EOF'
(require :asdf) (require :uiop)
(defvar *pkg* (uiop:getenv "CL_STACK_ZSTD_ROOT"))
(asdf:initialize-source-registry
 `(:source-registry (:directory ,(uiop:ensure-directory-pathname *pkg*))
                    :inherit-configuration))
(ql:quickload '("cffi" "cl-stack-zstd") :silent t)
(multiple-value-bind (ok ver) (cl-stack-zstd:ensure-zstd)
  (format t "~&ensure-zstd => ~A ~A~%" ok ver))
(let* ((s "hello zstd overlay")
       (raw (map '(simple-array (unsigned-byte 8) (*)) #'char-code s))
       (enc (cl-stack-zstd:compress raw :level 3))
       (dec (cl-stack-zstd:decompress enc)))
  (unless (equalp raw dec)
    (error "round-trip mismatch"))
  (format t "~&round-trip OK (~D -> ~D bytes)~%" (length raw) (length enc)))
(format t "~&SMOKE OK~%")
(uiop:quit 0)
EOF

if [[ ! -f "$QL/setup.lisp" ]]; then
  docker run --rm --platform linux/amd64 \
    -e DEBIAN_FRONTEND=noninteractive \
    -v "$QL:/ql" \
    ubuntu:24.04 \
    bash -c 'apt-get update -qq && apt-get install -y -qq ca-certificates curl sbcl >/dev/null \
      && curl -fsSL -o /tmp/ql.lisp https://beta.quicklisp.org/quicklisp.lisp \
      && sbcl --noinform --non-interactive --load /tmp/ql.lisp \
           --eval "(quicklisp-quickstart:install :path #p\"/ql/\")" >/dev/null'
fi

# Resolve natives via cffi:*foreign-library-directories* + absolute preload in
# ensure-zstd — never LD_LIBRARY_PATH (ignored mid-process on Linux anyway).
docker run --rm --platform linux/amd64 \
  -e DEBIAN_FRONTEND=noninteractive \
  -e CL_STACK_ZSTD_ROOT=/opt/cl-stack-zstd \
  -v "$PKG:/opt/cl-stack-zstd:ro" \
  -v "$QL:/ql:ro" \
  -v "$SMOKE_LISP:/opt/smoke.lisp:ro" \
  ubuntu:24.04 \
  bash -c 'apt-get update -qq && apt-get install -y -qq ca-certificates sbcl >/dev/null \
    && sbcl --noinform --non-interactive --load /ql/setup.lisp --load /opt/smoke.lisp'
