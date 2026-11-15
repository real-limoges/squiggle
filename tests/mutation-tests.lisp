;;;; mutation-tests.lisp: the pure verbs, unit and property tests

(in-package :squiggle/tests)

(in-suite :squiggle)

;;; --- Unit ---

(deftest-engine nudge-moves-entity
  (let* ((state (apply-nudge *state* 1 10 20))
         (e     (find-entity state 1)))
    (is (equal '(230 200) (entity-pos e)))))

(deftest-engine recolor-entity
  (let* ((state (apply-recolor *state* 1 :mustard))
         (e     (find-entity state 1)))
    (is (eq :mustard (entity-color e)))))

(deftest-engine resize-scales-entity
  (is (= 2.6 (entity-scale (find-entity (apply-resize *state* 1 2) 1)))))

(deftest-engine add-takes-the-next-id
  (let* ((state (apply-add *state* :curve 10 20 :ink 7))
         (e     (find-entity state 4)))
    (is (= 5 (canvas-next-id state)))
    (is (equal '(10 20) (entity-pos e)))
    (is (= 7 (entity-layer e)))
    (is (= 1.0 (entity-scale e)))))

(deftest-engine remove-drops-one-entity
  (let ((state (apply-remove *state* 2)))
    (is (= 2 (length (entities state))))
    (is (null (find-entity state 2)))))

(deftest-engine reset-restores-the-seed-canvas
  (setf *state* (apply-remove *state* 1))
  (reset! 42)
  (is (equalp (make-seed-canvas) *state*)))

(test make-canvas-is-empty
  (is (null (entities (make-canvas))))
  (is (= 1 (canvas-next-id (make-canvas)))))

(test stamp-layers-touches-only-adds
  (let* ((nudge   (list :nudge 1 2 3))
         (stamped (stamp-layers (list nudge (list :add :blob 1 1 :teal)) (make-random-state t))))
    (is (eq nudge (first stamped)))
    (is (= 6 (length (second stamped))))
    (is (integerp (sixth (second stamped))))))

;;; --- Properties ---

(defun op-mutation (canvas op)
  "OP 0 adds a blob; OP 1 removes the first entity, or adds when there is none."
  (if (and (= op 1) (entities canvas))
      (list :remove (entity-id (first (entities canvas))))
      (list :add :blob 10 10 :teal 1)))

(defun run-ops (canvas ops)
  (reduce (lambda (canvas op) (apply-mutation canvas (op-mutation canvas op)))
          ops :initial-value canvas))

(deftest-engine ids-stay-unique-through-adds-and-removes
  (for-all ((ops (gen-list :length (gen-integer :min 0 :max 30)
                           :elements (gen-integer :min 0 :max 1))))
    (let* ((state (run-ops (make-seed-canvas) ops))
           (ids   (mapcar #'entity-id (entities state))))
      (is (= (length ids) (length (remove-duplicates ids))))
      (is (every (lambda (id) (< id (canvas-next-id state))) ids)))))

(deftest-engine nudge-moves-only-its-entity
  (for-all ((dx (gen-integer :min -100 :max 100))
            (dy (gen-integer :min -100 :max 100)))
    (let ((state (apply-nudge *state* 2 dx dy)))
      (is (equal (list (+ 400 dx) (+ 320 dy)) (entity-pos (find-entity state 2))))
      (is (equal '(220 180) (entity-pos (find-entity state 1))))
      (is (equal '(400 320) (entity-pos (find-entity *state* 2)))))))
