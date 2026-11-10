;;;; package.lisp
;;;;
;;;; :squiggle/web: the SVG emitter, the pages, and the SSE server

(defpackage :squiggle/web
  (:use :cl :squiggle :cl-who)
  (:import-from :squiggle/backend #:*state* #:*tick-observers*)
  (:export
   :render-svg :canvas-page :about-page
   :start-server! :stop-server!))
