# Architecture

A map of what lives where in the Squiggle source tree, as it stands on `main`.

## Layout

```
squiggle/
├── squiggle.asd            ASDF system definitions (base + 4 subsystems)
├── scripts/
│   └── preprocess-corpus.lisp  offline: corpus/book.txt → corpus/passages.txt
├── src/
│   ├── package.lisp        :squiggle base package (shared vocabulary)
│   ├── types.lisp          constants, structs, canvas helpers  (:squiggle)
│   ├── backend/
│   │   ├── package.lisp     :squiggle/backend defpackage
│   │   ├── backend.lisp     RNGs, *state*, dispatch, jitter, lifecycle, tick!
│   │   ├── mutation.lisp    pure mutation verbs (apply-*)
│   │   ├── validator.lisp   validate-mutation/validate-mutations; wired into tick!
│   │   ├── tempo.lisp       mood→tick-rate lookup (stub; not yet in any ASDF system)
│   │   └── inspect.lisp     REPL tools: print-state, print-tick, demo
│   ├── oracle/
│   │   ├── package.lisp     :squiggle/oracle defpackage (jzon/ppcre nicknames)
│   │   ├── oracle.lisp      oracle structs, propose generic, *oracle*, random substrate, toggles
│   │   ├── fake-oracle.lisp PRNG oracle (dev + test + runtime fallback)
│   │   ├── corpus.lisp      passage loader + sequential pointer
│   │   └── llm-oracle.lisp  Qwen oracle: prompt, HTTP, parse, assemble
│   ├── web/
│   │   ├── package.lisp     :squiggle/web defpackage
│   │   ├── svg.lisp         pure canvas → SVG string (placeholder squares)
│   │   ├── page.lisp        canvas and about pages, CSS fade, EventSource client
│   │   └── server.lisp      Hunchentoot acceptor, routes, SSE broadcast observer
│   └── frontend/            empty directory
├── tests/
│   ├── package.lisp        :squiggle/tests pkg, suite def, deftest-engine macro
│   ├── mutation-tests.lisp unit tests for apply-*
│   ├── engine-tests.lisp   validator, dispatch, observers, reply parsing, tick!
│   └── web-tests.lisp      render-svg and canvas-page tests
├── corpus/                 gitignored; local text input
├── docs/                   gitignored except docs/reference/
└── .github/workflows/      CI
```

Files marked *(planned)* in the tables below do not exist yet.
Everything else exists today.

## ASDF Systems

| System | Depends On | Purpose |
| --- | --- | --- |
| `:squiggle` | Nothing | Shared vocabulary: constants, structs, canvas helpers |
| `:squiggle/oracle` | `:squiggle` + `dexador`, `com.inuoe.jzon`, `cl-ppcre` | Oracle implementations + random-draw substrate |
| `:squiggle/backend` | `:squiggle`, `:squiggle/oracle` | Engine: state, mutations, dispatch, lifecycle, tick |
| `:squiggle/web` | `:squiggle`, `:squiggle/backend` + `hunchentoot`, `cl-who`, `flexi-streams`, `bordeaux-threads` | SVG emitter, pages, SSE server |
| `:squiggle/tests` | `:squiggle`, `:squiggle/oracle`, `:squiggle/backend`, `:squiggle/web` + `fiveam` | Test suite |

## Packages

- **`:squiggle`**: constants (`+palette+`, `+canvas-w+`, `+canvas-h+`, `+entity-types+`, `+min-scale+`, `+max-scale+`), `entity`, `canvas`, and `oracle-result` defstructs (every slot read-only) and their accessors, the copiers `entity-with` and `canvas-with`, `entities`, `find-entity`.
- **`:squiggle/oracle`**: `*oracle*` defvar, the `propose` generic, the `fake-oracle` and `llm-oracle` structs and their constructors, `generate-mutation`, `random-elt`, `random-id`, `random-delta`, `use-fake-oracle!`, `use-llm-oracle!`, `load-passages!`, `next-passage!`.
- **`:squiggle/backend`**: `*rngs*`, `rngs-oracle`, `rngs-jitter`, `seed-rngs!`, `*state*`, `*tick-observers*`, the `observe-tick` generic, `boot!`, `reset!`, `make-seed-canvas`, `stamp-layers`, `apply-mutation`, `apply-mutations`, `update-entity`, all `apply-*` verbs, `validate-mutation`, `validate-mutations`, `tick!`, `demo`. (`*last-mood*` is defined but not exported.)
- **`:squiggle/web`**: `render-svg`, `canvas-page`, `about-page`, `start-server!`, `stop-server!`. Uses `cl-who`; imports `*state*`, `*tick-observers*` and `observe-tick` from `:squiggle/backend`.
- **`:squiggle/tests`**: test package; imports the packages above plus `fiveam`.
- **`:squiggle.aesthetic`**: deferred (post-v1).

