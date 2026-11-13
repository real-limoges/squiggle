;;;; backend.lisp: engine state and the tick loop
;;;; Every change builds a new canvas; nothing mutates one in place.

(in-package :squiggle/backend)

;;; --- RNG ---

(defvar *oracle-rng* nil)
(defvar *jitter-rng* nil)

(defun entropy-seed ()
  (random most-positive-fixnum (make-random-state t)))

(defun make-rng (seed)
  (sb-ext:seed-random-state seed))

(defun seed-rngs! (main-seed)
  (setf *oracle-rng* (make-rng main-seed)
        *jitter-rng* (make-rng (logxor main-seed #xA5A5A5A5))))

;;; --- State ---

(defparameter *state* (make-canvas))

(defvar *tick-observers* '()
  "Functions called as (fn state mutations) after each tick commits")

;; Recorded by tick! for the tempo subsystem; nothing reads it yet.
(defparameter *last-mood* nil)

(defun with-entities (state new-entities)
  (let ((copy (copy-canvas state)))
    (setf (canvas-entities copy) new-entities)
    copy))

(defun update-entity (state id fn)
  "Replace entity ID with (FN copy-of-entity). STATE comes back unchanged if ID
is missing."
  (if (null (find-entity state id))
      state
      (with-entities
        state
        (mapcar (lambda (e)
                  (if (= (entity-id e) id) (funcall fn (copy-entity e)) e))
                (entities state)))))

;;; --- Dispatch ---

(defun stamp-layers (mutations jitter-rng)
  "Append a random layer to each :add, giving apply-add its LAYER argument.
Runs after validation, which expects the unstamped four-argument :add."
  (mapcar (lambda (m)
            (if (eq (first m) :add)
                (append m (list (random most-positive-fixnum jitter-rng)))
                m))
          mutations))

(defun apply-mutation (state mutation)
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
  (reduce #'apply-mutation mutations :initial-value state))

;;; --- Jitter ---
;;; Sub-perceptual drift so the canvas is never still

(defparameter +jitter-nudge-prob+ 0.3)
(defparameter +jitter-recolor-prob+ 0.05)
(defparameter +jitter-magnitude+ 3)

(defun random-signed (n rng)
  "An integer in [-N, N]."
  (- (random (1+ (* 2 n)) rng) n))

(defun make-nudge (entity rng)
  (let ((dx (random-signed +jitter-magnitude+ rng))
        (dy (random-signed +jitter-magnitude+ rng)))
    (list :nudge (entity-id entity) dx dy)))

(defun make-recolor (entity rng)
  (list :recolor (entity-id entity) (squiggle/oracle:random-elt +palette+ rng)))

(defun jitter-mutations (state rng)
  "Each entity rolls separately for a nudge and a recolor."
  (loop for e in (entities state)
        when (< (random 1.0 rng) +jitter-nudge-prob+)
          collect (make-nudge e rng)
        when (< (random 1.0 rng) +jitter-recolor-prob+)
          collect (make-recolor e rng)))

;;; --- Lifecycle ---

(defun boot! ()
  (unless *oracle-rng*
    (seed-rngs! (entropy-seed))))

(defun make-seed-canvas ()
  (let ((c (make-canvas)))
    (setf (canvas-next-id c) 4
          (canvas-entities c)
          (list (make-entity :id 1 :type :blob     :pos '(220 180) :scale 1.3 :color :coral   :layer 1000)
                (make-entity :id 2 :type :squiggle :pos '(400 320) :scale 1.0 :color :teal    :layer 2000)
                (make-entity :id 3 :type :triangle :pos '(560 200) :scale 0.8 :color :mustard :layer 3000)))
    c))

(defun reset! (&optional seed)
  "For the REPL and tests only; the running piece never resets."
  (when seed (seed-rngs! seed))
  (setf *state* (make-seed-canvas)))

;;; --- Tick ---

(defun tick! (oracle)
  "Returns the oracle's mutations as applied (jitter not included)."
  (boot!)
  (let* ((result    (funcall oracle *state* *oracle-rng*))
         (valid     (validate-mutations (oracle-result-mutations result)))
         (mutations (stamp-layers valid *jitter-rng*)))
    (setf *last-mood* (oracle-result-mood result))
    (setf *state* (apply-mutations *state* mutations))
    (setf *state* (apply-mutations *state* (jitter-mutations *state* *jitter-rng*)))
    (dolist (observe *tick-observers*)
      (funcall observe *state* mutations))
    mutations))
