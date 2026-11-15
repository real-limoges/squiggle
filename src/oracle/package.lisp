;;;; package.lisp: the oracles and the random draws they share
;;;; Kept out of the base package so the jzon and ppcre nicknames resolve
;;;; against deps the :squiggle/oracle system loads.

(defpackage :squiggle/oracle
  (:use :cl :squiggle)
  (:local-nicknames (:jzon :com.inuoe.jzon)
                    (:ppcre :cl-ppcre))
  (:export
   :random-elt :random-id :random-delta
   :load-passages! :next-passage!
   :propose
   :fake-oracle :make-fake-oracle
   :llm-oracle :make-llm-oracle
   :generate-mutation
   :use-fake-oracle! :use-llm-oracle!
   :*oracle*))
