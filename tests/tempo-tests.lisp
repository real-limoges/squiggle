;;;; tempo-tests.lisp

(in-package :squiggle/tests)

(in-suite :squiggle)

(defun fold-moods (moods)
  "Fresh tempo with MOODS folded in oldest first. Effects are dropped"
  (reduce #'fold-mood moods :initial-value (make-tempo)))

(test tick-interval-table
  (is (= 120 (tick-interval 1)))
  (is (= 5 (tick-interval 10)))
  (is (= 45 (window-interval '()))))

(test remember-mood-caps-the-ring
  (let ((full (reduce (lambda (moods mood) (remember-mood mood moods))
                      '(1 2 3 4 5 6 7 8 9 10 3)
                      :initial-value '())))
    (is (= 10 (length full)))
    (is (= 3 (first full)))))

(test window-reads-newest-five
  (is (= 15 (window-interval '(8 8 8 8 8 1 1 1 1 1)))))

(test stuck-needs-a-full-flat-ring
  (is (not (stuck-p (make-list 9 :initial-element 7))))
  (is (stuck-p (make-list 10 :initial-element 7)))
  (is (not (stuck-p '(1 10 1 10 1 10 1 10 1 10)))))

(test rate-rederives-on-cadence
  (is (= 45 (tempo-seconds (fold-moods '(10 10 10 10)))))
  (is (= 5 (tempo-seconds (fold-moods '(10 10 10 10 10))))))

(test stuck-ring-calls-for-a-jump
  (multiple-value-bind (tempo effects)
      (fold-mood (fold-moods (make-list 9 :initial-element 7)) 7)
    (is (equal '(:jump-corpus) effects))
    (is (null (tempo-moods tempo)))))

(deftest-engine note-mood-jumps-the-corpus
    (let ((squiggle/oracle::*corpus*
            (squiggle/oracle::make-corpus :passages (make-array 100 :initial-element "x"))))
      (dotimes (i 10) (note-mood! 7))
      (is (= 50 (squiggle/oracle::corpus-index squiggle/oracle::*corpus*)))
      (is (null (tempo-moods *tempo*)))))

(deftest-engine tick-feeds-the-tempo
    (tick! (make-fake-oracle))
  (is (= 1 (length (tempo-moods *tempo*)))))
