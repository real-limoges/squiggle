# Architecture

Map of what's where. Rationale lives in `ROADMAP.md`.

## Layout

```
squiggle/
├── squiggle.asd            ASDF system definitions (3 subsystems)
├── src/
│   ├── package.lisp        :squiggle base package (shared vocabulary)
│   ├── types.lisp          constants, structs, canvas helpers  (:squiggle)
│   ├── backend/
│   │   ├── package.lisp     :squiggle/backend defpackage
│   │   ├── backend.lisp     RNGs, *state*, dispatch, jitter, lifecycle, tick!
│   │   ├── mutation.lisp    pure mutation verbs (apply-*)
│   │   ├── validator.lisp   C2 — validate-mutation/validate-mutations drafted; tick! integration pending
│   │   ├── tempo.lisp       mood→tick-rate lookup (E2 — tick-interval stub; not yet in any ASDF system)
│   │   └── inspect.lisp     REPL tools: print-state, print-tick, demo
│   └── oracle/
│       ├── package.lisp     :squiggle/oracle defpackage (jzon/ppcre nicknames)
│       ├── oracle.lisp      *oracle* defvar, random substrate, oracle toggles
│       ├── fake-oracle.lisp PRNG oracle (dev + test + runtime fallback)
│       ├── corpus.lisp      passage loader + sequential pointer (E1)
│       └── llm-oracle.lisp  Qwen oracle: prompt, HTTP, parse, assemble
├── tests/
│   ├── package.lisp        :squiggle/tests pkg, suite def, deftest-engine macro
│   └── mutation-tests.lisp unit tests for apply-*
├── corpus/                 gitignored — local text input
├── docs/                   gitignored — ROADMAP, BUILD-PLAN, ARCHITECTURE, prompt
└── .github/workflows/      CI
```

Planned files are tagged with their `BUILD-PLAN.md` task ID. Untagged files exist today.

## ASDF systems

| System | Depends on | Purpose |
| --- | --- | --- |
| `:squiggle` | — | Shared vocabulary: constants, structs, canvas helpers |
| `:squiggle/oracle` | `:squiggle` | Oracle implementations + random-draw substrate |
| `:squiggle/backend` | `:squiggle`, `:squiggle/oracle` | Engine: state, mutations, dispatch, lifecycle, tick |
| `:squiggle/tests` | all three + `fiveam` | Test suite |

## Packages

- **`:squiggle`** — constants (`+palette+`, `+canvas-w+`, `+canvas-h+`, `+entity-types+`, `+min-scale+`, `+max-scale+`), `entity`, `canvas`, and `oracle-result` defstructs and their accessors, `entities`, `find-entity`.
- **`:squiggle/oracle`** — `*oracle*` defvar, `random-elt`, `random-id`, `random-delta`, `*generators*`, `fake-oracle`, `llm-oracle`, `use-fake-oracle!`, `use-llm-oracle!`, `load-passages!`, `next-passage!`.
- **`:squiggle/backend`** — `*oracle-rng*`, `*jitter-rng*`, `seed-rngs!`, `*state*`, `boot!`, `reset!`, `make-seed-canvas`, `stamp-layers`, `apply-mutation`, `apply-mutations`, `with-entities`, `update-entity`, all `apply-*` verbs, `tick!`, `demo`.
- **`:squiggle/tests`** — test package; imports all three packages above plus `fiveam`.
- **`:squiggle.aesthetic`** — deferred (post-v1).

## Module responsibilities

