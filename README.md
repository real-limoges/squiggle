# squiggle

A self-evolving abstract composition.

## Run

```
$ sbcl
* (require :asdf)
* (asdf:load-system :squiggle)
* (in-package :squiggle)
* (demo)
```

## Dev

**Tests**
```bash
sbcl --non-interactive \
     --load ~/quicklisp/setup.lisp \
     --eval "(push #p\"$(pwd)/\" asdf:*central-registry*)" \
     --eval '(ql:quickload :squiggle/tests)' \
     --eval '(uiop:quit (if (fiveam:run-all-tests :squiggle) 0 1))'
```

**Lint**
```bash
sbcl --non-interactive \
     --load ~/quicklisp/setup.lisp \
     --eval '(ql:quickload :sblint)' \
     --eval '(uiop:quit (if (zerop (sblint:run-lint-asd #p"squiggle.asd")) 0 1))'
```

Or via the `sblint` shell function (defined in `~/.zshrc`) — run it from any CL project root.
