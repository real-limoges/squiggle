;;;; oracle.lisp: the active oracle and the random draws both oracles use

(in-package :squiggle/oracle)

(defvar *oracle* nil)

(defun random-elt (seq rng)
  (elt seq (random (length seq) rng)))

(defun random-id (state rng)
  (entity-id (random-elt (entities state) rng)))

(defun random-delta (rng)
  "An offset in [-40, 40]."
  (- (random 81 rng) 40))


(defun use-llm-oracle! () (setf *oracle* #'llm-oracle))

(defun use-fake-oracle! () (setf *oracle* #'fake-oracle))
