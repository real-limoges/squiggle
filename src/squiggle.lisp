;;;; squiggle.lisp
;;;;
;;;; A self-evolving abstract composition based on the Jazz design
;;;;
;;;; This file has NO networking and NO model yet. It is just:
;;;;   1. STATE     (the composition)
;;;;   2. APPLY     (pure functions that turn mutations into new state)
;;;;   3. TICK LOOP (drives the whole thing so you can watch it evolve)


;;; --- PACKAGE ---

(defpackage :squiggle
  (:use :cl)
  (:export :*state* :demo :tick! :apply-mutations :fake-oracle))

(in-package :squiggle)

;;; --- CONSTANTS ---

(defparameter *palette* '(:teal :coral :cream :ink :mustard)
  "The fixed set of colors the composition lives within.")

(defparameter +canvas-w+ 800)
(defparameter +canvas-h+ 500)
(defparameter +min-scale+ 0.4)
(defparameter +max-scale+ 2.5)
(defparameter +entity-types+ '(:blob :squiggle :triangle :curve))

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

;;; --- PREDICATES & ACCESSORS ---

(defun clamp (x lo hi)
  (max lo (min hi x)))

(defun valid-color-p (color)
  (member color *palette*))

(defun valid-type-p (type)
  (member type +entity-types+))

(defun clamp-x (x) (clamp x 0 +canvas-w+))
(defun clamp-y (y) (clamp y 0 +canvas-h+))
(defun clamp-scale (s) (clamp s +min-scale+ +max-scale+))

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

;;; --- TICK LOOP ---

(defun tick! (&optional (oracle #'fake-oracle))
  "Advance the composition by one step using ORACLE.
   Returns the list of mutations that were applied."
  (let ((mutations (funcall oracle *state*)))
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