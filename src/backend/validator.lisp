;;;; validator.lisp: drops oracle proposals the engine cannot apply
;;;; Validity only, never taste.

(in-package :squiggle/backend)

(defun clamp (x lo hi) (max lo (min hi x)))

(defun valid-color? (c) (member c +palette+))
(defun valid-type? (ty) (member ty +entity-types+))

(defun validate-mutation (m)
  "M, with :add coordinates clamped onto the canvas, or NIL."
  (case (car    m)
    (:nudge     m)
    (:remove    m)
    (:recolor   (when (valid-color? (caddr m)) m))
    (:add       (let ((args (rest m)))
                  ;; A truncated :add is routine from a 1.5B model, so reject
                  ;; it rather than signal.
                  (when (= 4 (length args))
                    (destructuring-bind (type x y color) args
                      (when (and (valid-type? type) (valid-color? color)
                                 (realp x) (realp y))
                        (list :add type
                              (clamp x 0 +canvas-w+)
                              (clamp y 0 +canvas-h+)
                              color))))))
    (:resize    m)
    (otherwise  nil)))

(defun validate-mutations (ms)
  (loop for m in ms
        for v = (validate-mutation m)
        when v collect v))
