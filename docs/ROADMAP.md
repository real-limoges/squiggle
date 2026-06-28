# Squiggle Roadmap & Decision Log

## Context

Squiggle is a Common Lisp "living art" engine: an immutable state of shapes (blob, squiggle, triangle, curve) on a fixed palette, mutated each tick by an oracle. The current oracle is a fake RNG. The piece is meant to be **fully autonomous and always-on** — a server ticks the canvas forever and viewers just observe.

This doc captures the major decisions before that vision is real. It is a decision log, not an implementation plan. Sections marked ✅ are settled (with minor follow-ups noted); sections marked ⏳ are still open.

Resolve open sections by editing in place — promote the chosen option to a "Decision:" line and demote the rest to small follow-ups.

---

## 1. Oracle: Qwen 2.5 1.5B integration — ✅ decided

**Transport:** HTTP sidecar (`ollama serve` / `llama-server` on localhost, model: `qwen2.5:1.5b`). Latency doesn't matter; the clean process boundary is worth it. Model runs in-memory on the same box as the Lisp server (see section 5 — cost is effectively zero, so co-location is fine). The existing fake oracle in `src/` is a **first-class peer**, not scaffolding (see section 7) — same interface, different implementation. Its output shape is the contract Qwen has to match, and it serves as both test infrastructure and a runtime safety net when Qwen returns garbage.

**Output handling — rejection sampling, not trust:** the engine treats every mutation Qwen returns as a *proposal*, not a command. Each proposal is validated independently: known verb? valid coords? legal color from the locked palette? Bad proposals are dropped silently, good ones are applied. This means we never need a "model returned garbage" panic mode — partial-batch acceptance is the normal case. If a whole batch is rejected, fall back to the fake oracle for that tick rather than skipping.

**Input — entropy from a runtime corpus:** the prompt is `a random sentence sampled from a corpus` — **no canvas state.** (Superseded an earlier draft that fed Qwen the current entity list. Dropped: Qwen is a chaos source, not a designer — a 1.5B model handed the canvas tries to "fix" it logically, which kills the Memphis clash. The engine shapes the piece; the model only injects entropy. See `docs/prompt.md` design notes.) The sentence injects variety so the model doesn't converge on the same suggestion every tick, and (via section 5's mood mechanism) the corpus's emotional arc conducts the piece's tempo.

**Corpus is a runtime input, never code.** The repo ships *no* book and depends on no specific text. At startup the engine reads from a configured path (e.g. `corpus/book.txt`); the file is gitignored and populated locally by whoever runs the instance. This keeps the project MIT-licensable while leaving each operator free to feed it whatever they legally hold a copy of:
- Public-domain (Project Gutenberg) — safest default for anyone forking.
- Personally-owned copyrighted work used privately on your own server (no redistribution, no public display of the text — only mood scores and shape mutations leave the box). Our hosted instance will, for the lols, use Infinite Jest: extreme mood variation (Hal / Gately / tennis academy / halfway house / Quebecois separatists) makes the rate mechanism genuinely unpredictable, and the joke of "this art piece is secretly conducted by Infinite Jest" pays off whether anyone ever knows or not.

The text never appears in the rendered output — it's input to mood and entropy queries only. No quotation, no display, no market substitution.

*Smaller follow-ups (resolve during implementation, not blocking):* exact prompt template; whether to constrain Qwen to the five existing verbs (`nudge`, `recolor`, `resize`, `add`, `remove`) or also accept proposed new verbs the validator then rejects; default corpus shipped as an example (probably a small Gutenberg text so the engine boots out-of-the-box for new contributors).

---

## 2. Frontend: CL all the way down — ✅ decided

**Decision:** CL-native stack. No JavaScript ecosystem (npm, shadow-cljs, ClojureScript). The piece is observation-only, so the cost of a CL-native UI is low. Server pushes SVG (see section 3) over the wire; browser just paints.

*Smaller follow-up:* CLOG (websocket-driven reactive UI from the server) vs Parenscript with a tiny static page. CLOG is heavier but gives a real framework; Parenscript is leaner if the page is truly just "receive SVG, swap it in." Pick during implementation.

---

