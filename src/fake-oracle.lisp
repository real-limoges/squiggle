;;;; fake-oracle.lisp
;;;;
;;;; This contains the fake oracle for development

(in-package :squiggle)

;;; Stands in for the model: returns 1–3 random valid mutations.

(defun random-elt (seq rng)
  (elt seq (random (length seq) rng)))

(defun random-id (state rng)
  (getf (random-elt (entities state) rng) :id))

(defun random-delta (rng)
  "A small offset in [-40, 40]."
  (- (random 81 rng) 40))

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
  "Return a list of 1–3 random valid mutations for STATE."
  (loop repeat (1+ (random 3 rng))
        collect (funcall (random-elt *generators* rng) state rng)))