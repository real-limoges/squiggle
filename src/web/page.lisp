;;;; page.lisp
;;;;
;;;; Canvas page and about page. Functions that return HTML


(in-package :squiggle/web)

(defparameter +page-css+
  "body { margin: 0; background: #f6ecd2; font-family: sans-serif; }
#stage { position: relative; width: min(100vw, 1000px); aspect-ratio: 8 / 5; margin: 0 auto; }
#stage svg { position: absolute; inset: 0; width: 100%; height: 100%; animation: fade-in 0.8s ease both; }
@keyframes fade-in { from { opacity: 0; } }")

(defparameter +page-js+
  "const stage = document.getElementById('stage');
new EventSource('/events').onmessage = (e) => {
  stage.insertAdjacentHTML('beforeend', e.data);
  const frames = stage.querySelectorAll('svg');
  if (frames.length > 2) frames[0].remove();
};")

(defun canvas-page (svg)
  "The full canvas page. SVG as its first frame."
  (with-html-output-to-string (s nil :prologue "<!DOCTYPE html>")
    (:html
     (:head (:meta :charset "utf-8")
            (:title "squiggle")
            (:style (str +page-css+)))
     (:body (:div :id "stage" (str svg))
            (:script (str +page-js+))))))

(defun about-page ()
  "The static about page."
  (with-html-output-to-string (s nil :prologue "<!DOCTYPE html>")
    (:html
     (:head (:meta :charset "utf-8")
            (:title "about squiggle")
            (:style (str +page-css+)))
     (:body (:h1 "squiggle")
            (:p "An experiment where I tried to crush so much 90s into something that it would implode on itself.")
            (:p (:a :href "/" "Back to the canvas."))))))
