;;;; corpus.lisp
;;;;
;;;; description


(in-package :squiggle/oracle)

(defparameter *passages* nil)
(defparameter *passage-idx* 0)

(defun load-passages! (&optional (path "corpus/passages.txt"))
  (setf *passages* (coerce (uiop:read-file-lines path) 'vector)
        *passage-idx* 0))

(defun next-passage! ()
  "Return the next corpus passage, advancing the pointer"
  (prog1 (aref *passages* *passage-idx*)
    (setf *passage-idx* (mod (1+ *passage-idx*) (length *passages*)))))
