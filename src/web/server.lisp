;;;; server.lisp
;;;;
;;;; Hunchentoot acceptor, its three routes, and the SSE broadcast.

(in-package :squiggle/web)

(defclass squiggle-acceptor (hunchentoot:acceptor) ()
  (:documentation "Acceptor that serves the canvas, about page, and /events"))

(defstruct server
  (acceptor nil :read-only t)
  (lock (bt:make-lock "squiggle viewers") :read-only t)
  ;; mutable
  (viewers '())
  (frame ""))

(defvar *server* :stopped
  "The running server, or :stopped. Handlers read its frame, never *STATE*")

(defparameter +ping-seconds+ 15
  "Seconds between keep-alive comments on idle /events stream")

;;; --- SSE ---

(defun frame-line (svg)
  "SVG as the data line of one SSE event"
  (concatenate 'string "data: " svg))

(defun write-sse (stream line)
  "Write LINE and the blank line that ends an SSE record.
Returns :sent, or :gone if the viewer has left"
  (handler-case (progn (write-string line stream)
                       (terpri stream)
                       (terpri stream)
                       (force-output stream)
                       :sent)
    (error () :gone)))

(defun deliver! (server stream line)
  "Write LINE to a registered viewer, dropping it if the write fails.
Call with the server lock held. Returns :sent or :dropped"
  (ecase (write-sse stream line)
    (:sent :sent)
    (:gone (setf (server-viewers server) (remove stream (server-viewers server)))
           :dropped)))

(defun send-to-viewer! (server stream line)
  "Write LINE to STREAM under the server lock. Returns :sent, :dropped, or
:unknown when STREAM is not a viewer"
  (bt:with-lock-held ((server-lock server))
    (if (member stream (server-viewers server))
        (deliver! server stream line)
        :unknown)))

(defun broadcast-frame! (server svg)
  "Send SVG to every open viewer"
  (let ((viewers (bt:with-lock-held ((server-lock server))
                   (copy-list (server-viewers server)))))
    (dolist (stream viewers)
      (send-to-viewer! server stream (frame-line svg)))))

(defmethod observe-tick ((server server) canvas mutations)
  "Render the committed CANVAS once and broadcast it"
  (declare (ignore mutations))
  (let ((svg (render-svg canvas)))
    (setf (server-frame server) svg)
    (broadcast-frame! server svg)))

;;; --- ROUTES ---

(defun events-stream (server)
  "Hold an /events connection open for as long as the browser is watching"
  (setf (hunchentoot:content-type*) "text/event-stream"
        (hunchentoot:header-out :cache-control) "no-cache")
  (let ((stream (flex:make-flexi-stream (hunchentoot:send-headers)
                                        :external-format :utf-8)))
    (bt:with-lock-held ((server-lock server))
      (push stream (server-viewers server)))
    (send-to-viewer! server stream (frame-line (server-frame server)))
    (loop do (sleep +ping-seconds+)
          while (eq :sent (send-to-viewer! server stream ": ping")))))

(defmethod hunchentoot:acceptor-dispatch-request ((acceptor squiggle-acceptor) request)
  (let ((path (hunchentoot:script-name request)))
    (cond ((string= path "/")       (canvas-page (server-frame *server*)))
          ((string= path "/about")  (about-page))
          ((string= path "/events") (events-stream *server*))
          (t (setf (hunchentoot:return-code*) hunchentoot:+http-not-found+)
             "not found"))))

;;;  --- LIFECYCLE ---

(defun start-server! (&key (port 8080))
  "Render the current canvas, register the server as a tick observer, start
serving. Signals if a server is already running"
  (unless (eq *server* :stopped)
    (error "The squiggle server is already running"))
  (let ((server (make-server :acceptor (make-instance 'squiggle-acceptor :port port)
                             :frame (render-svg *state*))))
    (setf *server* server)
    (push server *tick-observers*)
    (hunchentoot:start (server-acceptor server))
    server))

(defun stop-server! ()
  "Stop serving and unregister the observer. Returns :stopped, or :not-running"
  (if (eq *server* :stopped)
      :not-running
      (let ((server *server*))
        (setf *tick-observers* (remove server *tick-observers*))
        (hunchentoot:stop (server-acceptor server))
        (setf *server* :stopped))))
