(defsystem "cl-stack-zstd"
  :version "1.5.7"
  :description "Zstandard native overlays + thin CFFI for cl-stack Content-Encoding"
  :author "egao1980"
  :license "MIT"
  :depends-on ("cffi" "trivial-gray-streams")
  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "ffi")
               (:file "api")
               (:file "streams"))
  :in-order-to ((test-op (test-op "cl-stack-zstd/tests")))
  :properties
  (:cl-repo
   (:cffi-libraries ("libzstd")
    :provides ("cl-stack-zstd")
    :overlays
    ((:platform (:os "linux" :arch "amd64")
      :layers ((:role "native-library"
                :files (("lib/linux-amd64/libzstd.so" . "libzstd.so")))))
     (:platform (:os "linux" :arch "arm64")
      :layers ((:role "native-library"
                :files (("lib/linux-arm64/libzstd.so" . "libzstd.so")))))
     (:platform (:os "darwin" :arch "arm64")
      :layers ((:role "native-library"
                :files (("lib/darwin-arm64/libzstd.dylib" . "libzstd.dylib")))))
     (:platform (:os "windows" :arch "amd64")
      :layers ((:role "native-library"
                :files (("lib/windows-amd64/libzstd.dll" . "libzstd.dll")))))))))

(defsystem "cl-stack-zstd/tests"
  :depends-on ("cl-stack-zstd" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "api-test")
               (:file "streams-test"))
  :perform (test-op (o c) (symbol-call :rove :run c)))
