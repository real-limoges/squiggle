# Build Plan

What to build. Rationale lives in `ROADMAP.md`.

## A. Foundations
- ✅ **A1.** ~~Two seedable PRNGs (`*oracle-rng*`, `*jitter-rng*`) threaded explicitly as last arg through fake-oracle and (later) jitter. SBCL `sb-ext:seed-random-state`. Boot seeds both from entropy; `(seed-rngs! n)` derives both from one master seed for tests. `src/backend/backend.lisp`, `src/oracle/fake-oracle.lisp`.~~
- ✅ **A2.** ~~Convert canvas + entity from plists to `defstruct` (loose slot types). `*state*` initializes to `(make-canvas)` (empty). Add `(reset! &optional seed)` → sets `*state*` to `(make-seed-canvas)`, calls `(seed-rngs! seed)` when seed given. Add `make-seed-canvas` returning a hardcoded REPL-friendly composition; `(demo)` in `inspect.lisp`. Touches: `src/types.lisp`, `src/backend/backend.lisp`, `src/backend/mutation.lisp`, `src/oracle/fake-oracle.lisp`, `src/oracle/llm-oracle.lisp`.~~
- ✅ **A3.** ~~Add immutable `:layer` slot (integer) to entity struct. Layer assigned via `(stamp-layers jitter-rng mutations)` called in `tick!` after the oracle returns and before `apply-mutations` — rewrites each `:add` to carry `:layer (random most-positive-fixnum jitter-rng)`. `apply-mutations` and `apply-add` stay rng-free; `apply-add` just reads `:layer` from args. `make-seed-canvas` uses hardcoded layer constants. Render contract (for G2): sort by layer ascending, tiebreak by id ascending — higher layer paints on top. Touches: `src/types.lisp`, `src/backend/mutation.lisp`.~~
- ✅ **A4.** ~~3-subsystem namespace refactor. Split monolithic `src/squiggle.lisp` into `:squiggle` (shared types/constants, `src/types.lisp`), `:squiggle/oracle` (random utils + oracle impls, `src/oracle/`), `:squiggle/backend` (engine state, mutations, tick, `src/backend/`). Package definitions in `src/package.lisp`. REPL utilities in `src/backend/inspect.lisp`.~~

## Tick sequence

Reference for the engine spine. Sections C, D, E, G, H each add one stage:

1. **Get passage** — `next-passage!` (E1), called internally by `llm-oracle`.
2. **Get mutation** — call the oracle once → `validate-mutations` on the result's `mutations`. The LLM oracle returns one mutation per call (a 1-element list, or `()` on an unusable parse); if nothing survives, fall back to `fake-oracle` for this tick. `tick!` reads the result's `mood` into `*last-mood*` (C2 writes it; the E-series scheduler reads it). No target count — volume comes from the tick loop, not from sampling one response.
3. **Stamp layers** — `stamp-layers` rewrites `:add` mutations with random `:layer` values (A3).
4. **Apply oracle mutations** — `apply-mutations` threads state through the survivors.
5. **Jitter** — `jitter-mutations` generates sub-perceptual `:nudge`/`:recolor` mutations (D1); apply them.
6. **Heal** — `heal!` enforces the 3–12 entity-count band if needed (D2).
7. **Commit zone** — log to SQLite (H1), broadcast SVG via SSE (G4), persist passage pointer (E1). Atomic group.

## B. Test harness
- ✅ **B1.** ~~Plumbing. Install qlot, add `fiveam` to `qlfile`, run `qlot install`. Add `:squiggle/tests` ASDF subsystem to `squiggle.asd`. Wire `(asdf:test-system :squiggle/tests)` via `:perform` calling `(fiveam:run! :squiggle)`. Add `deftest-engine` macro in `tests/package.lisp`. Replace CI smoke step with `(asdf:test-system :squiggle/tests)`. Flat suite.~~
- **B2.** Pure-layer tests (unit + property) on `apply-*`, `reset!`, `make-canvas`, `stamp-layers`. `fiveam:for-all` for properties. Needs: A1, A2, A3, B1.
- **B3.** Adversarial tests with a garbage-oracle mock in `tests/`. Returns intentionally-broken mutations (off-palette, unknown verbs, OOB coords, malformed s-exprs). Exercises validator + retry/fallback. Needs: B1, C2, D2.

## C. Oracle

