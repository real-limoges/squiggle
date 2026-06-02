;;;; package.lisp
;;;;
;;;; :squiggle/oracle — oracle implementations and shared random-draw substrate.
;;;; Defined here (not in the base package file) so its jzon/ppcre nicknames
;;;; resolve against deps loaded by the :squiggle/oracle system.

(defpackage :squiggle/oracle
  (:use :cl :squiggle)
  (:local-nicknames (:jzon :com.inuoe.jzon)
                    (:ppcre :cl-ppcre))
  (:export
   :random-elt :random-id :random-delta
   :load-passages! :next-passage!
   :fake-oracle :llm-oracle
   :use-fake-oracle! :use-llm-oracle!
   :*generators* :*oracle*))
