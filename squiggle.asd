;;;; squiggle.asd

(asdf:defsystem :squiggle
  :description "A silly Jazz inspired living piece of art"
  :author "Real Limoges <b.real.limoges@gmail.com>"
  :license "MIT"
  :version "0.1.0"
  :depends-on (#:dexador #:com.inuoe.jzon)
  :pathname "src/"
  :serial t
  :components ((:file "package")
               (:file "squiggle")
               (:file "mutation")
               (:file "fake-oracle")
               (:file "llm-oracle")
               (:file "inspect")))

(asdf:defsystem :squiggle/tests
  :depends-on (#:squiggle #:fiveam)
  :pathname "tests/"
  :serial t
  :components ((:file "package")
               (:file "squiggle-tests")
               (:file "mutation-tests"))
  :perform (asdf:test-op (op c)
              (uiop:symbol-call :fiveam :run! :squiggle)))