## 3. Rendering layer — ✅ decided

**Decision:** SVG. Server emits SVG markup, browser paints it, transitions between ticks are CSS-driven (`opacity`, `transform`) on the SVG elements themselves. Pairs cleanly with the CL-only stack (section 2) and the autonomous-tick model — the server is the only thing that needs to know how to draw.

**Animation plan:** start with the cheap stuff — fade in / fade out / slide on `opacity` and `transform` transitions. No morphing in v1. If the piece feels static once it's live, revisit: shape-morphing is possible in pure CL if every shape uses a consistent bezier control-point count (lerp the control points server-side, stream the in-between path strings), but don't pay that complexity until the simple version proves boring.

*Smaller follow-up:* "download this frame as PNG" for sharing (see section 8, license & sharing) — separate concern from the live render. SVG → PNG is one library call server-side when we get there.

---

## 4. Aesthetic choices: shapes & colors — ✅ mostly decided

**Aesthetic anchor: Memphis Group / 90s Jazz design.** Going all-in on this thematic style — not "inspired by," not "with a Memphis flavor." The piece is a Memphis design that happens to be alive.

**Palette:** locked at `teal, coral, cream, ink, mustard`. Hard constraint — the oracle may not introduce new colors.

**Shape vocabulary:** all four shapes stay (`blob, squiggle, triangle, curve`). Triangle is on a watch-list (feels off next to three organic forms) but not cut.

**Composition rules:**
- **Entity count band: 3–12.** Hard floor and ceiling. Sanity guards in section 10 keep us inside it.
- **Overlap is encouraged, not avoided.** Memphis IS overlapping shapes — squiggles drawn across blobs, dots over triangles. The "no two same-color shapes touching" instinct is wrong for this aesthetic. Drop it. The rejection-sampling principle ("only reject for invalidity, not for off-kilterness") covers this: overlap is the look.
- **Z-order: niceness model.** Each entity is assigned a `z` value at `add` time from a wide range (e.g. -1000 to 1000). Set-and-forget, immutable in v1, no verb mutates it (escape hatch for a future `renice`-style verb if we ever want it). Result: stable but unpredictable layering — a new blob might appear *behind* an existing squiggle, creating that "drawn first, scribbled over" Memphis feel for free, with zero model burden. Pattern jitter (section 10) does **not** touch z — z changes are perceptually huge and would feel glitchy.

### Still open: per-shape visual treatment

The last gap before section 3's rendering work can start. What does a "blob" *actually look like* — filled vs outlined, smooth bezier vs slightly rough/hand-drawn, thick black contour vs no outline? Same call for squiggle (the iconic three-wave squiggle? consistent line weight? brush vs ink?), triangle (sharp corners or slightly rounded? filled or hollow?), curve.

**Do not decide this casually.** Memphis is a real, specific design movement with strong visual conventions. Before picking treatments, look at the actual reference material:

- Ettore Sottsass / Memphis Group furniture and textiles (1981–1987, the real source)
- The Solo "Jazz" disposable cup pattern (the most ubiquitous example)
- Saved By The Bell title cards and Trapper Keeper graphics (the 90s Americanization)
- 1980s–early 90s Nickelodeon branding

Common visual hallmarks to honor: solid flat colors (no gradients, no shading), often-but-not-always thick black outlines, hand-drawn imperfection (not pixel-perfect bezier), high contrast against cream/white grounds, asymmetric placement, repetition with variation. Squiggles in particular have a *specific* shape — three to five regular waves of consistent line weight, not arbitrary wiggly lines.

Pin this down when rendering work in section 3 begins, not before.

---

## 5. Tick scheduling & rate — ✅ partly decided

**Decided:**
- **Reset policy:** yes, the canvas resets. Always to the same initial state (the piece has a "home"). Triggered by some funny/character-ful mechanism — TBD what (a phrase, an event, a time threshold). The point is the reset is *part of the piece*, not a sysadmin thing.
- **Inference cost:** not a meaningful constraint. Qwen 2.5 1.5B is running in-memory under Ollama on our own box; marginal cost per tick is ~zero. This unblocks calling Qwen as often as we want.
- **Drift control:** folded into the rate mechanism below — won't be a separate system.

