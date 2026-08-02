(in-package #:cl-stack-zstd)

;;; Gray binary input streams over Zstd streaming C API.

(defclass zstd-stream (trivial-gray-streams:fundamental-binary-input-stream)
  ((source :initarg :source :reader zstd-stream-source)
   (ctx :initarg :ctx :accessor %zs-ctx)
   (fin :initarg :fin :reader %zs-fin)
   (fout :initarg :fout :reader %zs-fout)
   (fin-size :initarg :fin-size :reader %zs-fin-size)
   (fout-size :initarg :fout-size :reader %zs-fout-size)
   (fin-avail :initform 0 :accessor %zs-fin-avail)
   (fin-pos :initform 0 :accessor %zs-fin-pos)
   (fout-avail :initform 0 :accessor %zs-fout-avail)
   (fout-pos :initform 0 :accessor %zs-fout-pos)
   (source-eof :initform nil :accessor %zs-source-eof)
   (finished :initform nil :accessor %zs-finished)
   (closed :initform nil :accessor %zs-closed)))

(defclass zstd-decompressing-stream (zstd-stream) ())
(defclass zstd-compressing-stream (zstd-stream)
  ((ending :initform nil :accessor %zcs-ending)))

(defun make-decompressing-stream (source)
  "Return a binary input stream that decompresses octets read from SOURCE."
  (%load-native)
  (check-type source stream)
  (let ((ctx (%zstd-create-dstream)))
    (when (null-pointer-p ctx)
      (error 'zstd-error :message "ZSTD_createDStream failed"))
    (%check-zstd (%zstd-init-dstream ctx))
    (let* ((fin-size (max 1024 (%zstd-dstream-in-size)))
           (fout-size (max 1024 (%zstd-dstream-out-size)))
           (fin (foreign-alloc :uint8 :count fin-size))
           (fout (foreign-alloc :uint8 :count fout-size)))
      (make-instance 'zstd-decompressing-stream
                     :source source :ctx ctx
                     :fin fin :fout fout
                     :fin-size fin-size :fout-size fout-size))))

(defun make-compressing-stream (source &key (level 3))
  "Return a binary input stream that compresses octets read from SOURCE."
  (%load-native)
  (check-type source stream)
  (let ((ctx (%zstd-create-cstream)))
    (when (null-pointer-p ctx)
      (error 'zstd-error :message "ZSTD_createCStream failed"))
    (%check-zstd (%zstd-init-cstream ctx level))
    (let* ((fin-size (max 1024 (%zstd-cstream-in-size)))
           (fout-size (max 1024 (%zstd-cstream-out-size)))
           (fin (foreign-alloc :uint8 :count fin-size))
           (fout (foreign-alloc :uint8 :count fout-size)))
      (make-instance 'zstd-compressing-stream
                     :source source :ctx ctx
                     :fin fin :fout fout
                     :fin-size fin-size :fout-size fout-size))))

(defun %zs-close (stream free)
  (unless (%zs-closed stream)
    (setf (%zs-closed stream) t)
    (ignore-errors (funcall free (%zs-ctx stream)))
    (setf (%zs-ctx stream) (null-pointer))
    (foreign-free (%zs-fin stream))
    (foreign-free (%zs-fout stream)))
  t)

(defmethod close ((stream zstd-decompressing-stream) &key abort)
  (declare (ignore abort))
  (%zs-close stream #'%zstd-free-dstream))

(defmethod close ((stream zstd-compressing-stream) &key abort)
  (declare (ignore abort))
  (%zs-close stream #'%zstd-free-cstream))

(defun %zs-serve-byte (stream)
  (when (< (%zs-fout-pos stream) (%zs-fout-avail stream))
    (let ((b (mem-aref (%zs-fout stream) :uint8 (%zs-fout-pos stream))))
      (incf (%zs-fout-pos stream))
      b)))

(defun %zs-refill-input (stream)
  (when (and (zerop (- (%zs-fin-avail stream) (%zs-fin-pos stream)))
             (not (%zs-source-eof stream)))
    (let* ((lisp (make-array (%zs-fin-size stream) :element-type '(unsigned-byte 8)))
           (n (read-sequence lisp (zstd-stream-source stream))))
      (when (zerop n)
        (setf (%zs-source-eof stream) t)
        (return-from %zs-refill-input 0))
      (dotimes (i n)
        (setf (mem-aref (%zs-fin stream) :uint8 i) (aref lisp i)))
      (setf (%zs-fin-pos stream) 0
            (%zs-fin-avail stream) n)
      n)))

(defun %zds-pump (stream)
  (when (%zs-finished stream)
    (return-from %zds-pump t))
  (loop
    (when (< (%zs-fout-pos stream) (%zs-fout-avail stream))
      (return t))
    (%zs-refill-input stream)
    (with-foreign-objects ((in '(:struct zstd-in-buffer))
                           (out '(:struct zstd-out-buffer)))
      (let ((in-left (- (%zs-fin-avail stream) (%zs-fin-pos stream))))
        (setf (foreign-slot-value in '(:struct zstd-in-buffer) 'src)
              (if (plusp in-left)
                  (inc-pointer (%zs-fin stream) (%zs-fin-pos stream))
                  (null-pointer))
              (foreign-slot-value in '(:struct zstd-in-buffer) 'size) in-left
              (foreign-slot-value in '(:struct zstd-in-buffer) 'pos) 0
              (foreign-slot-value out '(:struct zstd-out-buffer) 'dst) (%zs-fout stream)
              (foreign-slot-value out '(:struct zstd-out-buffer) 'size) (%zs-fout-size stream)
              (foreign-slot-value out '(:struct zstd-out-buffer) 'pos) 0)
        (let ((code (%check-zstd (%zstd-decompress-stream (%zs-ctx stream) out in))))
          (let ((consumed (foreign-slot-value in '(:struct zstd-in-buffer) 'pos))
                (produced (foreign-slot-value out '(:struct zstd-out-buffer) 'pos)))
            (incf (%zs-fin-pos stream) consumed)
            (setf (%zs-fout-pos stream) 0
                  (%zs-fout-avail stream) produced)
            ;; Frame complete (0) — done once source is exhausted.
            (when (zerop code)
              (setf (%zs-finished stream) t)
              (return t))
            (when (plusp produced)
              (return t))
            ;; No progress with no input left → truncated / stuck.
            (when (and (%zs-source-eof stream)
                       (zerop (- (%zs-fin-avail stream) (%zs-fin-pos stream)))
                       (zerop consumed))
              (error 'zstd-error :message "truncated Zstd stream"))))))))
(defun %zcs-pump (stream)
  (when (%zs-finished stream)
    (return-from %zcs-pump t))
  (loop
    (when (< (%zs-fout-pos stream) (%zs-fout-avail stream))
      (return t))
    (unless (%zcs-ending stream)
      (when (zerop (- (%zs-fin-avail stream) (%zs-fin-pos stream)))
        (%zs-refill-input stream)
        (when (%zs-source-eof stream)
          (setf (%zcs-ending stream) t))))
    (with-foreign-objects ((in '(:struct zstd-in-buffer))
                           (out '(:struct zstd-out-buffer)))
      (let ((in-left (- (%zs-fin-avail stream) (%zs-fin-pos stream)))
            (end-op (if (%zcs-ending stream) :end :continue)))
        (setf (foreign-slot-value in '(:struct zstd-in-buffer) 'src)
              (if (plusp in-left)
                  (inc-pointer (%zs-fin stream) (%zs-fin-pos stream))
                  (null-pointer))
              (foreign-slot-value in '(:struct zstd-in-buffer) 'size) in-left
              (foreign-slot-value in '(:struct zstd-in-buffer) 'pos) 0
              (foreign-slot-value out '(:struct zstd-out-buffer) 'dst) (%zs-fout stream)
              (foreign-slot-value out '(:struct zstd-out-buffer) 'size) (%zs-fout-size stream)
              (foreign-slot-value out '(:struct zstd-out-buffer) 'pos) 0)
        (let ((code (%check-zstd
                     (%zstd-compress-stream2 (%zs-ctx stream) out in end-op))))
          (let ((consumed (foreign-slot-value in '(:struct zstd-in-buffer) 'pos))
                (produced (foreign-slot-value out '(:struct zstd-out-buffer) 'pos)))
            (incf (%zs-fin-pos stream) consumed)
            (setf (%zs-fout-pos stream) 0
                  (%zs-fout-avail stream) produced)
            (when (and (%zcs-ending stream) (zerop code))
              (setf (%zs-finished stream) t))
            (when (or (plusp produced) (%zs-finished stream))
              (return t))))))))

(defmethod trivial-gray-streams:stream-read-byte ((stream zstd-decompressing-stream))
  (or (%zs-serve-byte stream)
      (progn (%zds-pump stream)
             (or (%zs-serve-byte stream) :eof))))

(defmethod trivial-gray-streams:stream-read-byte ((stream zstd-compressing-stream))
  (or (%zs-serve-byte stream)
      (progn (%zcs-pump stream)
             (or (%zs-serve-byte stream) :eof))))

(defun %zs-read-sequence (stream seq start end pump)
  (let ((i start))
    (loop while (< i end)
          do (let ((b (or (%zs-serve-byte stream)
                          (progn (funcall pump stream)
                                 (%zs-serve-byte stream)))))
               (unless b (return i))
               (setf (aref seq i) b)
               (incf i)))
    i))

(defmethod trivial-gray-streams:stream-read-sequence
    ((stream zstd-decompressing-stream) seq start end &key)
  (%zs-read-sequence stream seq start end #'%zds-pump))

(defmethod trivial-gray-streams:stream-read-sequence
    ((stream zstd-compressing-stream) seq start end &key)
  (%zs-read-sequence stream seq start end #'%zcs-pump))