## Module Responsibilities

| File | Owns |
| --- | --- |
| `src/package.lisp` | The base `:squiggle` `defpackage` + exports (shared vocabulary). Subsystem packages live beside their code; see the two rows below. |
| `src/oracle/package.lisp` | `:squiggle/oracle` `defpackage` + exports, with the `(:jzon …)` / `(:ppcre …)` local nicknames. First component of `:squiggle/oracle` so the nicknames resolve against that system's deps. |
| `src/backend/package.lisp` | `:squiggle/backend` `defpackage` + exports. |
| `src/types.lisp` | Palette + canvas/scale/type constants. `entity`, `canvas`, and `oracle-result` `defstruct` definitions, every slot `:read-only`. `entity-with` and `canvas-with` build changed copies. `entities` and `find-entity` accessors. (`oracle-result` = `{mutations, mood}`, the shared oracle→engine return contract; it lives here because both oracles produce it and `tick!` consumes it.) |
| `src/oracle/oracle.lisp` | The `fake-oracle` struct and the `llm-oracle` struct (read-only `url` and `model`). `*oracle*` defvar, holding a `fake-oracle` instance by default. The `propose (oracle canvas rng)` generic, which returns an `oracle-result`. `use-llm-oracle!` / `use-fake-oracle!` swap the instance in `*oracle*` at runtime. `random-elt`, `random-id`, `random-delta`: shared random-draw helpers used by both oracle impls. |
| `src/oracle/fake-oracle.lisp` | `+fake-verbs+` and `generate-mutation (verb canvas rng)`, an `ecase` with one branch per verb. The `propose` method on `fake-oracle` returns an `oracle-result` with one mutation and a random mood 1–10, both drawn from the oracle stream. One mutation per call mirrors the LLM oracle, so swapping oracles doesn't change per-tick density. |
| `src/oracle/llm-oracle.lisp` | The `propose` method on `llm-oracle` returns an `oracle-result`. Its `handler-case` falls back to the fake oracle on any error, and `proposal-from-reply` falls back when the mood or the mutation is `:none`. `*prompt-template*` defparameter; `build-prompt`; `json-object` helper; `call-ollama (llm-oracle prompt)` (dexador→Ollama, jzon decode). Pure scanners: `scan-mood` (ppcre `MOOD=(\d+)`, an integer or `:none`), `scan-keywords`, `scan-numbers`. `parse-response (text)` → internal `parsed` struct. `assemble-mutation (parsed canvas rng)` returns one mutation or `:none` (priority add > recolor > nudge). The `parsed` struct (Qwen token bags) is defined here and never leaves this file. |
| `src/backend/backend.lisp` | Globals at the top. The `rngs` struct (read-only `oracle` and `jitter` streams), held in `*rngs*` and unbound until `boot!` or `seed-rngs!`. `*state*` defvar. `*tick-observers*`, observer instances that `tick!` hands to the `observe-tick` generic after each commit (the web layer's `server` is one). `*last-mood*` (mood of the latest `oracle-result`, written by `tick!`, read by nothing yet). `seed-rngs!`, `entropy-seed`, `make-rng`. `update-entity`, which signals on a missing id. `stamp-layers` (rewrites `:add` mutations with a `:layer` drawn from the jitter stream). `apply-mutation` dispatch (an `ecase`), `apply-mutations` reducer. Pattern jitter: `jitter-mutations`, `make-nudge`, `make-recolor`, `random-signed`, `+jitter-nudge-prob+` / `+jitter-recolor-prob+` / `+jitter-magnitude+`. `boot!`, `reset!`, `make-seed-canvas` lifecycle. `observe-tick` generic, `notify-observers`, `tick!` loop. |
| `src/backend/mutation.lisp` | One function per verb: `apply-nudge`, `apply-recolor`, `apply-resize`, `apply-add`, `apply-remove`. Pure: canvas in, new canvas out, built with `entity-with` and `canvas-with`. Validation is the validator's job. |
| `src/backend/inspect.lisp` | `print-entity`, `print-state`, `print-tick`. `demo` loads the seed canvas and runs N ticks with output. REPL convenience only; not called by the engine. Ticks with `*oracle*`. |
| `src/backend/validator.lisp` | `validate-mutation (canvas mutation)` returns the mutation or `:rejected`, and `validate-mutations (canvas mutations)` keeps the survivors. A proposal is dropped only for invalidity: unknown verb, wrong arity, off-palette color, off-vocabulary type, non-numeric argument, or an id not on the canvas. `:add` coordinates are clamped to canvas bounds rather than rejected. Never aesthetic. `tick!` calls `validate-mutations` on the oracle-result's mutations before stamping layers. |
| `src/oracle/corpus.lisp` | The `corpus` struct (read-only `passages` vector; mutable `index`), held in `*corpus*`. `load-passages!` reads `corpus/passages.txt` into a fresh corpus and returns `:loaded`; `next-passage!` returns the current passage and advances the index, wrapping at the end. The index is not yet persisted to disk. |
| `src/backend/tempo.lisp` *(stub)* | Mood→rate lookup (`tick-interval`, re-derived on a ~5-tick cadence from `*last-mood*`; no separate Qwen query, since mood rides in each `oracle-result`), mood ring buffer, low-variance → corpus jump. |
| `loop.lisp` *(planned)* | Thin wrapper: calls `(tick! *oracle*)` on a timer derived from current mood. The only place that runs forever. |
| `src/web/package.lisp` | `:squiggle/web` `defpackage` + exports. |
| `src/web/svg.lisp` | `render-svg`: pure `canvas → svg-string`, painted back to front by `paint-order` (layer ascending, ties by id). `entity-rect` draws each entity as a placeholder square sized by `+base-size+` and scale, filled from `+palette-hex+` (`fill-hex` signals on an off-palette color), until per-shape treatment is settled. |
| `src/web/page.lisp` | `canvas-page (svg)` and `about-page`: pure functions returning HTML. The canvas page carries `+page-css+` (the fade-in) and `+page-js+` (the `EventSource` client that keeps the newest two frames). |
| `src/web/server.lisp` | `squiggle-acceptor` dispatching `/`, `/about`, `/events`. The `server` struct (read-only `acceptor` and `lock`; mutable `viewers` and `frame`) is held in `*server*`, which is `:stopped` when nothing runs. `frame` holds the last committed SVG, so handlers never read `*state*`. The server is its own tick observer: its `observe-tick` method renders once and calls `broadcast-frame!`. `send-to-viewer!` returns `:sent`, `:dropped` or `:unknown` and drops dead streams. `events-stream` sends a keep-alive every `+ping-seconds+`. `start-server!` (`&key port`, default 8080) signals if a server is running and registers the observer; `stop-server!` removes it and returns `:stopped` or `:not-running`. |
| `log.lisp` *(planned)* | SQLite append-only log of applied mutations (post-validator, post-jitter). |
| `debug-page.lisp` *(planned)* | `/debug` HTML: sparklines for entity count, mutations/tick, mood timeline, corpus pointer. |
| `tests/` | Today: two unit tests in `mutation-tests.lisp`; validator, dispatch, LLM reply parsing, observer and fake-oracle `tick!` tests in `engine-tests.lisp`; seven `render-svg` and `canvas-page` tests in `web-tests.lisp`. Planned: property tests on the pure mutation layer and mock-Qwen adversarial tests. Fake oracle only. |

## State Shape

```lisp
;; canvas struct, every slot read-only  (make-canvas / canvas-with)
(canvas-next-id  canvas)   ; integer: monotonically assigned by apply-add; oracle never picks ids
(canvas-entities canvas)   ; list of entity structs, ordered by insertion

;; entity struct, every slot read-only  (make-entity / entity-with)
(entity-id    entity)   ; integer
(entity-type  entity)   ; keyword: member of +entity-types+
(entity-pos   entity)   ; (x y) list
(entity-scale entity)   ; float
(entity-color entity)   ; keyword: member of +palette+
(entity-layer entity)   ; integer: assigned at add time by stamp-layers; entity-with cannot change it

;; oracle-result struct, every slot read-only  (make-oracle-result)
(oracle-result-mutations oracle-result)   ; list of raw mutation s-exprs (validated later, in tick!)
(oracle-result-mood      oracle-result)   ; integer 1–10
```

Every oracle returns an `oracle-result`.
The `parsed` struct (Qwen's scanned token bags: mood + colors/shapes/numbers) is an llm-oracle implementation detail and does **not** appear here; it's consumed by `assemble-mutation` before the `llm-oracle` method returns.

`*state*` is the single live composition, rebound (never mutated in place) each tick.

Layer render contract: sort entities ascending by `:layer`; tiebreak by `:id`.
Higher layer paints on top.

## Mutation Verbs

| Verb | Args | Effect |
| --- | --- | --- |
| `:nudge`   | `id dx dy`           | Shift position |
| `:recolor` | `id color`           | Set color |
| `:resize`  | `id factor`          | Multiply scale |
| `:add`     | `type x y color layer` | Append new entity, assign id |
| `:remove`  | `id`                 | Drop entity |

The validator rejects unknown verbs, so `apply-mutation` is an `ecase` and signals on one.

`:layer` in `:add` is injected by `stamp-layers` (called in `tick!`); oracles never set it.

## Tick Lifecycle

```
tick! [oracle]                          oracle is a mandatory arg
  └─ boot!                              seed *rngs* from entropy if not yet seeded
  └─ (propose oracle *state* oracle-rng) → oracle-result {mutations, mood}
  └─ validate-mutations                 keep only valid (clamped) proposals
  └─ stamp-layers [jitter rng]          → rewrites :add entries with a positional :layer value
  └─ setf *last-mood* ← oracle-result-mood   recorded for the future scheduler
  └─ apply-mutations → setf *state*     → reduce apply-mutation over the stamped list
  └─ jitter-mutations [jitter rng]      → sub-perceptual nudge/recolor, applied
  └─ notify-observers                   (observe-tick observer *state* mutations) for each
  └─ return applied mutations

Planned additions:
  step-heal guard on entity count after apply-mutations
  mood→rate lookup filled in and added to the build (tempo.lisp)
  mood-driven scheduler wrapping tick!
```

`tick!` takes the oracle as a **mandatory argument**; it does not read `*oracle*` itself.
`*oracle*` remains the configured default: a `fake-oracle` instance on load, swapped at runtime by `use-llm-oracle!` / `use-fake-oracle!`.
The prod loop and the REPL pass it in as `(tick! *oracle*)`; tests pass an oracle directly, e.g. `(tick! (make-fake-oracle))`.

`tick!` consumes the `oracle-result` contract end to end: it validates `oracle-result-mutations`, stamps positional layers, records `oracle-result-mood` in `*last-mood*`, applies the survivors, and runs the jitter heartbeat.
What is not yet built is downstream: `step-heal`, the mood-to-rate lookup and the scheduler that reads `*last-mood*` (with `tempo.lisp` still a stub outside the build), and the corpus wiring that keeps `llm-oracle` from silently falling back to the fake oracle.

## External Dependencies

ASDF `:depends-on` (current):

- `fiveam`: test framework (`:squiggle/tests` only)
- `dexador`: HTTP client for Ollama (`:squiggle/oracle`)
- `com.inuoe.jzon`: JSON encode/decode for Ollama bodies + responses (`:squiggle/oracle`)
- `cl-ppcre`: regex for Qwen response parsing (`:squiggle/oracle`)
- `hunchentoot`: HTTP server (`:squiggle/web`)
- `cl-who`: HTML and SVG generation (`:squiggle/web`)
- `flexi-streams`: UTF-8 stream for each `/events` connection (`:squiggle/web`)
- `bordeaux-threads`: the lock guarding the viewer list (`:squiggle/web`)

All three HTTP/JSON/regex deps are scoped to `:squiggle/oracle` (not core `:squiggle`), so the engine stays dependency-free.
They are referenced via dexador's built-in `dex:` nickname and the `(:jzon :com.inuoe.jzon)` / `(:ppcre :cl-ppcre)` package-local nicknames on the `:squiggle/oracle` `defpackage`.
That `defpackage` lives in `src/oracle/package.lisp` (not the base `src/package.lisp`) precisely so the nicknames resolve against deps the `:squiggle/oracle` system loads, keeping the base `:squiggle` system dependency-free.

System Lisp: SBCL via Quicklisp.

## Build and Run

```lisp
$ sbcl --load ~/quicklisp/setup.lisp
* (push #p"/path/to/squiggle/" asdf:*central-registry*)
* (ql:quickload :squiggle/backend)
* (in-package :squiggle/backend)
* (reset! 42)                         ; required first: an empty canvas crashes the fake oracle
* (tick! squiggle/oracle:*oracle*)    ; one step; returns the applied mutations
* (demo)                              ; or: seed canvas + 20 ticks with printed output
```

Run tests from the REPL with `(asdf:test-system :squiggle/tests)`, which the `.asd` `:perform` maps to `(fiveam:run! :squiggle)`, or from the shell:

```bash
sbcl --non-interactive \
     --load ~/quicklisp/setup.lisp \
     --eval "(push #p\"$(pwd)/\" asdf:*central-registry*)" \
     --eval '(ql:quickload :squiggle/tests)' \
     --eval '(uiop:quit (if (uiop:symbol-call :fiveam :run! :squiggle) 0 1))'
```