**Rate mechanism — the book conducts the tempo:**

The variable agitated/settled rate is driven by the *same corpus* that supplies prompt entropy (section 1). Mechanism:

- Every Qwen tick already returns a **mood** alongside its mutations (the `MOOD=N` prefix, section 1, carried in `oracle-result`) — no separate mood call. The scheduler re-derives the tick rate from the recent mood(s) on a cadence (starting estimate: every 5 ticks) so the rate holds steady for a stretch instead of twitching every tick.
- The mood maps to a tick rate. Tense / agitated mood → fast ticks. Calm / melancholy → slow ticks. Joyful → medium-fast. Etc.
- That rate holds until the next re-derivation. The piece's tempo literally rises and falls with the dramatic arc of whatever book we're sampling — Othello, for example, gives us love → suspicion → jealousy → tragedy, all baked into the source material for free.

This collapses three open questions into one mechanism: rate, drift control, and "what makes the piece feel alive" are all the book's job now.

*Smaller follow-ups:*
- Which book. Don't overindex — Othello is a working placeholder; anything with real mood variation works. Avoid anything monotone.
- Constrained mood vocabulary (a fixed set of ~5 moods the engine knows how to map) vs free-text-and-classify. Constrained is simpler.
- Rate re-derivation cadence (every 5 ticks fixed, or does it also vary?). Default to fixed unless there's a reason to make it dynamic. Moods now arrive every tick, so this is about how often we *recompute the rate*, not how often we *ask*.
- Mood → rate mapping table. Easy to tweak once we see it running.

---

## 6. Persistence & history — ✅ decided (conditionally)

**Decision:** SQLite-backed mutation log, *only if it stays simple to shove in*. Hunch was no history at all, but the time-lapse view ("rewind the last 24h") earns its keep. Storage format is s-expressions on disk; JSON produced on demand by a deterministic `sexp→json` function (cheap, called per request, not per write). If SQLite starts to feel like real work, drop it and go ephemeral.

*Smaller follow-ups:* TTL value (24h vs 7d vs forever-with-downsampling) and schema grain (one row per mutation vs one row per tick-batch).

---

## 7. Testing, dev tooling & CI — ✅ decided

### Test strategy

- **Unit tests** for the pure functions. Keep them shallow — basic input → expected output coverage, nothing clever.
- **Property tests** (QuickCheck-style) layered on top of the pure mutation functions to catch what unit tests miss — invariants across random inputs (e.g. "a `nudge` mutation never changes the entity count," "a `recolor` always produces a color in the locked palette").
- **Never call a real Qwen from a test.** Too flaky, too slow, defeats the point of a hermetic test.
- **Do test the engine against a controlled mock Qwen** that returns garbage on demand: malformed JSON, unknown verbs, out-of-range coords, empty responses, valid-but-weird proposals. The engine's bad-input handling is the actual contract worth pinning down.

### The fake oracle is first-class infrastructure

Not "scaffolding to be deleted when Qwen ships." Lives permanently in `src/` alongside the Qwen oracle. Three earned roles:

1. **Test infrastructure.** Every engine-level test that needs an oracle uses the fake one. Deterministic (seedable PRNG, see below), controllable, fast.
2. **REPL dev tool.** SLIME/SLY sessions can iterate on engine logic without spinning up Ollama. When you're poking at the engine, not the model, the fake oracle is the path of least resistance.
3. **Runtime safety net.** When Qwen returns garbage or refuses to comply (e.g. retry exhaustion in entity-count band from section 10), the fake oracle synthesizes a valid mutation so the engine always makes progress. Already referenced in sections 1 and 10.

Both oracles implement the same interface. Engine startup chooses which to use via config. CI runs the suite against the fake oracle.

**The interface is `(state rng) → oracle-result {mutations, mood}`.** Two decisions worth recording:

