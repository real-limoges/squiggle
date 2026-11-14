;;;; mutation.lisp: one function per verb, canvas in and new canvas out
;;;; These trust their arguments; the validator has already checked them.

(in-package :squiggle/backend)

(defun moved-pos (pos dx dy)
  (list (+ (first pos) dx)
        (+ (second pos) dy)))

(defun apply-nudge (canvas id dx dy)
  (update-entity canvas id
                 (lambda (entity)
                   (entity-with entity :pos (moved-pos (entity-pos entity) dx dy)))))

(defun apply-recolor (canvas id color)
  (update-entity canvas id
                 (lambda (entity)
                   (entity-with entity :color color))))

(defun apply-resize (canvas id factor)
  (update-entity canvas id
                 (lambda (entity)
                   (entity-with entity :scale (* (entity-scale entity) factor)))))

(defun apply-add (canvas type x y color layer)
  (let* ((id     (canvas-next-id canvas))
         (entity (make-entity :id id
                              :type type
                              :pos (list x y)
                              :scale 1.0
                              :color color
                              :layer layer)))
    (canvas-with canvas
                 :next-id (1+ id)
                 :entities (append (entities canvas) (list entity)))))

(defun apply-remove (canvas id)
  (canvas-with canvas
               :entities (remove id (entities canvas) :key #'entity-id)))
