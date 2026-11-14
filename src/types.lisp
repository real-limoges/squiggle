;;;; types.lisp: constants and structs shared by the engine and the oracles

(in-package :squiggle)

(defparameter +palette+ '(:teal :coral :cream :ink :mustard))
(defparameter +canvas-w+ 800)
(defparameter +canvas-h+ 500)
(defparameter +min-scale+ 0.4)
(defparameter +max-scale+ 2.5)
(defparameter +entity-types+ '(:blob :squiggle :triangle :curve))

(defstruct entity
  (id    nil :read-only t)
  (type  nil :read-only t)
  (pos   nil :read-only t)
  (scale nil :read-only t)
  (color nil :read-only t)
  (layer nil :read-only t))

(defstruct canvas
  (next-id  1   :read-only t)
  (entities '() :read-only t))

(defstruct oracle-result
  (mutations '() :read-only t)
  (mood      :none :read-only t))

(defun entity-with (entity &key (pos   (entity-pos entity))
                                (scale (entity-scale entity))
                                (color (entity-color entity)))
  "A copy of ENTITY with POS, SCALE or COLOR changed. Id, type and layer never
change."
  (make-entity :id    (entity-id entity)
               :type  (entity-type entity)
               :pos   pos
               :scale scale
               :color color
               :layer (entity-layer entity)))

(defun canvas-with (canvas &key (next-id  (canvas-next-id canvas))
                                (entities (canvas-entities canvas)))
  "A copy of CANVAS with NEXT-ID or ENTITIES changed."
  (make-canvas :next-id next-id :entities entities))

(defun entities (canvas)
  (canvas-entities canvas))

(defun find-entity (canvas id)
  "The entity with ID or NIL."
  (find id (entities canvas) :key #'entity-id))
