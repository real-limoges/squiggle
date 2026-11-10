;;;; package.lisp: test package, suite and the deftest-engine macro

(defpackage :squiggle/tests
  (:use :cl :fiveam
        :squiggle :squiggle/backend :squiggle/oracle :squiggle/web))

(in-package :squiggle/tests)

(def-suite :squiggle
  :description "Squiggle tests")

(in-suite :squiggle)

(defmacro deftest-engine (name &body body)
  "A test that starts from the seed canvas with RNGs seeded from 42."
  `(test (,name :suite :squiggle)
     (reset! 42)
     ,@body))
