;;;; squiggle.asd
;;;; Every system is a strict-build system: any warning from compiling or loading
;;;; its own files, style-warnings included, fails the operation.

(asdf:defsystem :squiggle
  :description "A silly Jazz inspired living piece of art"
  :author "Real Limoges <b.real.limoges@gmail.com>"
  :license "BSD-2-Clause"
  :version "0.1.0"
  :defsystem-depends-on ("strict-build")
  :class "strict-build:strict-system"
  :default-component-class "strict-build:strict-source-file"
  :depends-on ()
  :pathname "src/"
  :serial t
  :components ((:file "package")
               (:file "frozen")
               (:file "types")))

(asdf:defsystem :squiggle/web
  :defsystem-depends-on ("strict-build")
  :class "strict-build:strict-system"
  :default-component-class "strict-build:strict-source-file"
  :depends-on (#:squiggle #:squiggle/backend
                          #:hunchentoot #:cl-who #:flexi-streams
                          #:bordeaux-threads)
  :pathname "src/web/"
  :serial t
  :components ((:file "package")
               (:file "svg")
               (:file "page")
               (:file "server")))

(asdf:defsystem :squiggle/oracle
  :defsystem-depends-on ("strict-build")
  :class "strict-build:strict-system"
  :default-component-class "strict-build:strict-source-file"
  :depends-on (#:squiggle #:dexador #:com.inuoe.jzon #:cl-ppcre)
  :pathname "src/oracle"
  :serial t
  :components ((:file "package")
               (:file "oracle")
               (:file "fake-oracle")
               (:file "corpus")
               (:file "llm-oracle")))

(asdf:defsystem :squiggle/backend
  :defsystem-depends-on ("strict-build")
  :class "strict-build:strict-system"
  :default-component-class "strict-build:strict-source-file"
  :depends-on (#:squiggle #:squiggle/oracle)
  :pathname "src/backend/"
  :serial t
  :components ((:file "package")
               (:file "tempo")
               (:file "backend")
               (:file "mutation")
               (:file "validator")
               (:file "inspect")))

(asdf:defsystem :squiggle/tests
  :defsystem-depends-on ("strict-build")
  :class "strict-build:strict-system"
  :default-component-class "strict-build:strict-source-file"
  :depends-on (#:fiveam
               #:squiggle #:squiggle/oracle #:squiggle/backend
               #:squiggle/web)
  :pathname "tests/"
  :serial t
  :components ((:file "package")
               (:file "build-tests")
               (:file "frozen-tests")
               (:file "mutation-tests")
               (:file "engine-tests")
               (:file "tempo-tests")
               (:file "web-tests"))
  :perform (asdf:test-op (op c)
                         (uiop:symbol-call :fiveam :run! :squiggle)))
