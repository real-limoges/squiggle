;;;; smoke.lisp
;;;;
;;;; CI's run of the production path that exists today (TODO.md T20): start the
;;;; server, tick on the fake oracle, and read the pages and frames over real HTTP,
;;;; as a browser would. The unit tests never start the server; this does.
;;;; Once loop-guide.md lands, this starts the piece with start! instead.
;;;;
;;;; Run from the repo root after loading :squiggle/web:
;;;;   sbcl --non-interactive ... --eval '(ql:quickload :squiggle/web)' --load ci/smoke.lisp

(defpackage :squiggle/smoke
  (:use :cl))

(in-package :squiggle/smoke)

(defparameter +port+ 8080)

(defparameter +ticks+ 3
  "Ticks to run while a viewer watches /events")

(defparameter +timeout-seconds+ 5
  "How long any one read may wait, so a stuck server fails the run instead of hanging it")

;;; --- HTTP ---

(defun url (path)
  (format nil "http://localhost:~D~A" +port+ path))

(defun status-of (path)
  "The HTTP status code GET PATH returns"
  (handler-case (nth-value 1 (dex:get (url path) :read-timeout +timeout-seconds+))
    (dex:http-request-failed (failure) (dex:response-status failure))))

(defun body-of (path)
  (dex:get (url path) :read-timeout +timeout-seconds+))

(defun open-events ()
  "A socket on /events. A plain HTTP/1.0 request, so the reply is the bare event
stream with no chunking to decode"
  (let ((socket (usocket:socket-connect "localhost" +port+ :element-type 'character)))
    (format (usocket:socket-stream socket) "GET /events HTTP/1.0~C~C~C~C"
            #\Return #\Newline #\Return #\Newline)
    (force-output (usocket:socket-stream socket))
    socket))

(defun read-line-within (socket)
  "The next line from SOCKET. Signals when nothing arrives within +timeout-seconds+"
  (let ((stream (usocket:socket-stream socket)))
    (unless (or (listen stream)
                (usocket:wait-for-input socket :timeout +timeout-seconds+ :ready-only t))
      (error "No line from /events within ~D seconds" +timeout-seconds+))
    (read-line stream)))

(defun frame-line-p (line)
  (and (< 6 (length line)) (string= "data: " line :end2 6)))

(defun next-frame (socket)
  "The next SSE data line on SOCKET, skipping headers, blank lines and pings"
  (loop for line = (read-line-within socket)
        when (frame-line-p line) return line))

;;; --- Checks ---

(defun check (label passed)
  "Print LABEL with its result. Returns :passed or :failed"
  (format t "~&~:[FAIL~;ok  ~] ~A~%" passed label)
  (if passed :passed :failed))

(defun svg-frame-p (line)
  (and line (search "<svg" line) t))

(defun check-pages ()
  (list (check "/ is 200 and holds the canvas"
               (and (= 200 (status-of "/")) (search "<svg" (body-of "/")) t))
        (check "/about is 200" (= 200 (status-of "/about")))
        (check "an unknown path is 404" (= 404 (status-of "/no-such-page")))))

(defun tick-and-read (socket)
  "Tick once on the fake oracle, then read the frame it broadcast"
  (squiggle/backend:tick! (squiggle/oracle:make-fake-oracle))
  (next-frame socket))

(defun check-frames ()
  (let ((socket (open-events)))
    (unwind-protect
         (cons (check "/events sends the current frame on connect" (svg-frame-p (next-frame socket)))
               (loop for tick from 1 to +ticks+
                     collect (check (format nil "tick ~D reaches the viewer as a frame" tick)
                                    (svg-frame-p (tick-and-read socket)))))
      (usocket:socket-close socket))))

(defun check-stop ()
  (list (check "stop-server! returns :stopped" (eq :stopped (squiggle/web:stop-server!)))
        (check "no tick observers are left" (null squiggle/backend:*tick-observers*))))

;;; --- Run ---

(defun run-smoke ()
  "Start the server, run every check, stop it. Returns :passed or :failed"
  (squiggle/web:start-server! :port +port+)
  (let ((results (append (check-pages) (check-frames) (check-stop))))
    (if (every (lambda (result) (eq :passed result)) results) :passed :failed)))

(uiop:quit (ecase (run-smoke)
             (:passed 0)
             (:failed 1)))
