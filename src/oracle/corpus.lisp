;;;; corpus.lisp: walks the book one passage at a time

(in-package :squiggle/oracle)

(define-frozen-struct corpus (:copier corpus-with :fixed (passages path))
  (passages #())
  (path     nil)                        ; passages filename or NIL
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

(defun pointer-path-for (passages-path)
  "corpus/pointer beside PASSAGES-PATH with no file type"
  (make-pathname :name "pointer" :type nil :defaults passages-path))

(defun read-pointer
  "The index saved at POINTER-PATH or 0"
  (with-open-file (in pointer-path :if-does-not-exist nil)
    (if in
        (let ((*read-eval nil)) (read in))
        0)))

(defun read-corpus (truename)
  "Corpus of the passages at TRUENAME resumed from the pointer beside it"
  (let ((corpus (make-corpus :passages (coerce (uiop:read-file-lines truename) 'vector)
                             :path truename)))
    (skip-passages corpus (read-pointer (pointer-path-for truename)))))

(defun load-passages! (&optional (path (default-passages-path)))
  "Load PATH + resume from its saved pointer. Returns :loaded or :missing)"
  (let ((truename (probe-file path)))
    (cond ((null truename) :missing)
          (t (setf *corpus* (read-corpus truename))
             :loaded))))

(defun ensure-passages! ()
  "Load the corpus (unless its already loaded). Returns :alread-loaded or
whatever load-passages! returns"
  (if (corpus-loaded-p *corpus*)
      :already-loaded
      (load-passages!)))

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

(defun write-pointer! (index pointer-path)
  "Write INDEX to POINTER-PATH through a temp file and a rename.
Crashes mid-write never leave a torn pointer"
  (let ((tmp (make-pathname :name "pointer-new" :defaults pointer-path)))
    (with-open-file (out tmp :direction :output :if-exists :supersede)
      (prin1 index out))
    (uiop:rename-file-overwriting-target tmp pointer-path)))

(defun save-pointer! ()
  "Write the index beside the loaded passages. Returns :saved or :not-loaded"
  (let ((corpus *corpus*))
    (cond ((not (corpus-loaded-p corpus)) :not-loaded)
          (t (write-pointer! (corpus-index corpus) (pointer-path-for (corpus-path corpus)))
             :saved))))
