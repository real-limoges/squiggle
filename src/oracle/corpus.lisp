;;;; corpus.lisp: walks the book one passage at a time

(in-package :squiggle/oracle)

(define-frozen-struct corpus (:copier corpus-with :fixed (passages))
  (passages #())
  (index    0))

(define-condition corpus-not-loaded (error) ()
  (:report "No passages are loaded; call load-passages! first"))

(defvar *corpus* (make-corpus)
  "The loaded book and the passage the piece is on")

(defun default-passages-path ()
  "corpus/passages.txt in the repo, wherever the process was started."
  (asdf:system-relative-pathname :squiggle "corpus/passages.txt"))

(defun corpus-loaded-p (corpus)
  (plusp (length (corpus-passages corpus))))

(defun wrap-index (corpus index)
  "INDEX wrapped onto CORPUS's passages"
  (mod index (length (corpus-passages corpus))))

(defun skip-passages (corpus n)
  "CORPUS moved N passages ahead, wrapping to the start at the end of the book"
  (corpus-with corpus :index (wrap-index corpus (+ (corpus-index corpus) n))))

(defun load-passages! (&optional (path (default-passages-path)))
  "Load PATH from its first passage. Returns :loaded."
  (setf *corpus* (make-corpus :passages (coerce (uiop:read-file-lines path) 'vector)))
  :loaded)

(defun next-passage! ()
  "Signals corpus-not-loaded before load-passages!"
  (let ((corpus *corpus*))
    (unless (corpus-loaded-p corpus)
      (error 'corpus-not-loaded))
    (setf *corpus* (skip-passages corpus 1))
    (aref (corpus-passages corpus) (corpus-index corpus))))

(defun advance-passages! (n)
  "Skip N passages ahead wrapping at the end of the book.
Returns :advanced or :not-loaded (before load-passages!)"
  (let ((corpus *corpus*))
    (cond ((not (corpus-loaded-p corpus)) :not-loaded)
          (t (setf *corpus* (skip-passages corpus n))
             :advanced))))