- **Mood is an explicit return value, not a side-effect global.** A Qwen tick produces two things the system needs — the shape mutations *and* a mood (which conducts tempo, section 5). Rather than have the parser stuff mood into a `*last-mood*` global as a side effect, the oracle hands back both in one struct and `tick!` routes the mood onward. This keeps the engine oracle-agnostic (it never asks "did the LLM run?") and keeps parsing side-effect-free. The fake oracle satisfies the contract by drawing a random mood — cheap, and it means the engine's mood path is exercised even in tests and fallback ticks.
- **Parsing and assembly are split, and only the products cross the boundary.** Inside the LLM oracle, `parse-response` is a pure `text → parsed` scan (mood + raw color/shape/number token bags), and `assemble-mutations` turns those bags into mutation s-exprs (this is where rng picks random targets). The token-bag `parsed` struct is the most LLM-shaped, most-likely-to-churn thing in the system — it exists only because a 1.5B model emits word salad instead of structure — so it stays *inside* the oracle and never reaches the engine. The engine only ever sees finished mutations and a mood integer. Were the bags pushed outward, the fake oracle would have to cosplay a sloppy LLM and the engine would own Qwen-interpretation logic — exactly backwards.

### Reset as a test fixture

The `(squiggle:reset!)` primitive from section 10 (dead-code-in-prod utility) earns its keep in tests: every test that needs a known starting state calls it first. This is what makes tests deterministic and isolated despite a stateful engine. Two reasons reset is tested even though prod never calls it: it has to actually work for tests, and the REPL relies on it.

### PRNG is seedable

Pattern jitter (section 10) and the fake oracle both consume from a PRNG. For tests to be deterministic, the PRNG must be seedable. The engine takes an RNG seed at startup — tests use a fixed seed, prod uses an entropy-seeded one. Same applies to the corpus sampling pointer.

### REPL workflow

Common Lisp is image-based — you can hot-reload functions and inspect state without restarting. The engine is built to be REPL-friendly:

- Tick is a callable function, not just an autonomous loop. Dev sessions: `(tick)`, inspect state, `(tick)`, inspect, `(reset!)`, repeat.
- Avoid hidden global mutable state where reasonable; thread state explicitly so it's inspectable.
- The autonomous loop (prod) is a thin wrapper that just calls `(tick)` on a timer. Same code path as the REPL.

### Library and tooling choices

- **Property-testing lib:** pick the simplest of `check-it` / `cl-quickcheck`. Not worth a real evaluation — first one that works in five minutes wins.
- **Lint & format:** yes — goal is uniform code, not a specific style. Pick one tool (likely `lisp-format` or `cl-indentify`), accept its defaults, enforce in CI. No bikeshedding the rules.
- **CI:** mirrors the deploy path. Whatever the deploy build does (compile, bundle, package), CI runs the same steps on every push — so green CI is real evidence the artifact will deploy. Test run is one stage of that pipeline, not a separate world.

---

## 8. License & sharing — ✅ decided

**License:** MIT. This is a for-the-lols project, not something with a moat.

**Frame sharing:** in scope — viewers can grab a specific moment of the canvas. Depends on section 6 (need at least the mutation log to permalink "the canvas at time T") and section 3's "SVG → PNG is one library call" note.

*Smaller follow-ups:* permalink format (timestamp? mutation index? short hash?), whether shared frames render as SVG or PNG (PNG is friendlier for social embeds; SVG is friendlier for the art-piece purist), and whether there's any metadata on the share (tick number, mood at that moment).

---

## 9. Single canvas — ✅ decided

**Decision:** one global Squiggle that every viewer sees the same state of. No per-viewer instances, no user inputs into the piece. The only "user" is the text corpus (section 1), which is enough to keep the piece evolving without any visitor interaction.

This simplifies almost everything: one server, one state, one mutation log, one mood timeline. Sharing a frame (section 8) is just sharing a timestamp — no "which canvas" ambiguity.

---

## 10. Sanity guarding & observability — ✅ decided

Two related concerns kept getting conflated, so split them: **sanity guarding** is the engine healing itself; **observability** is how a human notices what the engine did.

**Aesthetic anchor:** Memphis / 90s Jazz design. A *broken* Squiggle looks like a stock screensaver or a wallpaper-sample swatch — too clean, too repeating, too dead. A *healthy* Squiggle looks like a designer's actual sketchbook page from 1987 — intentional but loose, things overlap "wrong," colors clash on purpose. Sanity guards exist to prevent failure modes, not to enforce neatness.

