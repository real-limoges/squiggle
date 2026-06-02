(ql:quickload :str)

(defun count-sentences (paragraph)
  (count-if (lambda (c) (member c '(#\. #\! #\?))) paragraph))

(defun valid-paragraph? (text)
    (<= 3 (count-sentences text) 20))

(defun split-on-blank-lines (text)
  (let ((paragraphs nil)
        (current nil))
    (dolist (line (str:lines text))
      (cond ((str:blank? line)
             (when current
                (push (str:join " " (nreverse current)) paragraphs)
                (setf current nil)))
              (t (push line current))))
          (when current
            (push (str:join " " (nreverse current)) paragraphs))
          (nreverse paragraphs)))

(defun preprocess-corpus (&key (in "corpus/book.txt") (out "corpus/passages.txt"))
  (let* ((text (uiop:read-file-string in))
         (split-text (split-on-blank-lines text))
         (filtered-text (remove-if-not #'valid-paragraph? split-text)))
    (with-open-file (stream out :direction :output
                                :if-exists :supersede
                                :if-does-not-exist :create)
      (dolist (passage filtered-text)
        (write-line passage stream)))
    (length filtered-text)))

(preprocess-corpus)