(in-package #:cl-stack-zstd)

;; defparameter: SBCL DEFCONSTANT on strings trips DEFCONSTANT-UNEQL on reload.
(defparameter +zstd-version+ "1.5.7"
  "Zstd release this package version tracks (must match ASDF :version / OCI tag).")

(define-condition zstd-error (error)
  ((message :initarg :message :reader zstd-error-message))
  (:report (lambda (c s)
             (format s "Zstd error: ~A" (zstd-error-message c)))))

(defvar *zstd-loaded* nil)

(defun %host-os ()
  #+windows "windows"
  #+darwin "darwin"
  #+linux "linux"
  #-(or windows darwin linux) "unknown")

(defun %host-arch ()
  #+(or x86-64 x64) "amd64"
  #+(or arm64 aarch64) "arm64"
  #-(or x86-64 x64 arm64 aarch64) "unknown")

(defun %native-search-dirs ()
  "Overlay native/ (OCI) and lib/<os>-<arch>/ (local build). No LD_LIBRARY_PATH."
  (let ((dirs '()))
    (let ((v (uiop:getenv "CL_STACK_ZSTD_NATIVE")))
      (when (and v (plusp (length v)))
        (push v dirs)))
    (ignore-errors
      (let* ((sys (asdf:find-system :cl-stack-zstd nil))
             (root (when sys (asdf:system-source-directory sys))))
        (when root
          (push (namestring (merge-pathnames "native/" root)) dirs)
          (push (namestring
                 (merge-pathnames (format nil "lib/~A-~A/" (%host-os) (%host-arch)) root))
                dirs))))
    (nreverse dirs)))

(defun %lib-candidates ()
  #+windows '("libzstd.dll" "zstd.dll")
  #+darwin '("libzstd.dylib" "libzstd.1.dylib")
  #+(and unix (not darwin)) '("libzstd.so" "libzstd.so.1")
  #-(or windows darwin unix) '("libzstd.so"))

(defun %find-libzstd (dir)
  (dolist (name (%lib-candidates))
    (let ((p (merge-pathnames name (uiop:ensure-directory-pathname dir))))
      (when (probe-file p)
        (return (namestring (truename p)))))))

(defun %absolute-preload (dir)
  "Load libzstd by absolute path (cl-repository post-install policy)."
  (let ((p (%find-libzstd dir)))
    (when p
      (load-foreign-library p)
      t)))

(defun %load-native ()
  "Load libzstd via CFFI search path / absolute preload (not LD_LIBRARY_PATH).
   Invoked at ASDF load — consumers just call COMPRESS / DECOMPRESS."
  (unless *zstd-loaded*
    (let ((preloaded nil))
      (dolist (dir (%native-search-dirs))
        (when (and dir (uiop:directory-exists-p dir))
          (pushnew dir cffi:*foreign-library-directories* :test #'equal)
          (unless preloaded
            (setf preloaded (%absolute-preload dir)))))
      (unless preloaded
        (load-foreign-library 'libzstd)))
    (setf *zstd-loaded* t))
  (values t +zstd-version+))

(defun %check-zstd (code)
  (when (plusp (%zstd-is-error code))
    (error 'zstd-error :message (%zstd-get-error-name code)))
  code)

(defun %octet-vector (octets)
  (etypecase octets
    ((simple-array (unsigned-byte 8) (*)) octets)
    ((vector (unsigned-byte 8))
     (make-array (length octets) :element-type '(unsigned-byte 8) :initial-contents octets))))

(defun compress (octets &key (level 3))
  "Compress OCTETS with Zstd. LEVEL typically 1..22 (default 3). Returns octet vector."
  (%load-native)
  (check-type level (integer -131072 22))
  (let* ((in (%octet-vector octets))
         (in-len (length in))
         (bound (%zstd-compress-bound in-len)))
    (with-foreign-object (out :uint8 bound)
      (with-pointer-to-vector-data (in-ptr in)
        (let ((n (%check-zstd (%zstd-compress out bound in-ptr in-len level))))
          (let ((result (make-array n :element-type '(unsigned-byte 8))))
            (loop for i below n do (setf (aref result i) (mem-aref out :uint8 i)))
            result))))))

(defun decompress (octets &key max-decompressed-size)
  "Decompress Zstd OCTETS. When frame content size is unknown, grows up to
   MAX-DECOMPRESSED-SIZE (default 64 MiB)."
  (%load-native)
  (let* ((in (%octet-vector octets))
         (in-len (length in))
         (max-cap (or max-decompressed-size (* 64 1024 1024))))
    (with-pointer-to-vector-data (in-ptr in)
      (let ((frame-size (%zstd-get-frame-content-size in-ptr in-len)))
        (cond
          ((= frame-size +zstd-contentsize-error+)
           (error 'zstd-error :message "ZSTD_getFrameContentSize: not a valid frame"))
          ((and (/= frame-size +zstd-contentsize-unknown+)
                (<= frame-size max-cap))
           (let ((cap frame-size))
             (with-foreign-object (out :uint8 (max cap 1))
               (let ((n (%check-zstd (%zstd-decompress out (max cap 1) in-ptr in-len))))
                 (let ((result (make-array n :element-type '(unsigned-byte 8))))
                   (loop for i below n do (setf (aref result i) (mem-aref out :uint8 i)))
                   result)))))
          (t
           (let ((cap (min max-cap (max 1024 (* 8 in-len)))))
             (loop
               (when (> cap max-cap)
                 (error 'zstd-error
                        :message (format nil "decompressed size exceeds ~D bytes" max-cap)))
               (with-foreign-object (out :uint8 cap)
                 (let ((code (%zstd-decompress out cap in-ptr in-len)))
                   (if (plusp (%zstd-is-error code))
                       (let ((name (%zstd-get-error-name code)))
                         (if (search "dstSize_tooSmall" name :test #'char-equal)
                             (setf cap (min max-cap (* 2 cap)))
                             (error 'zstd-error :message name)))
                       (let ((result (make-array code :element-type '(unsigned-byte 8))))
                         (loop for i below code
                               do (setf (aref result i) (mem-aref out :uint8 i)))
                         (return result)))))))))))))
