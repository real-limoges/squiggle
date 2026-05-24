;;;; squiggle.lisp
;;;;
;;;; A self-evolving abstract composition based on the Jazz design


;;; --- PACKAGE ---

(defpackage :squiggle
  (:use :cl)
  (:export :*state* :demo :tick! :apply-mutations :fake-oracle :llm-oracle))

(in-package :squiggle)

;;; --- CONSTANTS ---

(defparameter *palette* '(:teal :coral :cream :ink :mustard)
  "The fixed set of colors the composition lives within.")

(defparameter +canvas-w+ 800)
(defparameter +canvas-h+ 500)
(defparameter +min-scale+ 0.4)
(defparameter +max-scale+ 2.5)
(defparameter +entity-types+ '(:blob :squiggle :triangle :curve))

;;; --- PRNG ---

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
;;; ENTITY: (:id 1 :type :blob :pos (220 180) :scale 1.3 :color :coral)
;;; STATE:  (:palette (...) :next-id N :entities (entity ...))

(defparameter *state*
  (list :palette *palette*
        :next-id 4
        :entities
        (list
         (list :id 1 :type :blob     :pos '(220 180) :scale 1.3 :color :coral)
         (list :id 2 :type :squiggle :pos '(400 320) :scale 1.0 :color :teal)
         (list :id 3 :type :triangle :pos '(560 200) :scale 0.8 :color :ink)))
  "The live composition. Rebound to a fresh value each tick.")

;;; --- ACCESSORS ---

(defun entities (state)
  (getf state :entities))

(defun find-entity (state id)
  "Return the entity plist with the given ID, or NIL."
  (find id (entities state) :key (lambda (e) (getf e :id))))

;;; --- STATE CONSTRUCTORS ---
;;; Every change returns a NEW state — never mutate in place.

(defun with-entities (state new-entities)
  "Return a copy of STATE whose entity list is NEW-ENTITIES."
  (let ((copy (copy-list state)))
    (setf (getf copy :entities) new-entities)
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
                  (if (= (getf e :id) id) (funcall fn (copy-list e)) e))
                (entities state)))))

(defun set-prop (entity key value)
  "Set KEY to VALUE on a (copied) ENTITY plist and return it.
   Meant to be used as the FN passed to `update-entity`."
  (setf (getf entity key) value)
  entity)

;;; --- DISPATCH ---

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

;;; --- LIFECYCLE ---

(defun boot! ()
  "Seed RNGs from OS Entropy if they aren't seeded yet. Idempotent"
  (unless *oracle-rng*
    (seed-rngs! (entropy-seed))))

(defun reset! ()
  "Reset engine state."
  (error "reset! not yet implemented"))

;;; --- TICK LOOP ---

; This is what I change to switch it to the llm-oracle
(defun tick! (&optional (oracle #'fake-oracle))
  "Advance the composition by one step using ORACLE.
   Returns the list of mutations that were applied."
  (boot!)
  (let ((mutations (funcall oracle *state* *oracle-rng*)))
    (setf *state* (apply-mutations *state* mutations))
    mutations))

;;; --- INSPECTION ---

(defun print-entity (e)
  (format t "  id=~D ~A pos=~A scale=~,2F color=~A~%"
          (getf e :id) (getf e :type) (getf e :pos)
          (getf e :scale) (getf e :color)))

(defun print-state (&optional (state *state*))
  (format t "~&--- ~D entities ---~%" (length (entities state)))
  (mapc #'print-entity (entities state))
  (values))

(defun print-tick (n mutations)
  (format t "~&~%=== tick ~D ===~%mutations: ~S~%" n mutations)
  (print-state))

(defun demo (&optional (steps 20))
  "Run STEPS ticks, printing the mutations and resulting state each time."
  (dotimes (i steps)
    (print-tick (1+ i) (tick!)))
  (values))