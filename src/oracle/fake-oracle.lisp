;;;; fake-oracle.lisp
;;;;
;;;; This contains the fake oracle for development

(in-package :squiggle/oracle)

;;; Stands in for the model: returns one random valid mutation per call.

(defun random-factor (rng)
  "A resize factor in [0.8, 1.2]."
  (+ 0.8 (/ (random 41 rng) 100.0)))

(defun gen-nudge   (state rng) (list :nudge (random-id state rng) (random-delta rng) (random-delta rng)))
(defun gen-recolor (state rng) (list :recolor (random-id state rng) (random-elt +palette+ rng)))
(defun gen-resize  (state rng) (list :resize (random-id state rng) (random-factor rng)))
(defun gen-add     (state rng) (declare (ignore state))
  (list :add (random-elt +entity-types+ rng)
        (random +canvas-w+ rng) (random +canvas-h+ rng) (random-elt +palette+ rng)))
(defun gen-remove  (state rng) (list :remove (random-id state rng)))

(defparameter *generators*
  (list #'gen-nudge #'gen-recolor #'gen-resize #'gen-add #'gen-remove)
  "All mutation generators the fake oracle can draw from.")

(defun fake-oracle (state rng)
  "Return an oracle-result: one random valid mutation for STATE + a random mood (1–10)."
  (make-oracle-result
    :mutations (list (funcall (random-elt *generators* rng) state rng))
    :mood (1+ (random 10 rng))))

(setf *oracle* #'fake-oracle)