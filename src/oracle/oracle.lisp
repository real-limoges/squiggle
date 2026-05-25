;;;; oracle.lisp
;;;;
;;;; main spot for all oracle stuff

(in-package :squiggle/oracle)

(defvar *oracle* nil
  "The active oracle function. Set on load; swap at runtime to change oracles.")

(defun random-elt (seq rng)
  (elt seq (random (length seq) rng)))

(defun random-id (state rng)
  (entity-id (random-elt (entities state) rng)))

(defun random-delta (rng)
  "A small offset in [-40, 40]."
  (- (random 81 rng) 40))