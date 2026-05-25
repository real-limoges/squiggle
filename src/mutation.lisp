;;;; mutation.lisp
;;;;
;;;; Mutation verbs — one flat function each, state in / new state out.

(in-package :squiggle)

(defun apply-nudge (state id dx dy)
  "Shift entity ID by (DX, DY). Bounds are the validator's job."
  (update-entity state id
                 (lambda (e)
                   (setf (entity-pos e)
                         (list (+ (first  (entity-pos e)) dx)
                               (+ (second (entity-pos e)) dy)))
                   e)))

(defun apply-recolor (state id color)
  "Recolor entity ID. Color validity is the validator's job."
  (update-entity state id
                 (lambda (e)
                   (setf (entity-color e) color)
                   e)))

(defun apply-resize (state id factor)
  "Multiply entity ID's scale by FACTOR. Bounds are the validator's job."
  (update-entity state id
                 (lambda (e)
                   (setf (entity-scale e) (* (entity-scale e) factor))
                   e)))

(defun apply-add (state type x y color layer)
  "Append a new entity. Type/color validity is the validator's job."
  (let* ((id    (canvas-next-id state))
         (new-e (make-entity :id id 
                             :type type
                             :pos (list x y) 
                             :scale 1.0 
                             :color color
                             :layer layer))
         (new-s (copy-canvas state)))
    (setf (canvas-entities new-s) (append (canvas-entities new-s) (list new-e)))
    (setf (canvas-next-id  new-s) (1+ id))
    new-s))

(defun apply-remove (state id)
  "Drop entity ID. The entity-count band guard is the sanity layer's job."
  (with-entities state
                 (remove id (entities state) :key #'entity-id)))
