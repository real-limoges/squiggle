;;;; mutation-tests.lisp
;;;;
;;;; Tests for src/mutation.lisp

(in-package :squiggle/tests)

(deftest-engine nudge-moves-entity
  (let* ((state (apply-nudge *state* 1 10 20))
         (e     (find-entity state 1)))
    (is (equal '(230 200) (entity-pos e)))))

(deftest-engine recolor-entity
  (let* ((state (apply-recolor *state* 1 :mustard))
         (e     (find-entity state 1)))
    (is (eq :mustard (entity-color e)))))