| File | Owns |
| --- | --- |
| `src/package.lisp` | The base `:squiggle` `defpackage` + exports (shared vocabulary). Subsystem packages live beside their code — see the two rows below. |
| `src/oracle/package.lisp` | `:squiggle/oracle` `defpackage` + exports, with the `(:jzon …)` / `(:ppcre …)` local nicknames. First component of `:squiggle/oracle` so the nicknames resolve against that system's deps. |
| `src/backend/package.lisp` | `:squiggle/backend` `defpackage` + exports. |
| `src/types.lisp` | Palette + canvas/scale/type constants. `entity`, `canvas`, and `oracle-result` `defstruct` definitions. `entities` and `find-entity` accessors. (`oracle-result` = `{mutations, mood}`, the shared oracle→engine return contract — lives here because both oracles produce it and `tick!` consumes it.) |
| `src/oracle/oracle.lisp` | `*oracle*` defvar (defaults to `nil`; set to `#'fake-oracle` by `fake-oracle.lisp` on load). `use-llm-oracle!` / `use-fake-oracle!` — flip `*oracle*` at runtime. `random-elt`, `random-id`, `random-delta` — shared random-draw helpers used by both oracle impls. |
| `src/oracle/fake-oracle.lisp` | Per-verb generators (`gen-nudge`, `gen-recolor`, `gen-resize`, `gen-add`, `gen-remove`). `*generators*` list. `fake-oracle` function — returns an `oracle-result` (one mutation per call + a random mood 1–10 from `*oracle-rng*`); one-mutation-per-call mirrors the LLM oracle so swapping oracles doesn't change per-tick density. Sets `*oracle*` to `#'fake-oracle` on load. |
| `src/oracle/llm-oracle.lisp` | `llm-oracle` — same `(state rng)` signature, returns an `oracle-result`, `handler-case`-falls back to `fake-oracle` on any error or empty parse. `*prompt-template*` defparameter; `build-prompt`; `json-object` helper; `call-ollama` (dexador→Ollama, jzon decode); pure scanners `scan-mood` (ppcre `MOOD=(\d+)`) / `scan-keywords` / `scan-numbers`; `parse-response (text)` → internal `parsed` struct; `assemble-mutations (parsed state rng)` — `cond` random-draw, one mutation per call (priority add > recolor > nudge). The `parsed` struct (Qwen token bags) is defined here and never leaves this file. |
| `src/backend/backend.lisp` | Two PRNGs (`*oracle-rng*`, `*jitter-rng*`). `seed-rngs!`, `entropy-seed`, `make-rng`. `*state*` defparameter. `with-entities`, `update-entity` state-threading helpers. `stamp-layers` (rewrites `:add` mutations with a `:layer` drawn from `*jitter-rng*`). `apply-mutation` dispatch, `apply-mutations` reducer. Pattern jitter (D1): `jitter-mutations`, `make-nudge`, `make-recolor`, `random-signed`, `+jitter-nudge-prob+` / `+jitter-recolor-prob+` / `+jitter-magnitude+`. `boot!`, `reset!`, `make-seed-canvas` lifecycle. `tick!` loop. |
| `src/backend/mutation.lisp` | One function per verb: `apply-nudge`, `apply-recolor`, `apply-resize`, `apply-add`, `apply-remove`. Pure: state in, new state out. Validation is the validator's job (C2). |
| `src/backend/inspect.lisp` | `print-entity`, `print-state`, `print-tick`. `demo` — loads seed canvas, runs N ticks with output. REPL convenience only; not called by the engine. |
| `src/backend/validator.lisp` *(C2 — validator drafted; tick! stage pending)* | `validate-mutation` / `validate-mutations`: drop only for invalidity (unknown verb, off-palette color, off-vocab type), clamp `:add` coords to canvas bounds rather than reject. Never aesthetic. Both written and exported; `tick!` doesn't call them yet (the remaining C2 step). |
| `src/oracle/corpus.lisp` | `load-passages!` reads `corpus/passages.txt` into the `*passages*` vector; `next-passage!` returns the current passage and advances `*passage-idx*` (wraps at end). Disk-persistence of the pointer still TODO (E1). |
| `src/backend/tempo.lisp` *(E2/E3 — stub)* | mood→rate lookup (`tick-interval`, re-derived on a ~5-tick cadence from `*last-mood*`; no separate Qwen query — mood rides in each `oracle-result`), mood ring buffer, low-variance → corpus jump. |
| `loop.lisp` *(F1)* | Thin wrapper: calls `(tick!)` on a timer derived from current mood. The only place that runs forever. |
| `web.lisp` *(G1)* | HTTP server, single canvas endpoint. |
| `svg.lisp` *(G2)* | Pure `state → svg-string`, z-ordered by `:layer`. |
| `log.lisp` *(H1)* | SQLite append-only log of applied mutations (post-validator, post-jitter). |
| `debug-page.lisp` *(H2)* | `/debug` HTML: sparklines for entity count, mutations/tick, mood timeline, corpus pointer. |
| `tests/` | Property + unit tests on pure mutation functions; mock-Qwen adversarial tests; uses fake oracle only. |

## State shape

```lisp
;; canvas struct  (make-canvas / copy-canvas)
(canvas-next-id  state)   ; integer — monotonically assigned by apply-add; oracle never picks ids
(canvas-entities state)   ; list of entity structs, ordered by insertion

;; entity struct  (make-entity / copy-entity)
(entity-id    e)   ; integer
(entity-type  e)   ; keyword — member of +entity-types+
(entity-pos   e)   ; (x y) list
(entity-scale e)   ; float
(entity-color e)   ; keyword — member of +palette+
(entity-layer e)   ; integer — assigned at add time by stamp-layers; never mutated

