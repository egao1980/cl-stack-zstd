(in-package #:cl-stack-zstd)

(defun %protocol-octets (data)
  (compression-protocol::%ensure-octets data))

(defun %as-compression-error (algorithm condition)
  (error 'compression-protocol:compression-error
         :algorithm algorithm
         :message (or (ignore-errors (zstd-error-message condition))
                      (princ-to-string condition))))

(macrolet ((define-zstd-codec (algorithm)
             `(progn
                (defmethod compression-protocol:compress-using-algorithm
                    ((algorithm (eql ,algorithm)) data &key level)
                  (handler-case
                      (compress (%protocol-octets data) :level (or level 3))
                    (zstd-error (c)
                      (%as-compression-error ,algorithm c))))
                (defmethod compression-protocol:decompress-using-algorithm
                    ((algorithm (eql ,algorithm)) data &key)
                  (handler-case
                      (decompress (%protocol-octets data))
                    (zstd-error (c)
                      (%as-compression-error ,algorithm c))))
                (defmethod compression-protocol:make-decompressing-stream-using-algorithm
                    ((algorithm (eql ,algorithm)) input &key)
                  (handler-case
                      (make-decompressing-stream input)
                    (zstd-error (c)
                      (%as-compression-error ,algorithm c)))))))
  (define-zstd-codec :zstd)
  (define-zstd-codec :zstandard))
