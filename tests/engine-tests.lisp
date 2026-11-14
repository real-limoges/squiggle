;;;; engine-tests.lisp: the validator, dispatch, observers, and tick!

(in-package :squiggle/tests)

;;; --- Fixtures ---

(defstruct recording-observer
  ;; mutable
  (ticks '()))

(defmethod observe-tick ((recording-observer recording-observer) canvas mutations)
  (push (list canvas mutations) (recording-observer-ticks recording-observer)))

(defun valid-entity-p (entity)
  (and (member (entity-color entity) +palette+)
       (member (entity-type entity) +entity-types+)))

;;; --- Validator ---

(deftest-engine validator-rejects-garbage
  (dolist (garbage (list 5 '() '(:explode 1) '(:add :blob 1) '(:add :hexagon 1 2 :teal)
                         '(:add :blob 1 2 :magenta) '(:recolor 1 :magenta)
                         '(:nudge 1 :left 2) '(:resize 1 -2) '(:remove)
                         '(:add . 3) '(:nudge 1 2 . 3)))
    (is (eq :rejected (validate-mutation *state* garbage)))))

(deftest-engine validator-rejects-unknown-ids
  (dolist (verb (list '(:nudge 99 1 1) '(:recolor 99 :teal) '(:resize 99 1.1) '(:remove 99)))
    (is (eq :rejected (validate-mutation *state* verb)))))

(deftest-engine validator-clamps-add-onto-the-canvas
  (is (equal '(:add :blob 0 500 :teal)
             (validate-mutation *state* '(:add :blob -10 900 :teal)))))

(deftest-engine validator-keeps-only-the-valid
  (is (equal '((:remove 1))
             (validate-mutations *state* '((:explode) (:remove 1) (:remove 99))))))

;;; --- Dispatch ---

(deftest-engine apply-mutation-signals-on-unknown-verb
  (signals error (apply-mutation *state* '(:explode 1))))

(deftest-engine update-entity-signals-on-missing-id
  (signals error (apply-nudge *state* 99 1 1)))

(deftest-engine nudge-leaves-the-original-canvas-alone
  (apply-nudge *state* 1 10 20)
  (is (equal '(220 180) (entity-pos (find-entity *state* 1)))))

;;; --- LLM Reply Parsing ---

(deftest-engine llm-reply-assembles-an-add
  (let ((result (squiggle/oracle::proposal-from-reply
                 (squiggle/oracle::parse-response "MOOD=8 coral squiggle 340 120")
                 *state* (rngs-oracle *rngs*))))
    (is (= 8 (oracle-result-mood result)))
    (is (equal '((:add :squiggle 340 120 :coral)) (oracle-result-mutations result)))))

(deftest-engine llm-reply-without-a-mood-falls-back
  (is (eq :none (squiggle/oracle::scan-mood "coral squiggle 340 120")))
  (let ((result (squiggle/oracle::proposal-from-reply
                 (squiggle/oracle::parse-response "coral squiggle 340 120")
                 *state* (rngs-oracle *rngs*))))
    (is (integerp (oracle-result-mood result)))))

;;; --- Tick ---

(deftest-engine tick-notifies-observers
  (let ((*tick-observers* (list (make-recording-observer))))
    (tick! (make-fake-oracle))
    (tick! (make-fake-oracle))
    (is (= 2 (length (recording-observer-ticks (first *tick-observers*)))))))

(deftest-engine fake-oracle-ticks-keep-the-canvas-valid
  (dotimes (i 25)
    (tick! (make-fake-oracle)))
  (let ((ids (mapcar #'entity-id (entities *state*))))
    (is (= (length ids) (length (remove-duplicates ids))))
    (is (every #'valid-entity-p (entities *state*)))
    (is (every (lambda (id) (< id (canvas-next-id *state*))) ids))))
