(defpackage #:cl-stack-zstd
  (:use #:cl #:cffi)
  (:export #:+zstd-version+
           #:zstd-error
           #:compress
           #:decompress))
