;;;; corpus.lisp: walks the book one passage at a time

(in-package :squiggle/oracle)

(defparameter *passages* nil)
(defparameter *passage-idx* 0)

(defun load-passages! (&optional (path "corpus/passages.txt"))
  (setf *passages* (coerce (uiop:read-file-lines path) 'vector)
        *passage-idx* 0))

(defun next-passage! ()
  "Wraps to the start at the end of the book."
  (prog1 (aref *passages* *passage-idx*)
    (setf *passage-idx* (mod (1+ *passage-idx*) (length *passages*)))))
