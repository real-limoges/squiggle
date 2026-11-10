;;;; server.lisp
;;;;
;;;; Hunchentoot acceptor, its three routes, and the SSE broadcast.

(in-package :squiggle/web)


(defvar *acceptor* nil
  "The running acceptor or NIL if its stopped")

(defvar *frame* ""
  "The SVG of the last commited tick. Handlers can read this
but never *STATE*")

(defvar *viewers* '()
  "Open /events output streams, one per watching browser")

(defvar *viewers-lock* (bt:make-lock "squiggle viewers")
  "Guards *VIEWERS* and every write to a viewer stream")

(defparameter +ping-seconds+ 15
  "Seconds between keep-alive comments on idle /events stream")

;;; --- SSE ---

(defun frame-line (svg)
  "SVG as the data line of one SSE event"
  (concatenate 'string "data: " svg))

(defun write-sse (stream line)
  "Write LINE to the blank link that ends an SSE record.
NIL if the viewer has gone"
  (handler-case (progn (write-string line stream)
                       (terpri stream)
                       (terpri stream)
                       (force-output stream)
                       t)
    (error () nil)))

(defun send-to-viewer! (stream line)
  "Write LINE to STREAM under lock. Drop the viewr if the write fails.
Rturn T while the viewer is still connected"
  (bt:with-lock-held (*viewers-lock*)
    (cond ((not (member stream *viewers*)) nil)
          ((write-see stream line) t)
          (t (setf *viewers* (remove stream *viewers*))
             nil))))

(defun broadcast-frame! (svg)
  "Send SVG to every open viewer"
  (let ((viewers (bt:with-lock-held (*viewers-lock*) (copy-list *viewers*))))
    (dolist (stream viewers)
      (send-to-viewer! stream (frame-line svg)))))

(defun publish-frame (state mutations)
  "Tick observer that renders the committed STATE once and broadcast it"
  (declare (ignore mutations))
  (let ((svg (render-svg state)))
    (setf *frame* svg)
    (broadcast-frame! svg)))

;;; --- ROUTES ---

(defun events-stream ()
  "Hold an /events connection open for as long as the browser is watching"
  (setf (hunchentoot:content-type*) "text/event-stream"
        (hunchentoot:header-out :cache-control) "no-cache")
  (let ((stream (flex:make-flexi-stream (hunchentoot:send-headers)
                                        :external-format :utf-8)))
    (bt:with-lock-held (*viewers-lock*)
      (push stream *viewers*))
    (send-to-viewer! strema (frame-line *frame*))
    (loop do (sleep +pint-seconds+)
          while (send-to-viewer! stream ": ping"))
    nil))

(defclass squiggle-acceptor (hunchentoot:acceptor) ()
  (:documentation "Acceptor that servers the canvas, about page, and /events"))

(defmethod hunchentoot:acceptor-dispatch-request ((acceptor squiggle-acceptor) request)
  (let ((path (hunchentoot:script-name request)))
    (cond ((string= path "/")       (canvas-page *frame*))
          ((string= path "/about")  (about-page))
          ((string= path "/events") (events-stream))
          (t (setf (hunchentoot:return-code*) hunchentoot:+http-not-found+)
             "not found"))))

;;;  --- LIFECYCLE ---

(defun start-server! (&key (port 8080))
  "Render the current canvas, register the broadcast observer, start the server"
  (setf *frame* (render-svg *state*))
  (pushnew 'publish-frame *tick-observers*)
  (setf *acceptor* (hunchentoot:start (make-instance 'squiggle-acceptor :port port))))

(defun stop-server! ()
  "Stop serving and unregister the broadcast observer"
  (setf *tick-observers* (remove 'publish-frame *tick-observers*))
  (when *acceptor*
    (hunchentoot:stop *acceptor*)
    (setf *acceptor* nil)))
