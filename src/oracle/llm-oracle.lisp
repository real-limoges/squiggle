;;;; llm-oracle.lisp
;;;;
;;;; LLM-backed oracle. Peer to fake-oracle: same interface (state → mutations),
;;;; different implementation. Runtime config picks which one tick! calls.

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

Don't explain. Just the score and the words."
  "Qwen prompt template; ~A = corpus passage. Rationale lives in docs/prompt.md.")

(defstruct parsed mood colors shapes numbers)

(defun json-object (&rest plist)
  "Build a JSON object string from a flat KEY VALUE plist (string keys)."
  (let ((h (make-hash-table :test 'equal)))
    (loop for (k v) on plist by #'cddr do (setf (gethash k h) v))
    (jzon:stringify h)))

(defun call-ollama (prompt)
  "POST PROMPT to the local Ollama sidecar; return Qwen's raw completion string."
  (let ((response (dex:post "http://localhost:11434/api/generate"
                            :headers '(("Content-Type" . "application/json"))
                            :content (json-object "model" "qwen2.5:1.5b"
                                                  "prompt" prompt
                                                  "stream" nil))))
    (gethash "response" (jzon:parse response))))

(defun build-prompt (passage)
  (format nil *prompt-template* passage))

(defun scan-mood (text)
  "Extracts the mood from TEXT"
  (ppcre:register-groups-bind ((#'parse-integer mood))
    ("MOOD=(\\d+)" text)
    (max 1 (min 10 mood))))

(defun scan-keywords (text valid)
  "Finds KEYWORDS in TEXT that are in the VALID list"
  (loop for tok in (ppcre:split "\\s+" text)
        for kw = (find-symbol (string-upcase tok) :keyword)
        when (member kw valid) collect kw))

(defun scan-numbers (text)
  "Integer tokens in TEXT"
  (loop for tok in (ppcre:split "\\s+" text)
        for n = (parse-integer tok :junk-allowed t)
        when n collect n))

(defun assemble-mutations (parsed state rng)
  "Draw ONE mutation from PARSED's token bags. Returns a 1-element list, or ()."
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
  "Qwen text -> parsed token bags. Pure, lenient — unknown tokens ignored,
   never errors."
  (make-parsed :mood    (scan-mood text)
               :colors  (scan-keywords text +palette+)
               :shapes  (scan-keywords text +entity-types+)
               :numbers (scan-numbers text)))

(defun llm-oracle (state rng)
  "Run one Qwen turn -> one mutation. Falls back to fake-oracle on any error
   (Ollama down, HTTP failure) or an empty parse."
  (handler-case
      (let* ((parsed (parse-response (call-ollama (build-prompt (next-passage!)))))
             (muts   (assemble-mutations parsed state rng)))
        (if muts
            (make-oracle-result :mutations muts :mood (parsed-mood parsed))
            (fake-oracle state rng)))
    (error () (fake-oracle state rng))))

