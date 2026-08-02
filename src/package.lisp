(defpackage #:cl-stack-zstd
  (:use #:cl #:cffi)
  (:export #:+zstd-version+
           #:zstd-error
           #:compress
           #:decompress
           #:make-decompressing-stream
           #:make-compressing-stream
           #:zstd-decompressing-stream
           #:zstd-compressing-stream))
