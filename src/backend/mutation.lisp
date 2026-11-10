;;;; mutation.lisp: one function per verb, canvas in and new canvas out
;;;; These trust their arguments; the validator has already checked them.

(in-package :squiggle/backend)

(defun apply-nudge (state id dx dy)
  (update-entity state id
                 (lambda (e)
                   (setf (entity-pos e)
                         (list (+ (first  (entity-pos e)) dx)
                               (+ (second (entity-pos e)) dy)))
                   e)))

(defun apply-recolor (state id color)
  (update-entity state id
                 (lambda (e)
                   (setf (entity-color e) color)
                   e)))

(defun apply-resize (state id factor)
  (update-entity state id
                 (lambda (e)
                   (setf (entity-scale e) (* (entity-scale e) factor))
                   e)))

(defun apply-add (state type x y color layer)
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
  (with-entities state
                 (remove id (entities state) :key #'entity-id)))
