;;;; llm-oracle.lisp
;;;;
;;;; LLM-backed oracle. Peer to fake-oracle: same interface (state → mutations),
;;;; different implementation. Runtime config picks which one tick! calls.

(in-package :squiggle)

(defun llm-oracle (state rng)
  "Returns a list of 1-3 random valid mutations. STUB — copies fake-oracle
   until the HTTP client lands."
  (loop repeat (1+ (random 3 rng))
        collect (funcall (random-elt *generators* rng) state)))