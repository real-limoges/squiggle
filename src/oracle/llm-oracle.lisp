;;;; llm-oracle.lisp: Qwen reads a passage and answers with a mood and loose tokens
;;;; The prompt carries no canvas state; the reply's words and numbers are
;;;; scanned into token bags and one mutation is assembled from them.

(in-package :squiggle/oracle)

(defparameter *prompt-template*
  "Read this passage:

---
~A
---

Respond in this format:
\"MOOD=N <words and numbers>\"

Where:
- N is 1-10. 1 = slow, heavy, blue. 10 = racing, manic, electric.
  Don't default to 5 — use the full range.
- Words come from: teal, coral, cream, ink, mustard, blob, squiggle, triangle, curve
- Numbers are integers 0-800

Example: \"MOOD=8 coral squiggle 340 teal blob 120 triangle 600 mustard\"

Don't explain. Just the score and the words.")

(defstruct parsed mood colors shapes numbers)

(defun json-object (&rest plist)
  "Takes string keys."
  (let ((h (make-hash-table :test 'equal)))
    (loop for (k v) on plist by #'cddr do (setf (gethash k h) v))
    (jzon:stringify h)))

(defun call-ollama (prompt)
  (let ((response (dex:post "http://localhost:11434/api/generate"
                            :headers '(("Content-Type" . "application/json"))
                            :content (json-object "model" "qwen2.5:1.5b"
                                                  "prompt" prompt
                                                  "stream" nil))))
    (gethash "response" (jzon:parse response))))

(defun build-prompt (passage)
  (format nil *prompt-template* passage))

(defun scan-mood (text)
  (ppcre:register-groups-bind ((#'parse-integer mood))
    ("MOOD=(\\d+)" text)
    (max 1 (min 10 mood))))

(defun scan-keywords (text valid)
  (loop for tok in (ppcre:split "\\s+" text)
        for kw = (find-symbol (string-upcase tok) :keyword)
        when (member kw valid) collect kw))

(defun scan-numbers (text)
  (loop for tok in (ppcre:split "\\s+" text)
        for n = (parse-integer tok :junk-allowed t)
        when n collect n))

(defun assemble-mutations (parsed state rng)
  "At most one mutation: an :add if there is a shape and two numbers, else a
:recolor if there is a color, else a :nudge if there are two numbers."
  (let ((shape (car (parsed-shapes parsed)))
        (color (car (parsed-colors parsed)))
        (nums  (parsed-numbers parsed)))
    (cond
      ((and shape (>= (length nums) 2))
       (list (list :add shape (first nums) (second nums)
                   (or color (random-elt +palette+ rng)))))
      (color
        (list (list :recolor (random-id state rng) color)))
      ((>= (length nums) 2)
       (list (list :nudge (random-id state rng) (first nums) (second nums))))
      (t '()))))

(defun parse-response (text)
  (make-parsed :mood    (scan-mood text)
               :colors  (scan-keywords text +palette+)
               :shapes  (scan-keywords text +entity-types+)
               :numbers (scan-numbers text)))

(defun llm-oracle (state rng)
  "Falls back to the fake oracle when Ollama fails or the reply yields nothing."
  (handler-case
      (let* ((parsed (parse-response (call-ollama (build-prompt (next-passage!)))))
             (muts   (assemble-mutations parsed state rng)))
        (if muts
            (make-oracle-result :mutations muts :mood (parsed-mood parsed))
            (fake-oracle state rng)))
    (error () (fake-oracle state rng))))
