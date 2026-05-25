;;;; types.lisp
;;;;
;;;; Shared components for Squiggle

(in-package :squiggle)

(defparameter +palette+ '(:teal :coral :cream :ink :mustard)
  "The fixed set of colors the composition lives within.")

;;; --- CONSTANTS ---

(defparameter +canvas-w+ 800)
(defparameter +canvas-h+ 500)
(defparameter +min-scale+ 0.4)
(defparameter +max-scale+ 2.5)
(defparameter +entity-types+ '(:blob :squiggle :triangle :curve))

;;; --- STRUCTS ---

(defstruct entity
  id type pos scale color layer)

(defstruct canvas
  (next-id 1)
  (entities '()))



;;; --- ACCESSORS ---

(defun entities (state)
  (canvas-entities state))

(defun find-entity (state id)
  "Return the entity plist with the given ID, or NIL."
  (find id (entities state) :key (lambda (e) (entity-id e))))