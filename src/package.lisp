;;;; package.lisp: shared vocabulary every subsystem uses
;;;; Subsystem packages live beside their code so each one's dependencies stay
;;;; with its own ASDF system.

(defpackage :squiggle
  (:use :cl)
  (:export
   :+palette+ :+canvas-w+ :+canvas-h+ :+min-scale+ :+max-scale+ :+entity-types+
   :make-entity :copy-entity
   :entity-id :entity-type :entity-pos :entity-scale :entity-color :entity-layer
   :make-canvas :copy-canvas :canvas-entities :canvas-next-id
   :entities :find-entity
   :make-oracle-result :copy-oracle-result :oracle-result-p
   :oracle-result-mutations :oracle-result-mood ))
