;;;; frozen-tests.lisp: define-frozen-struct's copier, and what it refuses

(in-package :squiggle/tests)

(in-suite :squiggle)

(defun expansion-refused-p (form)
  (handler-case (progn (macroexpand-1 form) nil)
    (error () t)))

(test copier-swaps-only-what-you-pass
  (let* ((entity (make-entity :id 1 :type :blob :pos (list 1 2) :scale 1.0 :color :ink :layer 7))
         (copy (entity-with entity :color :teal)))
    (is (eq :teal (entity-color copy)))
    (is (equal (list 1 2) (entity-pos copy)))
    (is (= 7 (entity-layer copy)))
    (is (eq :ink (entity-color entity)))))

(test frozen-struct-refuses-bad-definitions
  (is (expansion-refused-p '(define-frozen-struct thing () (a 1))))
  (is (expansion-refused-p '(define-frozen-struct thing (:copier thing-with) (a))))
  (is (expansion-refused-p '(define-frozen-struct thing (:copier thing-with :fixed (b)) (a 1))))
  (is (expansion-refused-p '(define-frozen-struct thing (:copier thing-with :fixed (a)) (a 1)))))
