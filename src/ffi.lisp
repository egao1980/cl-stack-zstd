(in-package #:cl-stack-zstd)

(define-foreign-library libzstd
  (:darwin (:or "libzstd.1.dylib" "libzstd.dylib"))
  (:unix (:or "libzstd.so.1" "libzstd.so"))
  (:windows (:or "libzstd.dll" "zstd.dll"))
  (t (:default "libzstd")))

(defcfun ("ZSTD_compress" %zstd-compress) :size
  (dst :pointer)
  (dst-capacity :size)
  (src :pointer)
  (src-size :size)
  (compression-level :int))

(defcfun ("ZSTD_decompress" %zstd-decompress) :size
  (dst :pointer)
  (dst-capacity :size)
  (src :pointer)
  (compressed-size :size))

(defcfun ("ZSTD_compressBound" %zstd-compress-bound) :size
  (src-size :size))

(defcfun ("ZSTD_getFrameContentSize" %zstd-get-frame-content-size) :ullong
  (src :pointer)
  (src-size :size))

(defcfun ("ZSTD_isError" %zstd-is-error) :unsigned-int
  (code :size))

(defcfun ("ZSTD_getErrorName" %zstd-get-error-name) :string
  (code :size))

(defcfun ("ZSTD_versionString" %zstd-version-string) :string)

;;; ZSTD_CONTENTSIZE_UNKNOWN = (0ULL - 1); ZSTD_CONTENTSIZE_ERROR = (0ULL - 2)
(defconstant +zstd-contentsize-unknown+ #xFFFFFFFFFFFFFFFF)
(defconstant +zstd-contentsize-error+ #xFFFFFFFFFFFFFFFE)
