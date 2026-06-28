# Qwen prompt draft

Working draft of the prompt for `llm-oracle`. Will get tuned once we see real Qwen output.

## Prompt template

```
Read this passage:

---
{PASSAGE}
---

Respond in this format:
"MOOD=N <words and numbers>"

Where:
- N is 1-10. 1 = slow, heavy, blue. 10 = racing, manic, electric.
  Don't default to 5 — use the full range.
- Words come from: teal, coral, cream, ink, mustard,
  blob, squiggle, triangle, curve
- Numbers are integers 0-800

Example: "MOOD=8 coral squiggle 340 teal blob 120 triangle 600 mustard"

Don't explain. Just the score and the words.
```

## Design notes

- **Canvas state is not included.** Qwen is a chaos source, not a designer. The piece is shaped by the engine, not the model.
- **`MOOD=N` prefix.** Solves a parsing problem — without it, the first integer in the response could be a mood score OR a coordinate. The prefix lets us grep it out cleanly with `MOOD=(\d+)`.
- **"Don't default to 5".** LLMs cluster scores around the middle. Worth trying in the prompt; if mood scores still clump, post-process to stretch the distribution.
- **One-shot example.** 1.5B benefits a lot from a concrete format anchor. The example is intentionally chaotic-looking so we don't bias Qwen toward "logical" word combinations.
- **One number range (0-800).** Could split into "x 0-800, y 0-500" but probably more burden than help at 1.5B. Parser sorts it out.
- **No "give me N items".** Sampling happens across ticks, not within a response. Take what we get.

## Parser sketch

Two stages: a pure scan, then an rng-using assembler. (Why split — ROADMAP §7.)

**`parse-response (text)` → `parsed` struct.** Pure, lenient, no rng/canvas. From any response:

1. Mood: grep `MOOD=(\d+)`, clamp to 1–10. Missing → `nil` (caller falls back to `*last-mood*`).
2. Colors: scan for any of the five palette words.
3. Shapes: scan for any of the four entity-type words.
4. Numbers: scan for any integers. (Clamping to canvas bounds is the validator's job, C2 — the scan just collects.)

Unknown tokens are ignored; never errors on garbage. Trivially unit-testable (`text → struct`).

**`assemble-mutations (parsed state rng)` → mutation s-exprs.** Small `cond` dispatch (tune as we see real output), **one mutation per call**, priority `add > recolor > nudge`; random targets/fills draw from `rng`:

- shape + ≥2 numbers → `:add` (missing color → a random palette draw)
- else a color present → `:recolor` on a random entity
- else ≥2 numbers → `:nudge` on a random entity
- else nothing usable → empty list; `llm-oracle` falls through to fake-oracle

`llm-oracle` then wraps the assembled mutations + the parsed mood into the `oracle-result` it returns. The `parsed` struct itself never leaves `llm-oracle.lisp`.
