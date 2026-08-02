(in-package #:cl-stack-zstd)

(define-foreign-library libzstd
  (:darwin (:or "libzstd.1.dylib" "libzstd.dylib"))
  (:unix (:or "libzstd.so.1" "libzstd.so"))
  (:windows (:or "libzstd.dll" "zstd.dll"))
  (t (:default "libzstd")))

(defcstruct zstd-in-buffer
  (src :pointer)
  (size :size)
  (pos :size))

(defcstruct zstd-out-buffer
  (dst :pointer)
  (size :size)
  (pos :size))

(defcenum zstd-end-directive
  (:continue 0)
  (:flush 1)
  (:end 2))

;;; --- one-shot ---

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

;;; --- streaming decode (DStream ≡ DCtx since v1.3) ---

(defcfun ("ZSTD_createDStream" %zstd-create-dstream) :pointer)

(defcfun ("ZSTD_freeDStream" %zstd-free-dstream) :size
  (zds :pointer))

(defcfun ("ZSTD_initDStream" %zstd-init-dstream) :size
  (zds :pointer))

(defcfun ("ZSTD_decompressStream" %zstd-decompress-stream) :size
  (zds :pointer)
  (output (:pointer (:struct zstd-out-buffer)))
  (input (:pointer (:struct zstd-in-buffer))))

(defcfun ("ZSTD_DStreamInSize" %zstd-dstream-in-size) :size)
(defcfun ("ZSTD_DStreamOutSize" %zstd-dstream-out-size) :size)

;;; --- streaming encode ---

(defcfun ("ZSTD_createCStream" %zstd-create-cstream) :pointer)

(defcfun ("ZSTD_freeCStream" %zstd-free-cstream) :size
  (zcs :pointer))

(defcfun ("ZSTD_initCStream" %zstd-init-cstream) :size
  (zcs :pointer)
  (compression-level :int))

(defcfun ("ZSTD_compressStream2" %zstd-compress-stream2) :size
  (cctx :pointer)
  (output (:pointer (:struct zstd-out-buffer)))
  (input (:pointer (:struct zstd-in-buffer)))
  (end-op zstd-end-directive))

(defcfun ("ZSTD_CStreamInSize" %zstd-cstream-in-size) :size)
(defcfun ("ZSTD_CStreamOutSize" %zstd-cstream-out-size) :size)

;;; ZSTD_CONTENTSIZE_UNKNOWN = (0ULL - 1); ZSTD_CONTENTSIZE_ERROR = (0ULL - 2)
(defconstant +zstd-contentsize-unknown+ #xFFFFFFFFFFFFFFFF)
(defconstant +zstd-contentsize-error+ #xFFFFFFFFFFFFFFFE)