;; oracle-result struct  (make-oracle-result / copy-oracle-result)
(oracle-result-mutations r)   ; list of raw mutation s-exprs (validated later, in tick!)
(oracle-result-mood      r)   ; integer 1–10, or NIL
```

Every oracle returns an `oracle-result`. The `parsed` struct (Qwen's scanned token bags — mood + colors/shapes/numbers) is an llm-oracle implementation detail and does **not** appear here; it's consumed by `assemble-mutations` before `llm-oracle` returns.

`*state*` is the single live composition, rebound (never mutated in place) each tick.

Layer render contract: sort entities ascending by `:layer`; tiebreak by `:id`. Higher layer paints on top.

## Mutation verbs

| Verb | Args | Effect |
| --- | --- | --- |
| `:nudge`   | `id dx dy`           | shift position |
| `:recolor` | `id color`           | set color |
| `:resize`  | `id factor`          | multiply scale |
| `:add`     | `type x y color layer` | append new entity, assign id |
| `:remove`  | `id`                 | drop entity |

Unknown verbs return state unchanged (`apply-mutation` `otherwise` branch).

`:layer` in `:add` is injected by `stamp-layers` (called in `tick!`) — oracles never set it.

## Tick lifecycle

```
tick! [oracle]                          oracle is now a mandatory arg (C3 landed)
  └─ boot!                              seed RNGs from entropy if not yet seeded
  └─ (oracle *state* *oracle-rng*)      → oracle-result {mutations, mood}  (contract; tick! doesn't unwrap it yet)
  └─ stamp-layers [*jitter-rng*]        → rewrites :add entries with :layer value
  └─ apply-mutations → setf *state*     → reduce apply-mutation over stamped list
  └─ jitter-mutations [*jitter-rng*]    → sub-perceptual nudge/recolor, applied (D1)
  └─ return oracle mutations

Planned additions (build plan):
  C2 — consume the oracle-result contract: unwrap .mutations (and validate them
       before stamp-layers), route .mood into *last-mood* for the E-series scheduler.
       tick! still feeds the oracle return straight in as a bare list today (see gap).
  D2 — heal! guard on entity count after apply-mutations
  E2/F1 — mood-driven scheduler wrapping tick!
```

`tick!` now takes the oracle as a **mandatory argument** (C3) — it no longer reads `*oracle*` itself. `*oracle*` remains the configured default: set to `#'fake-oracle` by `fake-oracle.lisp` on load, flipped at runtime by `use-llm-oracle!` / `use-fake-oracle!`. The prod loop (F1) and REPL pass it in as `(tick! *oracle*)`; tests pass an oracle directly, e.g. `(tick! #'fake-oracle)`.

**Current gap (`tick!` doesn't consume `oracle-result` yet):** both oracles now return an `oracle-result` — `llm-oracle` parses one, `fake-oracle` wraps one (one mutation + mood). But `tick!` still feeds the oracle's return value straight into `stamp-layers` / `apply-mutations` as if it were a bare mutation *list* — it does not yet unwrap `oracle-result-mutations` or route `oracle-result-mood` into `*last-mood*`. So `(tick! …)` would now hand `stamp-layers` a struct it can't map, and mood routing isn't wired. Wiring `tick!` to consume the contract is the remaining **C2** step (the C3 signature change has landed).

## External dependencies

ASDF `:depends-on` (current) —
- `fiveam` — test framework (`:squiggle/tests` only)
- `dexador` — HTTP client for Ollama (`:squiggle/oracle`)
- `com.inuoe.jzon` — JSON encode/decode for Ollama bodies + responses (`:squiggle/oracle`)
- `cl-ppcre` — regex for Qwen response parsing (`:squiggle/oracle`)

All three HTTP/JSON/regex deps are scoped to `:squiggle/oracle` (not core `:squiggle`) — the engine stays dependency-free. Referenced via dexador's built-in `dex:` nickname and the `(:jzon :com.inuoe.jzon)` / `(:ppcre :cl-ppcre)` package-local nicknames on the `:squiggle/oracle` `defpackage`. That `defpackage` lives in `src/oracle/package.lisp` (not the base `src/package.lisp`) precisely so the nicknames resolve against deps the `:squiggle/oracle` system loads — keeping the base `:squiggle` system dependency-free.

System Lisp: SBCL via Quicklisp.

## Build & run

```lisp
$ sbcl
* (require :asdf)
* (asdf:load-system :squiggle/backend)
* (in-package :squiggle/backend)
* (demo)        ; or (tick!) for a single step
```

Run tests (from the REPL: `(asdf:test-system :squiggle/tests)`, which the `.asd` `:perform` maps to `(fiveam:run! :squiggle)`):
```bash
sbcl --non-interactive \
     --load ~/quicklisp/setup.lisp \
     --eval "(push #p\"$(pwd)/\" asdf:*central-registry*)" \
     --eval '(ql:quickload :squiggle/tests)' \
     --eval '(uiop:quit (if (uiop:symbol-call :fiveam :run! :squiggle) 0 1))'
```
