(defsystem "cl-stack-zstd"
  :version "1.5.7"
  :description "Zstandard native overlays + thin CFFI for cl-stack Content-Encoding"
  :author "egao1980"
  :license "MIT"
  :depends-on ("cffi")
  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "ffi")
               (:file "api"))
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
