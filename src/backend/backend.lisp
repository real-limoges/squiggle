;;;; backend.lisp: engine state and the tick loop
;;;; Every change builds a new canvas; nothing mutates one in place.

(in-package :squiggle/backend)

;;; --- Globals ---

(defstruct rngs
  "The two independent random streams: one for oracle proposals, one for
jitter and layers."
  (oracle nil :read-only t)
  (jitter nil :read-only t))

;; Unbound until boot! or seed-rngs! sets it.
(defvar *rngs*)

(defvar *state* (make-canvas))

(defvar *tick-observers* '()
  "Observers whose observe-tick method runs after each tick commits")

(defvar *last-mood* :none
  "Recorded by tick! for the tempo subsystem; nothing reads it yet")

(defparameter +jitter-nudge-prob+ 0.3)
(defparameter +jitter-recolor-prob+ 0.05)
(defparameter +jitter-magnitude+ 3)

;;; --- RNG ---

(defun entropy-seed ()
  (random most-positive-fixnum (make-random-state t)))

(defun make-rng (seed)
  (sb-ext:seed-random-state seed))

(defun seed-rngs! (main-seed)
  (setf *rngs* (make-rngs :oracle (make-rng main-seed)
                          :jitter (make-rng (logxor main-seed #xA5A5A5A5)))))

;;; --- State ---

(defun update-entity (canvas id fn)
  "Replace entity ID with (FN entity). Signals when ID is not on CANVAS."
  (unless (find-entity canvas id)
    (error "No entity ~D on the canvas" id))
  (canvas-with canvas
               :entities (mapcar (lambda (entity)
                                   (if (= (entity-id entity) id) (funcall fn entity) entity))
                                 (entities canvas))))

;;; --- Dispatch ---

(defun stamp-layers (mutations jitter-rng)
  "Append a random layer to each :add, giving apply-add its LAYER argument.
Runs after validation, which expects the unstamped four-argument :add."
  (mapcar (lambda (mutation)
            (if (eq (first mutation) :add)
                (append mutation (list (random most-positive-fixnum jitter-rng)))
                mutation))
          mutations))

(defun apply-mutation (canvas mutation)
  (let ((args (rest mutation)))
    (ecase (first mutation)
      (:nudge   (apply #'apply-nudge   canvas args))
      (:recolor (apply #'apply-recolor canvas args))
      (:resize  (apply #'apply-resize  canvas args))
      (:add     (apply #'apply-add     canvas args))
      (:remove  (apply #'apply-remove  canvas args)))))

(defun apply-mutations (canvas mutations)
  (reduce #'apply-mutation mutations :initial-value canvas))

;;; --- Jitter ---
;;; Sub-perceptual drift so the canvas is never still

(defun random-signed (n rng)
  "An integer in [-N, N]."
  (- (random (1+ (* 2 n)) rng) n))

(defun make-nudge (entity rng)
  (let ((dx (random-signed +jitter-magnitude+ rng))
        (dy (random-signed +jitter-magnitude+ rng)))
    (list :nudge (entity-id entity) dx dy)))

(defun make-recolor (entity rng)
  (list :recolor (entity-id entity) (squiggle/oracle:random-elt +palette+ rng)))

(defun jitter-mutations (canvas rng)
  "Each entity rolls separately for a nudge and a recolor."
  (loop for entity in (entities canvas)
        when (< (random 1.0 rng) +jitter-nudge-prob+)
          collect (make-nudge entity rng)
        when (< (random 1.0 rng) +jitter-recolor-prob+)
          collect (make-recolor entity rng)))

;;; --- Lifecycle ---

(defun boot! ()
  (unless (boundp '*rngs*)
    (seed-rngs! (entropy-seed))))

(defun make-seed-canvas ()
  (make-canvas
   :next-id 4
   :entities (list (make-entity :id 1 :type :blob     :pos '(220 180) :scale 1.3 :color :coral   :layer 1000)
                   (make-entity :id 2 :type :squiggle :pos '(400 320) :scale 1.0 :color :teal    :layer 2000)
                   (make-entity :id 3 :type :triangle :pos '(560 200) :scale 0.8 :color :mustard :layer 3000))))

(defun reset! (&optional seed)
  "For the REPL and tests only; the running piece never resets."
  (when seed (seed-rngs! seed))
  (setf *state* (make-seed-canvas)))

;;; --- Tick ---

(defgeneric observe-tick (observer canvas mutations)
  (:documentation "Runs after a tick commits CANVAS. MUTATIONS are the oracle's,
as applied."))

(defun notify-observers (canvas mutations)
  (dolist (observer *tick-observers*)
    (observe-tick observer canvas mutations)))

(defun tick! (oracle)
  "Returns the oracle's mutations as applied (jitter not included)."
  (boot!)
  (let* ((result    (squiggle/oracle:propose oracle *state* (rngs-oracle *rngs*)))
         (valid     (validate-mutations *state* (oracle-result-mutations result)))
         (mutations (stamp-layers valid (rngs-jitter *rngs*))))
    (setf *last-mood* (oracle-result-mood result))
    (setf *state* (apply-mutations *state* mutations))
    (setf *state* (apply-mutations *state* (jitter-mutations *state* (rngs-jitter *rngs*))))
    (notify-observers *state* mutations)
    mutations))
