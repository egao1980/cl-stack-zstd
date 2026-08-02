(in-package #:cl-stack-zstd/tests)

(deftest version
  (ok (string= +zstd-version+ "1.5.7")))

(deftest buffer-round-trip
  (let* ((raw (%bytes "hello zstd content-encoding"))
         (enc (compress raw :level 3))
         (dec (decompress enc)))
    (ok (plusp (length enc)))
    (ok (not (equalp raw enc)))
    (ok (equalp raw dec))))

(deftest buffer-empty
  (let* ((raw (make-array 0 :element-type '(unsigned-byte 8)))
         (enc (compress raw :level 1))
         (dec (decompress enc)))
    (ok (equalp raw dec))))

(deftest buffer-binary
  (let* ((raw (make-array 4096 :element-type '(unsigned-byte 8)
                          :initial-contents (loop for i below 4096 collect (mod (* i 17) 256))))
         (enc (compress raw :level 5))
         (dec (decompress enc)))
    (ok (< (length enc) (length raw)))
    (ok (equalp raw dec))))

(deftest bad-input
  (ok (signals (decompress (%bytes "not-zstd!!!!")) 'zstd-error)))
