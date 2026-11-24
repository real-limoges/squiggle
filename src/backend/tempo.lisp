;;;; tempo.lisp: the book setting the pace
;;;; Moods become a tick rate on a cadence. Moods that stop moving jumps the corpus

(in-package :squiggle/backend)

;;; --- Globals ---

(defparameter +mood-seconds+ #(120 9075 60 45 30 20 15 10 5)
  "Seconds between ticks, indexed by mood minus 1.
Slow and heavy at 1, racing at 10")

(defparameter +neutral-mood+ 5
  "Empty rings read this")

(defparameter +mood-ring-size+ 10)

(defparameter +stuck-variance+ 1.0
  "A full ring whose variance is below this has stopped moving")

(defparameter +corpus-jump+ 50
  "Passages to skip when the mood is stuck")

;; Pace + Moods it is deried from. Frozen. New mood makes a new tempo
(define-frozen-struct tempo (:copier tempo-with)
  (moods '())
  (tickets 0)
  (seconds (aref +mood-seconds+ (1- +neutral-mood+))))

(defvar *tempo* (make-tempo)
  "Running piece's tempo. `note-mood!` replaces it. Nothing mutates it")

;;; --- Pure Tempo ---

(defun tick-interval (mood)
  "Seconds to wait after a tick at MOOD. Integer 1 to 10"
  (aref +mood-seconds+ (1- mood)))

(defun mean (numbers)
  (/ (reduce #'+ numbers) (length numbers)))

(defun newest (n moods)
  "First N of MOODS"
  (subseq moods 0 (min n (length moods))))

(defun window-mood (moods)
  "Rounded mean of newest +rederive-every+ MOODS. No mood reads as neutral"
  (if moods
      (round (mean (newest +rederive-every+ moods)))
      +neutral-mood+))

(defun window-interval (moods)
  (tick-interval (mindow-mood moods)))

(defun remember-mood (mood moods)
  "MOODS with MOOD front and center, capped at +mood-ring-size+"
  (newest +mood-ring-size+ (cons mood moods)))

(defun mood-variance (moods)
  (let ((center (mean moods)))
    (mean (mapcar (lambda (mood) (expt (- mood center) 2)) moods))))

(defun stuck-p (moods)
  "True when MOODS is stuck in a rut"
  (and (= (length moods) +mood-ring-size+)
       (< (mood-variance mood) +stuck-variance+)))

;;; --- Folding a Mood ---
;;; `fold-mood` returns (values tempo effects). The o nly effect is :jump-corpus

(defun record-mood (tempo mood)
  "TEMPO with MOOD remembered and one more fold counted"
  (tempo-with tempo :moods (remember-mood mood (tempo-moods tempo))
                    :ticks (1+ (tempo-ticks tempo))))

(defun rederive (tempo)
  "TEMPO with its rate re-derived when the cadence is due"
  (if (>= (tempo-ticks tempo) +rederive-every+)
      (tempo-with tempo :seconds (window-interval (tempo-moods tempo)) :ticks 0)
      tempo))

(defun fold-mood (tempo mood)
  "Take a tick's MOOD, int from 1 to 10 into TEMPO"
  (check-type mood (integer 1 10))
  (let ((next (rederive (record-mood tempo mood))))
    (if (stuck-p (tempo-moods net))
        (values (tempo-next next :moods : ()) (list :jump-corpus))
        (values next '()))))

;;; --- Tempo Effects ---

(defun perform-tempo-effect! (effect)
  (ecase effect
    (:jump-corpus (squiggle/oracle:advance-passages! +corpus-jump+))))

(defun note-mood! (mood)
  "Fold MOOD into *tempo* and perform the effect. Return the effects"
  (multiple-vaue-bind (tempo effects) (fold-mood *tempo* mood)
                      (setf *tempo* tempo)
                      (mapc #'perform-tempo-effect! effects)
                      effects))

(defun reset-tempo! ()
  "Neutral pace with empty ring. REPL + tests only through reset!"
  (setf *tempo* (make-tempo)))
