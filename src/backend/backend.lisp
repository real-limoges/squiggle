;;;; backend.lisp
;;;;
;;;; A self-evolving abstract composition based on the Jazz design


(in-package :squiggle/backend)

;;; --- RNG ---

(defvar *oracle-rng* nil)
(defvar *jitter-rng* nil)

(defun entropy-seed ()
  "Return a fresh integer seed from OS entropy"
  (random most-positive-fixnum (make-random-state t)))

(defun make-rng (seed)
  "Return a fresh random-state seeded deterministically from SEED"
  (sb-ext:seed-random-state seed))

(defun seed-rngs! (main-seed)
  "Derive both engine RNGs from MAIN-SEED. Used by tests."
  (setf *oracle-rng* (make-rng main-seed)
        *jitter-rng* (make-rng (logxor main-seed #xA5A5A5A5))))

;;; --- STATE ---

(defparameter *state* (make-canvas))

;;; --- STATE CONSTRUCTORS ---
;;; Every change returns a NEW state — never mutate in place.

(defun with-entities (state new-entities)
  "Return a copy of STATE whose entity list is NEW-ENTITIES."
  (let ((copy (copy-canvas state)))
    (setf (canvas-entities copy) new-entities)
    copy))

(defun update-entity (state id fn)
  "Return a new state where entity ID has been replaced by (FN entity).
   If ID doesn't exist, return STATE unchanged. This single helper absorbs
   the find/copy/replace pattern that every modifying verb used to repeat."
  (if (null (find-entity state id))
      state
      (with-entities
        state
        (mapcar (lambda (e)
                  (if (= (entity-id e) id) (funcall fn (copy-entity e)) e))
                (entities state)))))

;;; --- DISPATCH ---

(defun stamp-layers (mutations jitter-rng)
  "Rewrites each :add in MUTATIONS to carry a random :layer drawn from JITTER-RNG"
  (mapcar (lambda (m)
          (if (eq (first m) :add)
              (append m (list :layer (random most-positive-fixnum jitter-rng)))
              m))
              mutations))

(defun apply-mutation (state mutation)
  "Apply a single MUTATION s-expression to STATE, returning a new state.
   Unknown verbs are ignored."
  (let ((op (first mutation))
        (args (rest mutation)))
    (case op
      (:nudge   (apply #'apply-nudge   state args))
      (:recolor (apply #'apply-recolor state args))
      (:resize  (apply #'apply-resize  state args))
      (:add     (apply #'apply-add     state args))
      (:remove  (apply #'apply-remove  state args))
      (otherwise state))))

(defun apply-mutations (state mutations)
  "Apply a LIST of mutations in order, threading the state through each."
  (reduce #'apply-mutation mutations :initial-value state))

;;; --- JITTER ---

(defparameter +jitter-nudge-prob+ 0.3)
(defparameter +jitter-recolor-prob+ 0.05)

(defparameter +jitter-magnitude+ 3)

(defun random-signed (n rng)
  "Return a random integer in [-N, N] inclusive, drawn from RNG."
  (- (random (1+ (* 2 n)) rng) n))

(defun make-nudge (entity rng)
  "Return a :nudge mutation shifting ENTITY by a sub-perceptual random offset."
  (let ((dx (random-signed +jitter-magnitude+ rng))
        (dy (random-signed +jitter-magnitude+ rng)))
    (list :nudge (entity-id entity) dx dy)))

(defun make-recolor (entity rng)
  "Return a :recolor mutation assigning ENTITY a random color from +PALETTE+."
  (list :recolor (entity-id entity) (squiggle/oracle:random-elt +palette+ rng)))

(defun jitter-mutations (state rng)
  "Return a list of sub-perceptual :nudge/:recolor mutations for STATE's entities.
   Each entity rolls independently for nudge and (separately) for recolor."
  (loop for e in (entities state)
          when (< (random 1.0 rng) +jitter-nudge-prob+)
            collect (make-nudge e rng)
          when (< (random 1.0 rng) +jitter-recolor-prob+)
            collect (make-recolor e rng)))

;;; --- LIFECYCLE ---

(defun boot! ()
  "Seed RNGs from OS Entropy if they aren't seeded yet. Idempotent"
  (unless *oracle-rng*
    (seed-rngs! (entropy-seed))))

(defun make-seed-canvas ()
  "Return a fixed REPL-friendly starting composition with hardcoded layers."
  (let ((c (make-canvas)))
    (setf (canvas-next-id c) 4
          (canvas-entities c)
          (list (make-entity :id 1 :type :blob     :pos '(220 180) :scale 1.3 :color :coral   :layer 1000)
                (make-entity :id 2 :type :squiggle :pos '(400 320) :scale 1.0 :color :teal    :layer 2000)
                (make-entity :id 3 :type :triangle :pos '(560 200) :scale 0.8 :color :mustard :layer 3000)))
    c))

(defun reset! (&optional seed)
  "Reset engine state to the seed canvas. Optionally re-seed RNGs from SEED."
  (when seed (seed-rngs! seed))
  (setf *state* (make-seed-canvas)))

;;; --- TICK LOOP ---

(defun tick! (oracle)
  "Advance the composition by one step using ORACLE.
   Returns the list of mutations that were applied."
  (boot!)
  (let* ((raw (funcall oracle *state* *oracle-rng*))
         (mutations (stamp-layers raw *jitter-rng*)))
    (setf *state* (apply-mutations *state* mutations))
    (setf *state* (apply-mutations *state* (jitter-mutations *state* *jitter-rng*)))
    mutations))
