;;;; oracle.lisp: the oracle interface, the active oracle, and the random draws
;;;; both oracles use

(in-package :squiggle/oracle)

(defstruct fake-oracle)

(defstruct llm-oracle
  "A llama-server on localhost; the model is whichever GGUF it was started with"
  (url "http://localhost:8081/v1/chat/completions" :read-only t))

(defvar *oracle* (make-fake-oracle)
  "The oracle the running piece ticks with")

(defgeneric propose (oracle canvas rng)
  (:documentation "An oracle-result of mutations for CANVAS and a mood."))

(defun random-elt (seq rng)
  (elt seq (random (length seq) rng)))

(defun random-id (canvas rng)
  (entity-id (random-elt (entities canvas) rng)))

(defun random-delta (rng)
  "An offset in [-40, 40]."
  (- (random 81 rng) 40))

(defun use-llm-oracle! () (setf *oracle* (make-llm-oracle)))

(defun use-fake-oracle! () (setf *oracle* (make-fake-oracle)))
