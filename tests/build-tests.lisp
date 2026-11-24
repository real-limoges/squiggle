;;;; build-tests.lisp: every source file is compiled by some system
;;;; A file no system names is never compiled, so the strict build can't see its
;;;; warnings and its code silently isn't there.

(in-package :squiggle/tests)

(in-suite :squiggle)

(defun squiggle-systems ()
  "Every system defined in squiggle.asd"
  (let ((asd (asdf:system-source-file :squiggle)))
    (remove-if-not (lambda (system) (uiop:pathname-equal (asdf:system-source-file system) asd))
                   (mapcar #'asdf:find-system (asdf:registered-systems)))))

(defun component-files (system)
  (mapcar #'asdf:component-pathname
          (remove-if-not (lambda (component) (typep component 'asdf:cl-source-file))
                         (asdf:component-children system))))

(defun lisp-files-under (directory-name)
  "Every .lisp file under DIRECTORY-NAME in the repo, at any depth"
  (directory (merge-pathnames (make-pathname :directory (list :relative directory-name :wild-inferiors)
                                             :name :wild :type "lisp")
                              (asdf:system-source-directory :squiggle))))

(defun source-files ()
  "Every .lisp file under src/ and tests/"
  (append (lisp-files-under "src") (lisp-files-under "tests")))

(defun orphan-files ()
  "Source files no squiggle system names as a component"
  (set-difference (source-files)
                  (mapcan #'component-files (squiggle-systems))
                  :test #'uiop:pathname-equal))

(test every-source-file-is-a-component
  (is (plusp (length (source-files))))
  (is (null (orphan-files))))