**Oracle protocol:** an oracle is a function `(state rng)` → an `oracle-result` struct `{mutations, mood}` (struct defined in `types.lisp` — the shared oracle→engine contract). `mutations` is a list of raw candidates (any length, possibly empty), validated outside the oracle in `tick!`; `mood` is an integer 1–10 or `nil`. **Both oracles return this shape** — the fake oracle draws a mood from `*oracle-rng*`, the LLM oracle parses it from Qwen. Mood travels as an explicit return value, never a side-effect global. Validation happens outside the oracle, in `tick!`. Sampling is *across ticks*, not within a single response — each oracle call yields **at most one** mutation; volume accrues over the tick loop, never by drawing N from one response. A 1.5B model can't reliably produce N of anything, so we take what we get and trust the long-run average. Keep all oracle/parser functions flexible; the shape may shift as we learn what Qwen actually produces.

- ✅ **C1.** Implement `src/oracle/llm-oracle.lisp` (replaces stub). ✅ ~~`build-prompt (passage)` assembles the prompt (no canvas state, no count requirement) by `format`-ing a passage into the `*prompt-template*` defparameter;~~ ✅ ~~`call-ollama (prompt)` does `dex:post` to `http://localhost:11434/api/generate` with `stream:false` (body built via a small `json-object` plist→JSON helper), decodes via `jzon`;~~ ✅ ~~`parse-response (text)` is **pure** — scans Qwen's free-form output into a `parsed` struct (no rng); `assemble-mutations (parsed state rng)` turns that struct into mutation s-exprs (rng + canvas enter here); `llm-oracle (state rng)` calls `next-passage!` (E1) → `build-prompt` → `call-ollama` → `parse-response` → `assemble-mutations`, wraps the result in an `oracle-result` with the parsed mood, and `handler-case`-falls back to `fake-oracle` on any error or empty parse.~~ (Full chain landed; not yet compile-verified — adversarial garbage-oracle coverage is B3.) `dexador` + `com.inuoe.jzon` (+ `cl-ppcre`) deps live on `:squiggle/oracle`. Needs: E1.
- **C2.** `src/backend/validator.lisp` + tick oracle stage. ✅ ~~Validator drafted: `valid-color?` (member `+palette+`) / `valid-type?` (member `+entity-types+`) predicates + a `clamp` helper (`valid-verb?` folded into the `case` `otherwise` branch). `validate-mutation` — per-verb `case`: reject off-palette colors / off-vocab types / unknown verbs, clamp `:add` x/y to `[0,+canvas-w+]`/`[0,+canvas-h+]`, `:nudge` deltas pass through. `validate-mutations` — list filter. File wired into `:squiggle/backend`; both `validate-mutation`/`validate-mutations` exported.~~ **Remaining — tick oracle stage:** in `tick!`, call the oracle once, unwrap the `oracle-result` (`setf *last-mood*` — new defvar in `:squiggle/backend` — ← `oracle-result-mood`; run `validate-mutations` on `oracle-result-mutations`); if nothing survives, fall back to `fake-oracle` for this tick; then `stamp-layers`, `apply-mutations`. This unwrap is what un-breaks `tick!`. No target count, no retry loop — one mutation per tick. Needs: C1.
- ✅ **C3.** Oracle toggle fns. `*oracle*` defvar already in `src/oracle/oracle.lisp`. ✅ ~~Add `use-llm-oracle!` / `use-fake-oracle!` toggle fns there.~~ ✅ ~~Make `oracle` a mandatory parameter in `tick!` (drop `&optional`).~~ Prod loop (F1) will call `(tick! *oracle*)`; tests call `(tick! #'fake-oracle)` directly. Needs: C1.
- ✅ **C4.** Prompt design + response parsing in `src/oracle/llm-oracle.lisp`. Qwen is a chaos source, not a designer — canvas state is NOT in the prompt. ✅ ~~Prompt gives Qwen the color vocabulary (`teal coral cream ink mustard`), shape vocabulary (`blob squiggle triangle curve`), a number range (`0-800`), a corpus passage, and asks for a `MOOD=N` prefix (1=slow/heavy/blue, 10=racing/manic/electric) followed by free-association words and numbers. One-shot example included to anchor the 1.5B model on the format.~~ (`*prompt-template*` + full response parsing below landed.)

  Split into a pure parser and an rng-using assembler:
  - ✅ ~~`parse-response (text)` → `parsed` struct, leniently and with **no rng/canvas**: (1) mood — grep `MOOD=(\d+)`, clamp 1–10, `nil` if missing; (2) the raw token bags — `colors`, `shapes`, `numbers` scanned from the free-association words. Never errors on garbage; unknown tokens ignored. Trivially unit-testable (`text → struct`).~~ Implemented as `(defstruct parsed mood colors shapes numbers)` + pure scanners: `scan-mood` (ppcre `MOOD=(\d+)`, clamp), `scan-keywords` (`ppcre:split` → `find-symbol`/`:keyword`, filtered against `+palette+` / `+entity-types+`), `scan-numbers` (`parse-integer :junk-allowed t`). Unit tests still TODO (B2).
  - ✅ ~~`assemble-mutations (parsed state rng)` → mutation s-exprs. This is where the dispatch table lives (e.g. shape + two numbers + a color → `:add`; a color alone → `:recolor` on a random entity; two numbers alone → `:nudge` a random entity) — random targets draw from `rng` (`*oracle-rng*`). Rules get tuned as we see real Qwen output; keep the table easy to swap.~~ Implemented as a `cond`, priority **add > recolor > nudge**: shape + ≥2 numbers → `:add` (missing color falls back to `(random-elt +palette+ rng)`); lone color → `:recolor` a random entity; ≥2 numbers alone → `:nudge` a random entity; else `()`. **Consumption model = random-draw from the bags, one mutation per call** — the separate-bag `parsed` shape discards cross-category token order, so positional/adjacency pairing is *not* an option here. Tunable as we see real Qwen output.

  The `parsed` struct (token bags) is **oracle-internal — defined in `llm-oracle.lisp`, never crosses to the engine.** Only the `oracle-result` `{mutations, mood}` crosses the boundary. Mood reaches E-series via `tick!` reading `oracle-result`'s mood into `*last-mood*` (no parse-time side effect). Sample prompt draft lives in `docs/prompt.md`. Needs: C1, E1.

