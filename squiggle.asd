;;;; squiggle.asd

(asdf:defsystem :squiggle
  :description "A silly Jazz inspired living piece of art"
  :author "Real Limoges <b.real.limoges@gmail.com>"
  :license "MIT"
  :version "0.1.0"
  :depends-on ()
  :pathname "src/"
  :serial t
  :components ((:file "package")
               (:file "types")))

(asdf:defsystem :squiggle/oracle
  :depends-on (#:squiggle #:dexador #:com.inuoe.jzon #:cl-ppcre)
  :pathname "src/oracle"
  :serial t
  :components ((:file "oracle")
               (:file "fake-oracle")
               (:file "corpus")
               (:file "llm-oracle")))

(asdf:defsystem :squiggle/backend
  :depends-on (#:squiggle #:squiggle/oracle)
  :pathname "src/backend/"
  :serial t
  :components ((:file "backend")
               (:file "mutation")
               (:file "inspect")))

(asdf:defsystem :squiggle/tests
  :depends-on (#:fiveam
               #:squiggle #:squiggle/oracle #:squiggle/backend)
  :pathname "tests/"
  :serial t
  :components ((:file "package")
               (:file "mutation-tests"))
  :perform (asdf:test-op (op c)
              (uiop:symbol-call :fiveam :run! :squiggle)))