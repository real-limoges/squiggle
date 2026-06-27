

(in-package :squiggle/backend)

(defun clamp (x lo hi) (max lo (min hi x)))

(defun valid-color? (c) (member c +palette+))
(defun valid-type? (ty) (member ty +entity-types+))

(defun validate-mutation (m)
  "Return M (with :add coords clamped) if structurally valid, else NIL."
  (case (car    m)
    (:nudge     m)
    (:remove    m)
    (:recolor   (when (valid-color? (caddr m)) m))
    (:add       (destructuring-bind (type x y color) (rest m)
                  (when (and (valid-type? type) (valid-color? color))
                    (list :add type 
                          (clamp x 0 +canvas-w+) 
                          (clamp y 0 +canvas-h+) 
                          color))))
    (:resize    m)
    (otherwise  nil)))

(defun validate-mutations (ms)
  "Filter MS, keeping only valid (possibly clamped) mutations."
  (loop for m in ms
        for v = (validate-mutation m)
        when v collect v))