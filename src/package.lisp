(defpackage #:cl-stack-zstd
  (:use #:cl #:cffi)
  (:export #:+zstd-version+
           #:zstd-error
           #:ensure-zstd
           #:compress
           #:decompress))
