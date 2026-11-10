;;;; types.lisp: constants and structs shared by the engine and the oracles

(in-package :squiggle)

(defparameter +palette+ '(:teal :coral :cream :ink :mustard))
(defparameter +canvas-w+ 800)
(defparameter +canvas-h+ 500)
(defparameter +min-scale+ 0.4)
(defparameter +max-scale+ 2.5)
(defparameter +entity-types+ '(:blob :squiggle :triangle :curve))

(defstruct entity
  id type pos scale color layer)

(defstruct canvas
  (next-id 1)
  (entities '()))

(defstruct oracle-result
  (mutations '())
  mood)

(defun entities (state)
  (canvas-entities state))

(defun find-entity (state id)
  (find id (entities state) :key (lambda (e) (entity-id e))))