## D. Self-healing engine
- ✅ **D1.** ~~Pattern jitter heartbeat in `src/backend/backend.lisp`. `random-elt` already in `src/oracle/oracle.lisp`. Add `+jitter-nudge-prob+` and `+jitter-recolor-prob+` constants. `jitter-mutations (state jitter-rng)` iterates entities; each entity has an independent probability of getting a `:nudge` and an independent (lower) probability of getting a `:recolor`. Returns a list of s-exprs using only `*jitter-rng*`. Wire into `tick!` after oracle mutations; `tick!` return value stays oracle mutations only. Needs: A1, A3.~~
- **D2.** `heal! (state oracle)` in `src/backend/backend.lisp`. After `apply-mutations`, if entity count is outside `[3, 12]`, call the oracle, filter for `:add` (under-band) or `:remove` (over-band), apply valid ones, repeat until in-band or retry cap (3, tunable) is hit. Empty/useless responses fall through to `fake-oracle` for that retry. `tick!` calls `heal!` on the post-mutation state and replaces `*state*` with the result. Needs: C2, C3.

## E. Corpus & tempo

**Sampling is sequential, not random.** The book's emotional arc literally conducts the piece's tempo — the whole "secretly conducted by Infinite Jest" premise depends on it. Pointer walks through preprocessed passages in order, wraps at end.

- **E1.** Corpus preprocess + runtime sampler.
  - ✅ ~~Offline script `scripts/preprocess-corpus.lisp`: read `corpus/book.txt`, split on blank lines, filter paragraphs by sentence count (3–20), write survivors one-per-line to `corpus/passages.txt` (gitignored alongside the book).~~
  - ✅ ~~Runtime sampler in `src/oracle/corpus.lisp`: `load-passages!` reads `passages.txt` into the `*passages*` vector at boot; `*passage-idx*` defparameter tracks position; `next-passage!` returns current passage and advances (wrap to 0 at end).~~
  - Pointer persistence: `*passage-idx*` persists to `corpus/pointer` (single integer via `prin1`/`read`), written every tick, read at boot with `:if-does-not-exist nil` fallback to 0. `load-passages!` should seed `*passage-idx*` from the saved pointer rather than resetting to 0.
