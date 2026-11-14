;;;; fake-oracle.lisp: one random valid mutation per call
;;;; A peer to the LLM oracle, not a stub: tests, the REPL and the LLM oracle's
;;;; fallback all run it.

(in-package :squiggle/oracle)

(defparameter +fake-verbs+ '(:nudge :recolor :resize :add :remove)
  "The verbs the fake oracle picks from, one per call")

(defun random-factor (rng)
  "A resize factor in [0.8, 1.2]."
  (+ 0.8 (/ (random 41 rng) 100.0)))

(defun random-add (rng)
  (list :add (random-elt +entity-types+ rng)
        (random +canvas-w+ rng) (random +canvas-h+ rng) (random-elt +palette+ rng)))

(defun generate-mutation (verb canvas rng)
  "A random mutation with VERB against CANVAS."
  (ecase verb
    (:nudge   (list :nudge (random-id canvas rng) (random-delta rng) (random-delta rng)))
    (:recolor (list :recolor (random-id canvas rng) (random-elt +palette+ rng)))
    (:resize  (list :resize (random-id canvas rng) (random-factor rng)))
    (:add     (random-add rng))
    (:remove  (list :remove (random-id canvas rng)))))

(defmethod propose ((fake-oracle fake-oracle) canvas rng)
  (make-oracle-result
    :mutations (list (generate-mutation (random-elt +fake-verbs+ rng) canvas rng))
    :mood (1+ (random 10 rng))))
