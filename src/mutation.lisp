;;;; mutation.lisp
;;;;
;;;; Mutation verbs — one flat function each, state in / new state out.

(in-package :squiggle)

(defun apply-nudge (state id dx dy)
  "Shift entity ID by (DX, DY). Bounds are the validator's job."
  (update-entity state id
                 (lambda (e)
                   (let ((pos (getf e :pos)))
                     (set-prop e :pos
                               (list (+ (first pos) dx)
                                     (+ (second pos) dy)))))))

(defun apply-recolor (state id color)
  "Recolor entity ID. Color validity is the validator's job."
  (update-entity state id (lambda (e) (set-prop e :color color))))

(defun apply-resize (state id factor)
  "Multiply entity ID's scale by FACTOR. Bounds are the validator's job."
  (update-entity state id
                 (lambda (e)
                   (set-prop e :scale (* (getf e :scale) factor)))))

(defun make-entity (id type x y color)
  "Build a fresh entity plist. CL assigns the id, never the oracle."
  (list :id id :type type
        :pos (list x y)
        :scale 1.0 :color color))

(defun apply-add (state type x y color)
  "Append a new entity. Type/color validity is the validator's job."
  (let* ((id (getf state :next-id))
         (added (with-entities state
                               (append (entities state)
                                       (list (make-entity id type x y color)))))
         (copy (copy-list added)))
    (setf (getf copy :next-id) (1+ id))
    copy))

(defun apply-remove (state id)
  "Drop entity ID. The entity-count band guard is the sanity layer's job."
  (with-entities state
                 (remove id (entities state)
                         :key (lambda (e) (getf e :id)))))