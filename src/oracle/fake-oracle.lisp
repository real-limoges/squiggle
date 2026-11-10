;;;; fake-oracle.lisp: one random valid mutation per call
;;;; A peer to the LLM oracle, not a stub: tests, the REPL and the LLM oracle's
;;;; fallback all run it.

(in-package :squiggle/oracle)

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
  (list #'gen-nudge #'gen-recolor #'gen-resize #'gen-add #'gen-remove))

(defun fake-oracle (state rng)
  (make-oracle-result
    :mutations (list (funcall (random-elt *generators* rng) state rng))
    :mood (1+ (random 10 rng))))

(setf *oracle* #'fake-oracle)
