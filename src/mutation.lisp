;;;; mutation.lisp
;;;;
;;;; Mutation verbs — one flat function each, state in / new state out.

(in-package :squiggle)

(defun apply-nudge (state id dx dy)
  "Shift entity ID by (DX, DY), clamped to the canvas."
  (update-entity state id
                 (lambda (e)
                   (let ((pos (getf e :pos)))
                     (set-prop e :pos
                               (list (clamp-x (+ (first pos) dx))
                                     (clamp-y (+ (second pos) dy))))))))

(defun apply-recolor (state id color)
  "Recolor entity ID, if COLOR is in the palette."
  (if (valid-color-p color)
      (update-entity state id (lambda (e) (set-prop e :color color)))
      state))

(defun apply-resize (state id factor)
  "Multiply entity ID's scale by FACTOR, clamped to bounds."
  (update-entity state id
                 (lambda (e)
                   (set-prop e :scale (clamp-scale (* (getf e :scale) factor))))))

(defun make-entity (id type x y color)
  "Build a fresh entity plist. CL assigns the id, never the oracle."
  (list :id id :type type
        :pos (list (clamp-x x) (clamp-y y))
        :scale 1.0 :color color))

(defun apply-add (state type x y color)
  "Append a new entity. Ignored if TYPE or COLOR is invalid."
  (if (and (valid-type-p type) (valid-color-p color))
      (let* ((id (getf state :next-id))
             (added (with-entities state
                                   (append (entities state)
                                           (list (make-entity id type x y color)))))
             (copy (copy-list added)))
        (setf (getf copy :next-id) (1+ id))
        copy)
      state))

(defun apply-remove (state id)
  "Drop entity ID — but never let the canvas go empty."
  (let ((remaining (remove id (entities state)
                           :key (lambda (e) (getf e :id)))))
    (if (null remaining)
        state
        (with-entities state remaining))))