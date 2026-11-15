;;;; package.lisp: the engine (state, mutations, validation, tick)

(defpackage :squiggle/backend
  (:use :cl :squiggle)
  (:export
   :*rngs* :rngs-oracle :rngs-jitter :seed-rngs!
   :*state* :*tick-observers* :observe-tick
   :boot! :reset! :make-seed-canvas
   :stamp-layers :apply-mutation :apply-mutations
   :update-entity
   :apply-nudge :apply-recolor :apply-resize :apply-add :apply-remove
   :validate-mutation :validate-mutations
   :tick!
   :demo))