- **E2.** Mood→tick rate lookup in `src/backend/tempo.lisp`. Pure lookup: integer mood 1–10 → seconds. Starting table (easy to tune):
  ```
  1 → 120s (2 min)      6 → 30s
  2 → 90s               7 → 20s
  3 → 75s               8 → 15s
  4 → 60s               9 → 10s
  5 → 45s              10 → 5s
  ```
  `tick-interval (mood)` returns seconds; prod loop reads `*last-mood*` after each tick and schedules the next via `sleep`. Default mood (no Qwen response yet, or parse fail) → 5 = 45s. Needs: E1, C4.
- **E3.** Mood ring buffer + corpus jump on low variance. `*mood-history*` ring of last 10 moods. After each tick, if the ring is full and variance falls below threshold (tunable, starting guess: variance < 1.0), advance `*passage-idx*` by a chunk (starting guess: 50 paragraphs) and clear the buffer. The "ring full" check skips the variance test during warmup (first 10 ticks after boot or after a jump). The fix is "advance the conductor," never "inject a fake mood." Needs: E1, E2.

## F. Run forever
- **F1.** Autonomous prod loop: `tick!` wrapper driven by mood→rate. `*running*` defvar as a clean-stop flag — loop checks each iteration, exits when nil. `start!` / `stop!` toggle it. Loop runs on a background thread (bordeaux-threads) so the REPL stays usable. Needs: C3, D2, E2.

## G. Rendering & web

**Stack:** Hunchentoot (web server) + cl-who (HTML/SVG generation) + SSE (server push) + ~10 lines vanilla JS (SSE listener + DOM swap). CSS handles all transitions. JS knows nothing about the piece — it just puts what the server sends into the page.

- **G1.** Hunchentoot skeleton. Add `:squiggle/web` ASDF subsystem with `hunchentoot` + `cl-who` deps. Define routes: `GET /` (canvas page), `GET /about` (static), `GET /events` (SSE stream). Start server on boot. `src/web/server.lisp`.
- **G2.** SVG emitter: pure `state → string` in `src/web/svg.lisp`. Renders entities sorted by `:layer` ascending (tiebreak `:id`). Each shape type gets a placeholder `<rect>` for now (per-shape visual treatment is deferred). Needs: A3.
- **G3.** Canvas page (`GET /`). cl-who template: full-bleed canvas area + minimal chrome (title, tick counter). Inline CSS fade transition on the SVG container (`opacity` + CSS `transition`). ~10 lines vanilla JS: open `EventSource` on `/events`, on message swap inner SVG and trigger fade. Needs: G1, G2.
- **G4.** SSE push. `tick!` side-effect: after updating `*state*`, broadcast fresh SVG string to all open `/events` connections. Hunchentoot chunked response, keep-alive. Needs: G1, G2.
- **G5.** About page (`GET /about`). Static cl-who template. Same chrome as canvas page. Needs: G1.

## H. Persistence & observability

**Tick commit is one atomic chunk.** After `apply-mutations` + `heal!`, the engine runs its side effects together: log to DB, broadcast SVG, persist pointer. No partial state — either the tick commits everything or (in the failure mode) we roll back to before. This pairs naturally with G4 (SSE push) and E1 (pointer persistence) — they all live in the same post-apply zone in `tick!`.

**Observer pattern for opt-in side effects.** `tick!` walks a `*tick-observers*` list (defvar in `:squiggle/backend`) at commit time, calling each observer with the post-commit state + applied mutations. G4 registers its broadcast fn on web startup; H1 registers its log fn on DB open. F1 can run bare (no observers registered) — useful for REPL dev and tests. Pointer persistence (E1) is unconditional, not an observer.

- **H1.** Mutation log (SQLite). One row per *tick*, not per mutation — the grain that matches the "tick committed" event. Columns: `tick_id`, `timestamp`, `mood`, `mutations` (s-expr blob). `cl-sqlite` dep. Write happens in `tick!` alongside the SSE broadcast and pointer persist. Append-only; no updates, no deletes.
- **H2.** `/debug` page: sparklines for entity count, mutations/tick, mood timeline, corpus pointer. Needs: H1, G1.

## I. Dev ergonomics
- ✅ **I1.** ~~Pick one CL linter, wire into CI. Using sblint; runs on `squiggle.asd` in CI.~~
- **I2.** CI parity audit: tests + lint + artifact build. Needs: I1, B1, G1. (Deferred until G is done.)

## Deferred (post-v1)
- Per-shape visual treatment.
- `squiggle.aesthetic` package (Memphis-score for boredom/jitter).
- Frame sharing / SVG→PNG export. Needs: H1.
