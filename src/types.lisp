;;;; types.lisp: constants and structs shared by the engine and the oracles

(in-package :squiggle)

(defparameter +palette+ '(:teal :coral :cream :ink :mustard))
(defparameter +canvas-w+ 800)
(defparameter +canvas-h+ 500)
(defparameter +min-scale+ 0.4)
(defparameter +max-scale+ 2.5)
(defparameter +entity-types+ '(:blob :squiggle :triangle :curve))

(define-frozen-struct entity (:copier entity-with :fixed (id type layer))
  (id    nil)
  (type  nil)
  (pos   nil)
  (scale nil)
  (color nil)
  (layer nil))

(define-frozen-struct canvas (:copier canvas-with)
  (next-id  1)
  (entities '()))

(defstruct oracle-result
  (mutations '() :read-only t)
  (mood      :none :read-only t))

(defun entities (canvas)
  (canvas-entities canvas))

(defun find-entity (canvas id)
  "The entity with ID or NIL."
  (find id (entities canvas) :key #'entity-id))