### Sanity guards (engine heals itself)

- **Pattern jitter — architectural commitment.** Two mutation sources, always: Qwen plus a continuous low-amplitude PRNG heartbeat. Every tick, regardless of what the model returns, a tiny random nudge or color jitter on a random entity. Sub-perceptual per-tick, but means the canvas is never pixel-locked. This is the "hand-drawn vibration" of real Memphis pieces, and it's also drift insurance — if the piece walks into a corner, jitter slowly walks it back out.
- **Entity-count band.** Target band `[3, 12]`. Below floor → keep asking Qwen for `add` proposals until back in band; cap retries, fall back to the fake oracle if Qwen refuses. Above ceiling → bias next prompts toward `remove`. Catches both collapse and mush.
- **Mood ring buffer.** Last N=10 moods kept in a ring; if variance falls below threshold, jump the corpus pointer forward by a chunk. The book is conducting — if we're stuck, we're in a flat stretch of the book, just advance. Don't fight the mechanism.
- **Lean toward keeping weird.** Rejection sampling validates *invalid* (off-palette, off-canvas, unknown verb), not *off-kilter*. Weird overlaps and color clashes are the look — never reject for taste, only for legality.

### Reset — dead-code utility

The engine does **not** call reset. Combined with pattern jitter, corpus jumps, entity bands, and a corpus the size of Infinite Jest, the piece has no structural reason to ever reset — it just keeps living, accumulating history forever, and the time-lapse becomes a real archive of years of behavior.

But the reset *function* exists, fully implemented and tested. A single call that wipes the canvas back to the initial state. Two reasons it earns its keep as dead code:
1. **REPL debugging.** Calling `(squiggle:reset!)` from SLIME during development is genuinely useful.
2. **Future-proofing.** If we ever decide to add reset as a *narrative* gesture (midnight wipe, chapter-break wipe, whatever), the primitive is proven and ready to wire up.

### Deferred: aesthetic scoring (fuzzy memphis-score)

Boredom and "the canvas looks off" don't have crisp detectors — Memphis aesthetics are inherently vague, and that's the right kind of vagueness to model with fuzzy sets rather than to crisp-ify. Defer to a separate Common Lisp package (e.g. `squiggle.aesthetic`) added in a later phase.

Planned design: decompose "good Memphis-ness" into 4–6 fuzzy sets with membership functions in [0,1] — color clash (high pairwise color variance), overlap density (sweet-spot curve, not monotonic), asymmetry (off-center mass), shape-type diversity (Shannon entropy across the four types), size variance, z-spread. Aggregate (weighted average to start, possibly fuzzy AND later) into a single `memphis_score(canvas) ∈ [0,1]` per tick. Cheap to compute.

Use as **soft pressure, not a controller**:
- Boredom trigger: `memphis_score` below threshold for a sustained window → turn up pattern-jitter amplitude and jump the corpus pointer (reuses existing mechanisms).
- Jitter gradient: bias jitter direction toward whichever fuzzy set is currently weakest (e.g. low `μ_clash` → jitter preferentially recolors).
- Not used as a mutation veto. Rejection sampling stays validity-only (section 1); aesthetic scoring informs, never blocks.

Fuzzy is the right tool here precisely because it doesn't claim to be truth — it models vagueness directly, so "pretty good" output is correctly-typed for the domain. Eyeball validation via the time-lapse stays the ultimate signal; the score is a useful pressure, not a judge.

Not blocking v1.

### Observability (Tier 1 only for v1)

- **`/debug` page on the web server** with sparklines for: entity count, mutations proposed vs accepted, ticks/min, time-since-event, verb breakdown, mood timeline, corpus pointer position. All cheap counters. Catches every structural failure on the sanity-guard list above.
- **Time-lapse from section 6** is the aesthetic observability. Scrub the day at 30x; "screensaver stretch from 2pm–4pm" reveals itself in seconds. No metric for "looks like a screensaver" — eyeball it.
- Heavier instrumentation (per-tick prompt/response capture, mood label histograms over long windows) deferred until we have an actual "why is Qwen doing this" debugging moment that needs it.
