# Architecture

A map of what lives where in the Squiggle source tree, as it stands today.

## Layout

```
squiggle/
├── LICENSE                 BSD-2-Clause
├── squiggle.asd            ASDF system definitions (base + 4 subsystems)
├── scripts/
│   └── preprocess-corpus.lisp  offline: corpus/book.txt → corpus/passages.txt
├── src/
│   ├── package.lisp        :squiggle base package (shared vocabulary)
│   ├── frozen.lisp         define-frozen-struct: read-only struct + copier  (:squiggle)
│   ├── types.lisp          constants, structs, canvas helpers  (:squiggle)
│   ├── backend/
│   │   ├── package.lisp     :squiggle/backend defpackage
│   │   ├── backend.lisp     RNGs, *state*, dispatch, jitter, lifecycle, tick!
│   │   ├── mutation.lisp    pure mutation verbs (apply-*)
│   │   ├── validator.lisp   validate-mutation/validate-mutations; wired into tick!
│   │   ├── tempo.lisp       mood→tick-rate lookup (stub; the strict build refuses it)
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
│   ├── build-tests.lisp    every .lisp file under src/ and tests/ is a component
│   ├── frozen-tests.lisp   define-frozen-struct's copier and refusals
│   ├── mutation-tests.lisp unit and property tests for the pure layer
│   ├── engine-tests.lisp   validator, dispatch, observers, reply parsing, tick!, garbage oracle
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

Every system is a strict build (`:defsystem-depends-on ("strict-build")`): any warning from compiling or loading squiggle's own files, style-warnings included, fails the operation.
Warnings from libraries only print.
CI clones strict-build beside the checkout.

## Packages

- **`:squiggle`**: `define-frozen-struct`, constants (`+palette+`, `+canvas-w+`, `+canvas-h+`, `+entity-types+`, `+min-scale+`, `+max-scale+`), `entity`, `canvas`, and `oracle-result` structs (every slot read-only) and their accessors, the copiers `entity-with` and `canvas-with`, `entities`, `find-entity`.
- **`:squiggle/oracle`**: `*oracle*` defvar, the `propose` generic, the `fake-oracle` and `llm-oracle` structs and their constructors, `generate-mutation`, `random-elt`, `random-id`, `random-delta`, `use-fake-oracle!`, `use-llm-oracle!`, `load-passages!`, `next-passage!`, `advance-passages!`, the `corpus-not-loaded` condition.
- **`:squiggle/backend`**: `*rngs*`, `rngs-oracle`, `rngs-jitter`, `seed-rngs!`, `*state*`, `*tick-observers*`, the `observe-tick` generic, `boot!`, `reset!`, `make-seed-canvas`, `stamp-layers`, `apply-mutation`, `apply-mutations`, `update-entity`, all `apply-*` verbs, `validate-mutation`, `validate-mutations`, `tick!`, `demo`.
  `*last-mood*` is defined but not exported.
- **`:squiggle/web`**: `render-svg`, `canvas-page`, `about-page`, `start-server!`, `stop-server!`.
  Uses `cl-who`; imports `*state*`, `*tick-observers*` and `observe-tick` from `:squiggle/backend`.
- **`:squiggle/tests`**: test package; imports the packages above plus `fiveam`.
- **`:squiggle.aesthetic`**: deferred (post-v1).

## Module Responsibilities

| File | Owns |
| --- | --- |
| `src/package.lisp` | The base `:squiggle` `defpackage` + exports (shared vocabulary). Subsystem packages live beside their code; see the two rows below. |
| `src/oracle/package.lisp` | `:squiggle/oracle` `defpackage` + exports, with the `(:jzon …)` / `(:ppcre …)` local nicknames. First component of `:squiggle/oracle` so the nicknames resolve against that system's deps. |
| `src/backend/package.lisp` | `:squiggle/backend` `defpackage` + exports. |
| `src/frozen.lisp` | `define-frozen-struct (name (&key copier fixed) &body slot-specs)`: one slot list writes a `defstruct` with every slot `:read-only` and a `copier` taking one keyword per slot not in `fixed`. Refuses at expansion a missing copier, a slot spec that isn't `(slot-name default)`, a fixed name that isn't a slot, or every slot fixed. |
| `src/types.lisp` | Palette + canvas/scale/type constants. `entity` and `canvas` via `define-frozen-struct` (`entity-with` cannot change `id`, `type` or `layer`); `oracle-result` as a plain `defstruct`, every slot `:read-only`. `entity-with` and `canvas-with` build changed copies. `entities` and `find-entity` accessors. (`oracle-result` = `{mutations, mood}`, the shared oracle→engine return contract; it lives here because both oracles produce it and `tick!` consumes it.) |
| `src/oracle/oracle.lisp` | The `fake-oracle` struct and the `llm-oracle` struct (read-only `url` and `model`). `*oracle*` defvar, holding a `fake-oracle` instance by default. The `propose (oracle canvas rng)` generic, which returns an `oracle-result`. `use-llm-oracle!` / `use-fake-oracle!` swap the instance in `*oracle*` at runtime. `random-elt`, `random-id`, `random-delta`: shared random-draw helpers used by both oracle impls. |
| `src/oracle/fake-oracle.lisp` | `+fake-verbs+` and `generate-mutation (verb canvas rng)`, an `ecase` with one branch per verb. `fake-verb (canvas rng)` draws a verb from `+fake-verbs+`, or returns `:add` when the canvas is empty, since the other four verbs need an entity to target. The `propose` method on `fake-oracle` returns an `oracle-result` with one mutation and a random mood 1–10, both drawn from the oracle stream. One mutation per call mirrors the LLM oracle, so swapping oracles doesn't change per-tick density. |
| `src/oracle/llm-oracle.lisp` | The `propose` method on `llm-oracle` returns an `oracle-result`. Its `handler-case` falls back to the fake oracle on any error, and `proposal-from-reply` falls back when the mood or the mutation is `:none`. `*prompt-template*`, `+token-punctuation+`, `+reply-max-tokens+` (64, so a runaway reply stops early) and `+reply-timeout-seconds+` (10) defparameters; `build-prompt`; `json-object` helper; `chat-request` and `reply-content`; `call-llama-server (llm-oracle prompt)` (dexador→llama-server's `/v1/chat/completions` with `max_tokens` and an explicit read timeout, jzon decode). Pure scanners: `scan-mood` (ppcre `MOOD=(\d+)`, an integer or `:none`), and `scan-keywords` and `scan-numbers`, which read `reply-tokens` (the reply split on whitespace, each token trimmed of `+token-punctuation+`, so `coral,` and `(340` parse). `parse-response (text)` → internal `parsed` struct. `assemble-mutation (parsed canvas rng)` returns one mutation or `:none` (priority add > recolor > nudge); an `:add`'s two numbers are percentages, scaled onto the canvas by `percent-of`, and a `:nudge`'s are pixels; on an empty canvas the recolor and nudge branches give `:none`, so the fake oracle's `:add` stands in. The `parsed` struct (Qwen token bags) is defined here and never leaves this file. |
| `src/backend/backend.lisp` | Globals at the top. The `rngs` struct (read-only `oracle` and `jitter` streams), held in `*rngs*` and unbound until `boot!` or `seed-rngs!`. `*state*` defvar. `*tick-observers*`, observer instances that `tick!` hands to the `observe-tick` generic after each commit (the web layer's `server` is one). `*last-mood*` (mood of the latest `oracle-result`, written by `tick!`, read by nothing yet). `seed-rngs!`, `entropy-seed`, `make-rng`. `require-entity`, which signals on a missing id, and `update-entity`, which goes through it. `stamp-layers` (appends a layer drawn from the jitter stream to each `:add` as a trailing positional argument). `apply-mutation` dispatch (an `ecase`), `apply-mutations` reducer. Pattern jitter: `jitter-mutations`, `make-nudge`, `make-recolor`, `random-signed`, `+jitter-nudge-prob+` / `+jitter-recolor-prob+` / `+jitter-magnitude+`. `boot!`, `reset!`, `make-seed-canvas` lifecycle. `observe-tick` generic, `notify-observers`, `fallback-mutations` (the fake oracle's mutations, which `tick!` applies when the validator rejects every proposal), `tick!`. |
| `src/backend/mutation.lisp` | One function per verb: `apply-nudge`, `apply-recolor`, `apply-resize`, `apply-add`, `apply-remove`. Pure: canvas in, new canvas out, built with `entity-with` and `canvas-with`. Validation is the validator's job, but every verb that takes an id signals on a missing one. |
| `src/backend/inspect.lisp` | `print-entity`, `print-state`, `print-tick`. `demo` loads the seed canvas and runs N ticks with output. REPL convenience only; not called by the engine. Ticks with `*oracle*`. |
| `src/backend/validator.lisp` | `validate-mutation (canvas mutation)` returns the mutation or `:rejected`, and `validate-mutations (canvas mutations)` keeps the survivors. A proposal is dropped only for invalidity: unknown verb, improper list, wrong arity, off-palette color, off-vocabulary type, non-numeric argument, a resize factor that is not positive, or an id not on the canvas. `:add` coordinates are clamped to canvas bounds rather than rejected. Never aesthetic. `tick!` calls `validate-mutations` on the oracle-result's mutations before stamping layers. |
| `src/oracle/corpus.lisp` | The frozen `corpus` struct (`passages` vector, fixed; `index`), held in `*corpus*` and replaced by a copy whenever the index moves. `load-passages!` reads a passages file into a fresh corpus and returns `:loaded`; its default path is `default-passages-path`, `corpus/passages.txt` resolved against the `:squiggle` system (`asdf:system-relative-pathname`), so it does not depend on the process's working directory. `skip-passages` is the pure move, wrapping at the end through `wrap-index`. `next-passage!` returns the current passage and moves one ahead, and signals `corpus-not-loaded` on an empty corpus. `advance-passages!` jumps N ahead and returns `:advanced` or `:not-loaded`. The index is not yet persisted to disk. |
| `src/backend/tempo.lisp` *(stub)* | Today only `tick-interval` with an empty body; a component of `:squiggle/backend`, which the strict build refuses for the unused `mood` until the tempo guide replaces it. Planned: mood→rate lookup (`tick-interval`, re-derived on a ~5-tick cadence from a ring of recent moods that `tick!` feeds; no separate Qwen query, since mood rides in each `oracle-result`), low-variance → corpus jump. |
| `loop.lisp` *(planned)* | Thin wrapper: calls `(tick! *oracle*)` on a background thread, sleeping the tempo's derived interval between ticks. The only place that runs forever. |
| `src/web/package.lisp` | `:squiggle/web` `defpackage` + exports. |
| `src/web/svg.lisp` | `render-svg`: pure `canvas → svg-string`, painted back to front by `paint-order` (layer ascending, ties by id). `entity-rect` draws each entity as a placeholder square sized by `+base-size+` and scale, filled from `+palette-hex+` (`fill-hex` signals on an off-palette color), until per-shape treatment is settled. |
| `src/web/page.lisp` | `canvas-page (svg)` and `about-page`: pure functions returning HTML. The canvas page carries `+page-css+` (the fade-in) and `+page-js+` (the `EventSource` client that keeps the newest two frames). |
| `src/web/server.lisp` | `squiggle-acceptor` dispatching `/`, `/about`, `/events`. The `server` struct (read-only `acceptor` and `lock`; mutable `viewers` and `frame`) is held in `*server*`, which is `:stopped` when nothing runs. `frame` holds the last committed SVG, so handlers never read `*state*`. The server is its own tick observer: its `observe-tick` method renders once and calls `broadcast-frame!`. `send-to-viewer!` returns `:sent`, `:dropped` or `:unknown` and drops dead streams. `events-stream` sends a keep-alive every `+ping-seconds+`. `start-server!` (`&key port`, default 8080) signals if a server is running and registers the observer; `stop-server!` removes it and returns `:stopped` or `:not-running`. |
| `log.lisp` *(planned)* | SQLite append-only log of applied mutations (post-validator, post-jitter). |
| `debug-page.lisp` *(planned)* | `/debug` HTML: sparklines for entity count, mutations/tick, mood timeline, corpus pointer. |
| `tests/` | `build-tests.lisp`: every `.lisp` file under `src/` and `tests/` is a component of some system in `squiggle.asd`, and the listing found files at all. `frozen-tests.lisp`: `entity-with` swaps only what it's passed, and `define-frozen-struct` refuses bad definitions. `mutation-tests.lisp`: unit tests and fiveam `for-all` property tests on the pure mutation layer. `engine-tests.lisp`: validator, dispatch, LLM reply parsing (punctuation, empty canvas), observer and `tick!` tests, including a tick from an empty canvas, plus a `garbage-oracle` struct whose `propose` method returns only invalid proposals (`+garbage-mutations+`), ticked to check the canvas stays valid and the fake-oracle fallback fires. `web-tests.lisp`: seven `render-svg` and `canvas-page` tests. Never real Qwen. |

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
(oracle-result-mood      oracle-result)   ; integer 1–10 from both oracles; the slot defaults to :none
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
     or fallback-mutations              the fake oracle's, when none survive
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

`tick!` consumes the `oracle-result` contract end to end: it validates `oracle-result-mutations` (falling back to the fake oracle's mutations when every proposal is rejected, while keeping the original oracle's mood), stamps positional layers, records `oracle-result-mood` in `*last-mood*`, applies the survivors, and runs the jitter heartbeat.
What is not yet built is downstream: `step-heal`, the mood-to-rate lookup over the recent moods and the scheduler that sleeps on it (with `tempo.lisp` still a stub outside the build), and the corpus wiring that keeps `llm-oracle` from silently falling back to the fake oracle.

## External Dependencies

ASDF `:depends-on` (current):

- `fiveam`: test framework (`:squiggle/tests` only)
- `dexador`: HTTP client for llama-server (`:squiggle/oracle`)
- `com.inuoe.jzon`: JSON encode/decode for llama-server bodies + responses (`:squiggle/oracle`)
- `cl-ppcre`: regex for Qwen response parsing (`:squiggle/oracle`)
- `hunchentoot`: HTTP server (`:squiggle/web`)
- `cl-who`: HTML and SVG generation (`:squiggle/web`)
- `flexi-streams`: UTF-8 stream for each `/events` connection (`:squiggle/web`)
- `bordeaux-threads`: the lock guarding the viewer list (`:squiggle/web`)

All three HTTP/JSON/regex deps are scoped to `:squiggle/oracle` (not core `:squiggle`), so the base system stays dependency-free; `:squiggle/backend` loads them through its dependency on `:squiggle/oracle`.
They are referenced via dexador's built-in `dex:` nickname and the `(:jzon :com.inuoe.jzon)` / `(:ppcre :cl-ppcre)` package-local nicknames on the `:squiggle/oracle` `defpackage`.
That `defpackage` lives in `src/oracle/package.lisp` (not the base `src/package.lisp`) precisely so the nicknames resolve against deps the `:squiggle/oracle` system loads, keeping the base `:squiggle` system dependency-free.

System Lisp: SBCL via Quicklisp.

## Build and Run

```lisp
$ sbcl --load ~/quicklisp/setup.lisp
* (push #p"/path/to/squiggle/" asdf:*central-registry*)
* (ql:quickload :squiggle/backend)
* (in-package :squiggle/backend)
* (reset! 42)                         ; start from the seed canvas; *state* is empty until then
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
