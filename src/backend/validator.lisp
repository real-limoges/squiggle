;;;; validator.lisp: drops oracle proposals the engine cannot apply
;;;; Validity only, they can be ugly as hell

(in-package :squiggle/backend)

(defun clamp (x lo hi) (max lo (min hi x)))

(defun valid-color? (c) (member c +palette+))
(defun valid-type? (ty) (member ty +entity-types+))

(defun live-id? (canvas id)
  (and (integerp id) (find-entity canvas id)))

;;; --- Per-verb checks ---
;;; Each takes the arguments after the verb. A truncated proposal is routine
;;; from a 1.5B model, so a wrong arity is rejected rather than signaled.

(defun valid-nudge? (canvas args)
  (and (= 3 (length args))
       (live-id? canvas (first args))
       (realp (second args))
       (realp (third args))))

(defun valid-recolor? (canvas args)
  (and (= 2 (length args))
       (live-id? canvas (first args))
       (valid-color? (second args))))

(defun valid-resize? (canvas args)
  (and (= 2 (length args))
       (live-id? canvas (first args))
       (realp (second args))
       (plusp (second args))))

(defun valid-remove? (canvas args)
  (and (= 1 (length args))
       (live-id? canvas (first args))))

(defun valid-add? (args)
  (and (= 4 (length args))
       (destructuring-bind (type x y color) args
         (and (valid-type? type) (valid-color? color)
              (realp x) (realp y)))))

(defun validate-add (args)
  "The :add with its coordinates clamped onto the canvas, or :rejected."
  (if (valid-add? args)
      (destructuring-bind (type x y color) args
        (list :add type
              (clamp x 0 +canvas-w+)
              (clamp y 0 +canvas-h+)
              color))
      :rejected))

;;; --- Entry points ---

(defun accept-when (valid mutation)
  (if valid mutation :rejected))

(defun validate-verb (canvas mutation)
  (let ((args (rest mutation)))
    (case (first mutation)
      (:nudge     (accept-when (valid-nudge?   canvas args) mutation))
      (:recolor   (accept-when (valid-recolor? canvas args) mutation))
      (:resize    (accept-when (valid-resize?  canvas args) mutation))
      (:remove    (accept-when (valid-remove?  canvas args) mutation))
      (:add       (validate-add args))
      (otherwise  :rejected))))

(defun proper-mutation? (mutation)
  "A non-empty proper list, so the per-verb checks can take its length"
  (and (consp mutation)
       (null (cdr (last mutation)))))

(defun validate-mutation (canvas mutation)
  "MUTATION, with :add coordinates clamped onto the canvas, or :rejected.
Ids are checked against CANVAS as it stands before the tick."
  (if (proper-mutation? mutation)
      (validate-verb canvas mutation)
      :rejected))

(defun validate-mutations (canvas mutations)
  (loop for mutation in mutations
        for valid = (validate-mutation canvas mutation)
        unless (eq valid :rejected) collect valid))
