;;;; squiggle.asd

(asdf:defsystem :squiggle
  :description "A silly Jazz inspired living piece of art"
  :author "Real Limoges <b.real.limoges@gmail.com>"
  :license "MIT"
  :version "0.1.0"
  :depends-on (#:dexador #:com.inuoe.jzon)
  :pathname "src/"
  :serial t
  :components ((:file "squiggle")
               (:file "fake-oracle")
               (:file "llm-oracle")
               (:file "mutation")))