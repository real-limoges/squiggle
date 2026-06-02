# squiggle

A self-evolving abstract composition.

Squiggle is a Common Lisp engine for an always-on piece of generative art in the 90s Memphis Group style — blobs, squiggles, triangles, and curves on five fixed colors. A small local LLM reads passages from a book and barfs out words and numbers that the engine turns into shape mutations on a canvas. The book's mood decides how fast the piece moves. Nobody can interact with it. It just sits there forever, slowly redecorating itself.

## Run

```
$ sbcl
* (require :asdf)
* (asdf:load-system :squiggle/backend)
* (in-package :squiggle/backend)
* (demo)
```

## Dev

**Tests**
```bash
sbcl --non-interactive \
     --load ~/quicklisp/setup.lisp \
     --eval "(push #p\"$(pwd)/\" asdf:*central-registry*)" \
     --eval '(ql:quickload :squiggle/tests)' \
     --eval '(uiop:quit (if (uiop:symbol-call :fiveam :run! :squiggle) 0 1))'
```

**Lint**
```bash
sbcl --non-interactive \
     --load ~/quicklisp/setup.lisp \
     --eval '(ql:quickload :sblint)' \
     --eval '(uiop:quit (if (zerop (sblint:run-lint-asd #p"squiggle.asd")) 0 1))'
```

Or via the `sblint` shell function (defined in `~/.zshrc`) — run it from any CL project root.
