;;;; fake-oracle.lisp
;;;;
;;;; This contains the fake oracle for development

(in-package :squiggle)

;;; Stands in for the model: returns 1–3 random valid mutations.

(defun random-elt (seq)
  (elt seq (random (length seq))))

(defun random-id (state)
  (getf (random-elt (entities state)) :id))

(defun random-delta ()
  "A small offset in [-40, 40]."
  (- (random 81) 40))

(defun random-factor ()
  "A resize factor in [0.8, 1.2]."
  (+ 0.8 (/ (random 41) 100.0)))

(defun gen-nudge   (state) (list :nudge (random-id state) (random-delta) (random-delta)))
(defun gen-recolor (state) (list :recolor (random-id state) (random-elt *palette*)))
(defun gen-resize  (state) (list :resize (random-id state) (random-factor)))
(defun gen-add     (state) (declare (ignore state))
  (list :add (random-elt +entity-types+)
        (random +canvas-w+) (random +canvas-h+) (random-elt *palette*)))
(defun gen-remove  (state) (list :remove (random-id state)))

(defparameter *generators*
  (list #'gen-nudge #'gen-recolor #'gen-resize #'gen-add #'gen-remove)
  "All mutation generators the fake oracle can draw from.")

(defun fake-oracle (state)
  "Return a list of 1–3 random valid mutations for STATE."
  (loop repeat (1+ (random 3))
        collect (funcall (random-elt *generators*) state)))