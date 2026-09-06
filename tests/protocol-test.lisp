(in-package #:cl-stack-zstd/tests)

(deftest protocol-zstd-roundtrip
  (let* ((raw (%bytes "hello compression-protocol zstd"))
         (enc (compression-protocol:compress raw :algorithm :zstd :level 3))
         (dec (compression-protocol:decompress enc :algorithm :zstd)))
    (ok (plusp (length enc)))
    (ok (equalp raw dec))))
