;;;; package.lisp
;;;;
;;;; Test package, suite, and shared infrastructure.

(defpackage :squiggle/tests
  (:use :cl :fiveam :squiggle))

(in-package :squiggle/tests)

(def-suite :squiggle
  :description "Squiggle tests")

(in-suite :squiggle)

(defmacro deftest-engine (name &body body)
  "Define a test in the :squiggle suite, resetting engine state first."
  `(test (,name :suite :squiggle)
     (reset! 42)
     ,@body))