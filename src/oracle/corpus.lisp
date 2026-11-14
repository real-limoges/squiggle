;;;; corpus.lisp: walks the book one passage at a time

(in-package :squiggle/oracle)

(defstruct corpus
  (passages #() :read-only t)
  ;; mutable
  (index 0))

(defvar *corpus* (make-corpus)
  "The loaded book and the passage the piece is on")

(defun load-passages! (&optional (path "corpus/passages.txt"))
  "Load PATH from its first passage. Returns :loaded."
  (setf *corpus* (make-corpus :passages (coerce (uiop:read-file-lines path) 'vector)))
  :loaded)

(defun advance-index! (corpus)
  "Wraps to the start at the end of the book."
  (setf (corpus-index corpus)
        (mod (1+ (corpus-index corpus)) (length (corpus-passages corpus)))))

(defun next-passage! ()
  (let ((corpus *corpus*))
    (prog1 (aref (corpus-passages corpus) (corpus-index corpus))
      (advance-index! corpus))))
