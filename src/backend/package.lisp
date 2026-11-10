;;;; package.lisp: the engine (state, mutations, validation, tick)

(defpackage :squiggle/backend
  (:use :cl :squiggle)
  (:export
   :*oracle-rng* :*jitter-rng* :seed-rngs!
   :*state* :*tick-observers*
   :boot! :reset! :make-seed-canvas
   :stamp-layers :apply-mutation :apply-mutations
   :with-entities :update-entity
   :apply-nudge :apply-recolor :apply-resize :apply-add :apply-remove
   :validate-mutation :validate-mutations
   :tick!
   :demo))
