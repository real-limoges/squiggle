# Frontend Guide — Hunchentoot for an Elixir/Phoenix Dev

This is the deep-dive for Squiggle's web layer (build-plan **§G**), written for someone
who knows web work through **Phoenix + LiveView** and is meeting the Common Lisp stack
for the first time. The goal is to hand you the right mental model so the §G phases read
as "oh, that's just X from Phoenix, minus the framework."

The stack is already decided (ROADMAP §2/§3/§9, BUILD-PLAN §G). This doc explains *why*
each piece is what it is, by analogy — it does **not** re-open those decisions, and it's
not a copy-paste implementation. Snippets are illustrative; you write the real thing.

> Locked decisions, for reference: **Hunchentoot** (server) + **cl-who** (HTML/SVG markup)
> + **SSE** (server→browser push) + **~10 lines of vanilla JS** (an `EventSource` listener
> that swaps the SVG). CSS does all the animation. One global canvas; every viewer sees the
> same state. No WebSockets, no JS framework, no per-viewer state.

---

## 1. The mental-model swap (read this first)

| Phoenix / Elixir | Squiggle / CL | Note |
|---|---|---|
| Cowboy | **Hunchentoot** (an *acceptor*) | The HTTP server you start. |
| Endpoint / `mix phx.server` | `(hunchentoot:start (make-instance 'acceptor ...))` | Started from the REPL or `boot!`. |
| Plug pipeline | plain function calls | No middleware DSL. You compose handlers as ordinary functions. |
| Router (`scope`, `get "/"`) | `*dispatch-table*` / `define-easy-handler` | Map a path to a function. That's it. |
| Controller action | a handler function returning a string | No conn-in/conn-out struct threading. |
| EEx / HEEx (`~H`) | **cl-who** (s-expr → HTML) | A macro that compiles to string-building. |
| `assigns` / change tracking | *(none)* | No diffing — there's no LiveView to diff for. |
| **LiveView** | **SSE + full server-rendered SVG swap** | The big one. See §5. |
| Channels / `Phoenix.PubSub` | the tick **observer list** (`*tick-observers*`, §H) | One topic, one global, everyone subscribed. |
| `Endpoint.broadcast(topic, ...)` | write the SVG to every open `/events` stream | Fan-out to all viewers. |
| GenServer holding state | `*state*` — a single special variable | A BEAM process vs. a Lisp global. See §2. |
| Supervision tree | *(deferred — the bordeaux-threads tick loop, §F)* | |
| `iex -S mix` hot reload | the live SBCL image | Redefine a handler, it's live instantly. See §9. |

If you remember one row: **LiveView → SSE + SVG swap**. Everything else is plumbing.

---

## 2. The one conceptual difference that matters: the process model

This is where your Phoenix intuition will actively mislead you, so it goes first.

**Phoenix is per-connection state, isolated and supervised.** Every LiveView mount spins up
its own BEAM process holding its own `assigns`. A thousand viewers = a thousand little state
machines, each crash-isolated, each independently mutable. State lives *at the edge*, next to
the socket.

**Squiggle is the exact opposite, on purpose** (ROADMAP §9): there is **one** global canvas
and every viewer sees the identical state. State lives *in the center* — a single special
variable in `:squiggle/backend`:

```lisp
(defparameter *state* (make-canvas))   ; the whole piece, one global
```

The only "user" is the text corpus driving the oracle; there are no user inputs into the
piece. So there's nothing per-viewer to isolate.

**What this buys you:** one mutation log, one mood timeline, one thing to render. Sharing a
frame is just sharing a timestamp — no "which canvas?" ambiguity. The server is dramatically
simpler than a Phoenix app because 90% of what Phoenix's process model protects you from
(per-user state, input races, session isolation) *doesn't exist here*.

**What you must watch for:** a shared mutable global has no BEAM-style isolation. `tick!`
replaces `*state*` on a background thread while HTTP handlers are reading it. You do **not**
get the actor model's "one message at a time" guarantee for free.

The discipline that makes this safe is simple and it's the same one §G already assumes:

> **Render the SVG string *once*, at tick commit, and broadcast that string.** Connections
> never read `*state*` directly during a tick. They receive a finished, immutable snapshot.

So `*state*` is mutated in exactly one place (the tick), the SVG is rendered from the
post-commit value, and every viewer gets a byte-identical frame. No half-applied canvas ever
reaches a browser. (In Phoenix terms: you're not letting each socket re-read the GenServer —
you compute the payload once and `broadcast` it.)

---

## 3. Hunchentoot basics for a Phoenix dev

**The acceptor is your endpoint.** You make one and start it:

```lisp
(defvar *acceptor*
  (make-instance 'hunchentoot:easy-acceptor :port 8080))

(hunchentoot:start *acceptor*)   ; ≈ mix phx.server
(hunchentoot:stop  *acceptor*)
```

**A handler is just a function that returns a string.** There's no `conn` threaded in and out,
no `|> render(...)` pipeline. The current request/response are dynamic variables you reach for
when you need them:

```lisp
(hunchentoot:*request*)                       ; the inbound request object
(setf (hunchentoot:content-type*) "text/html") ; set a response header
(hunchentoot:header-in* :accept)              ; read a request header
```

**Two ways to route.** The quick one, `define-easy-handler`, bundles route + handler:

```lisp
(hunchentoot:define-easy-handler (about :uri "/about") ()
  (render-about-page))
```

The explicit one pushes a matcher→handler pair onto `*dispatch-table*`:

```lisp
(push (hunchentoot:create-prefix-dispatcher "/about" #'render-about-page)
      hunchentoot:*dispatch-table*)
```

For Squiggle's three known routes (`GET /`, `GET /about`, `GET /events`), prefer **explicit
dispatch** — it keeps the route table in one readable place in `src/web/server.lisp`, closer
to how a Phoenix router gives you one `scope` block to scan. The easy-handler macro scatters
routes across definitions, which is fine for a sprawling app but noise for three endpoints.

**There is no Plug pipeline.** Cross-cutting concerns in Phoenix are plugs you stack; here
they're just function calls you make inside the handler (or a wrapping function). Squiggle
needs almost none of them — no auth, no CSRF, no sessions (the piece is read-only), so the
absence of a pipeline is a feature, not a gap.

---

## 4. cl-who vs. EEx/HEEx

cl-who is the templating layer. Instead of a `~H""" """` sigil with interpolation, you write
**s-expressions that the macro compiles into efficient string output** — conceptually like how
HEEx compiles your template, except there's no change-tracking/diffing because there's no
LiveView consuming a diff.

The canvas page skeleton looks like this (chrome + an SVG container + the tiny SSE client):

```lisp
(defun render-canvas-page ()
  (cl-who:with-html-output-to-string (s nil :prologue t :indent t)
    (:html
     (:head
      (:title "squiggle")
      (:style "#stage{transition:opacity .6s ease} ..."))   ; CSS does the fades
     (:body
      (:h1 "squiggle")
      (:div :id "stage"
            (cl-who:str (render-svg squiggle/backend:*state*))) ; initial paint
      (:script "const es=new EventSource('/events');
                es.onmessage=e=>{document.getElementById('stage').innerHTML=e.data;};")))))
```

Two escaping notes that bite Phoenix devs (HEEx auto-escapes everything):

- `(:p "text")` and the `esc` helper **escape** HTML — safe for user-ish text.
- `(cl-who:str x)` injects `x` **raw, unescaped**. That's exactly what you want for the SVG
  string (it *is* markup), but never wrap untrusted text in `str`. Squiggle has no untrusted
  text on this path, so this is low-risk here — just know the two are different.

The `render-svg` above is the pure `state → string` emitter (§G2, `src/web/svg.lisp`): it
sorts `(squiggle:entities state)` by `:layer` ascending, tiebreaks on `:id`, and emits one
SVG element per entity. v1 uses a placeholder `<rect>` per shape; per-shape Memphis treatment
is deferred (ROADMAP §4).

---

## 5. The realtime layer — SSE, and "why not LiveView"

This is the heart of the frontend, and the place your LiveView reflexes need recalibrating.

**What LiveView does:** the server holds your `assigns`, and on every state change it computes
a **diff**, ships it over a **WebSocket** (a stateful, *bidirectional* channel), and the JS
client morphdom-patches the DOM. It's brilliant for apps where the user clicks things and the
server reacts per-socket.

**What Squiggle does instead:** on every tick the server renders the *whole* SVG to a string
and pushes that string over **SSE** — Server-Sent Events, which is one-way (server→browser),
stateless, and rides a plain long-lived HTTP response. The client swaps `innerHTML` and CSS
handles the transition.

**Why this, and not LiveView?** Because the entire return channel LiveView gives you is dead
weight here. There are no user inputs into the piece (ROADMAP §9) — nothing the browser needs
to *send back*. LiveView's WebSocket, its per-socket process, its diff engine, its `app.js`
client framework: all of that exists to handle interaction Squiggle doesn't have. SSE is the
honest size of the problem — "server has a new frame, here it is." (This also resolves the
ROADMAP §2 "CLOG vs. Parenscript" open question: with a one-way, no-input piece, the lean
static-page path wins; CLOG's reactive WebSocket framework would be all overhead.)

**SSE ↔ Phoenix.PubSub mapping.** If you squint, the broadcast side *is* PubSub with a single
topic that everyone is subscribed to:

| Phoenix.PubSub | Squiggle SSE |
|---|---|
| `subscribe(topic)` on socket join | a browser opens `EventSource('/events')`; server keeps that output stream |
| the set of subscribers to a topic | the list of open `/events` streams |
| `Endpoint.broadcast(topic, msg)` | loop over open streams, write the SVG to each |
| the topic registry | the `*tick-observers*` list (§H) the tick walks at commit |

**The wire format** is dead simple. Each event is `data:` lines terminated by a blank line,
and the response is `text/event-stream`:

```
data: <svg ...>...</svg>

```

(One logical event = your SVG string, but it must contain no bare newlines that would split
it across `data:` records — emit the SVG as a single line, or prefix every line with `data: `.
Single-line is easiest.)

**The handler** sets the content type, then *doesn't return* — it parks, holding the
connection open, and registers its output stream so the tick can write to it:

```lisp
(defun events-handler ()
  (setf (hunchentoot:content-type*) "text/event-stream")
  (let ((stream (hunchentoot:send-headers)))     ; get the raw chunked output stream
    (register-stream! stream)                    ; add to the broadcast set
    ;; keep the connection alive; the tick observer writes frames to STREAM
    ...))
```

**The broadcast side** is the observer the web layer registers on startup (§G4). At tick
commit it formats the already-rendered SVG as one SSE event and writes it to every open
stream, dropping any that have closed:

```lisp
(defun broadcast-frame (svg)
  (dolist (s (open-streams))
    (handler-case
        (progn
          (format s "data: ~A~%~%" svg)   ; one SSE event
          (force-output s))
      (error () (drop-stream! s)))))       ; viewer left — prune it
```

**Gotchas a Phoenix dev won't expect:**

- **Thread-per-connection, not lightweight processes.** Hunchentoot serves each request on a
  worker thread from a pool. An open SSE connection **pins a worker thread for as long as the
  viewer is watching** — it is nothing like a cheap BEAM process. For an art piece with a
  handful of simultaneous viewers this is fine; just know the ceiling is the thread pool size,
  not "two million connections." If viewership ever grows, that's the constraint to revisit
  (raise the pool, or move SSE to a dedicated acceptor).
- **`EventSource` auto-reconnects for free.** If a stream drops (deploy, network blip), the
  browser's `EventSource` retries on its own after a few seconds — so a pruned stream just
  reappears as a fresh connection on the next tick. You don't need LiveView-style reconnect
  logic; the browser primitive already does it.
- **You must `force-output`.** Buffered output means the browser sees nothing until the buffer
  flushes. Flush after every event.

---

## 6. The client (~10 lines of vanilla JS)

Contrast with LiveView's `app.js` + `live_socket` — a real client-side framework that
negotiates a socket, manages reconnection, applies diffs, runs hooks. Squiggle's client is the
opposite extreme, and **that's the point**: the JS knows *nothing* about the piece. It opens a
stream and dumps whatever arrives into a div.

```html
<script>
  const es = new EventSource('/events');
  es.onmessage = (e) => {
    document.getElementById('stage').innerHTML = e.data;  // e.data is the SVG string
  };
</script>
```

That's the whole client. No build step, no npm, no bundler, no framework (and per project
rules, none of those are coming). All the intelligence — what to draw, how shapes look, the
fade timing — lives in the server's SVG + the page's CSS. The browser is a dumb display.

---

## 7. Wiring it into the tick loop

The tick is the *only* writer of `*state*`, and the broadcast is one of its commit-time side
effects. Today `tick!` ends by returning the applied mutations:

```lisp
(defun tick! (oracle)
  (boot!)
  (let* ((raw       (funcall oracle *state* *oracle-rng*))
         (mutations (stamp-layers raw *jitter-rng*)))
    (setf *state* (apply-mutations *state* mutations))
    (setf *state* (apply-mutations *state* (jitter-mutations *state* *jitter-rng*)))
    mutations))
```

§H introduces the **observer pattern**: `tick!` walks a `*tick-observers*` list at commit time,
calling each observer with the post-commit state. The web layer (§G4) registers a broadcast
observer when the server starts; the DB layer (§H1) registers a logging observer when it opens.
The commit is **one atomic chunk** — apply → heal → log → **broadcast** → persist — so either a
tick commits everything or it rolls back; no viewer ever sees a partial frame.

In Phoenix you'd do the same shape from a context/GenServer: run the state transition, then
`Endpoint.broadcast` the result. Same idea — the machinery is a special-variable list of
functions instead of a PubSub registry, and the "process" is a background thread instead of a
GenServer.

> Note: `*tick-observers*` isn't exported from `:squiggle/backend` yet — it lands with §H.
> Until then a bare `tick!` runs with no observers, which is exactly what the REPL and tests
> want (no server, no DB).

---

## 8. Putting it together: the `:squiggle/web` subsystem

§G adds a new ASDF subsystem (it isn't in `squiggle.asd` yet). Orientation map:

```lisp
(asdf:defsystem :squiggle/web
  :depends-on (#:squiggle #:squiggle/backend #:hunchentoot #:cl-who)
  :components ((:file "package")
               (:file "svg"    :depends-on ("package"))   ; G2: state → SVG string
               (:file "server" :depends-on ("package" "svg")))) ; G1/G3/G4/G5
```

Phase map (full detail in BUILD-PLAN §G):

- **G1** — Hunchentoot skeleton: the acceptor + route table (`/`, `/about`, `/events`), start
  on boot. `src/web/server.lisp`.
- **G2** — the pure SVG emitter `state → string`, layer-sorted. `src/web/svg.lisp`.
- **G3** — the canvas page: cl-who template, inline CSS fade on `#stage`, the EventSource JS.
- **G4** — SSE push: register the broadcast observer; chunked keep-alive response per viewer.
- **G5** — the static `/about` page, same chrome.

Keep `svg.lisp` a **pure function of state** — no Hunchentoot, no global reads inside it.
That keeps it testable without a running server (pass it a hand-built canvas and assert on the
string) and is what lets §2's "render once, broadcast the snapshot" discipline hold.

---

## 9. REPL workflow vs. `iex -S mix`

You'll feel at home here — the live SBCL image is `iex -S mix` with the dial turned to 11.

- **Start/stop the server live:** `(hunchentoot:start *acceptor*)` / `(stop ...)` from the REPL.
  No restart, no recompile-the-world.
- **Redefine a handler and it's instantly live.** Edit `render-canvas-page`, recompile that one
  form (in VSCode + Alive: recompile the top-level form), refresh the browser — done. This is
  Phoenix's `recompile`/hot-reload, but finer-grained and without a file watcher: you choose
  the exact form to redefine, and the running acceptor picks it up because handlers are looked
  up by symbol.
- **Hit routes from the REPL** without a browser using the oracle's existing HTTP client
  (`dexador`, already a dep): `(dex:get "http://localhost:8080/")` returns the page as a string
  to inspect.
- **Drive ticks by hand** to watch frames push: with the server up and a browser on `/`, call
  `(squiggle/backend:tick! squiggle/oracle:*oracle*)` and the SVG should swap in the browser.

The mental upgrade from BEAM: you're not reloading *modules*, you're surgically replacing
*individual functions* inside a process that never stopped — including the live server's
handlers and the live tick loop.

---

## 10. Gotchas / cheat-sheet

- **Thread-per-connection, not BEAM processes.** Each open SSE stream pins a Hunchentoot worker
  thread. Fine at art-piece scale; the thread pool is the ceiling, not millions of sockets.
- **`*state*` is a shared mutable global** with no per-process isolation. Mutate it only in the
  tick; render the SVG once at commit and **broadcast the string**, never let handlers re-read
  `*state*` mid-tick.
- **`force-output` after every SSE write**, or buffering hides frames from the browser.
- **Emit the SVG as a single line** (or prefix each line with `data: `) so a newline doesn't
  split one frame across SSE records.
- **cl-who escaping is opt-out, not opt-in** (unlike HEEx): `(:p x)` / `esc` escape, `str`
  injects raw. The SVG goes through `str`; nothing untrusted should.
- **No CSRF / sessions / auth needed** — the piece is read-only, single global, no inputs.
  Don't port Phoenix's security plumbing; there's nothing to protect.
- **Set the content type for SSE** explicitly: `text/event-stream`. The browser won't treat the
  stream as events otherwise.
- **`EventSource` reconnects itself** — no client reconnect logic required.
- **Deps aren't in `squiggle.asd` yet** — `hunchentoot` + `cl-who` land with the `:squiggle/web`
  subsystem in §G1.

### Reference: the data you're rendering

From `src/types.lisp` — what the SVG emitter consumes:

```lisp
(defstruct entity id type pos scale color layer)  ; pos is a (x y) list
(defstruct canvas (next-id 1) (entities '()))
(squiggle:entities state)                          ; → the entity list

+canvas-w+      ; 800   — SVG viewport width
+canvas-h+      ; 500   — SVG viewport height
+palette+       ; (:teal :coral :cream :ink :mustard) — map each keyword → a hex fill
+entity-types+  ; (:blob :squiggle :triangle :curve) — placeholder <rect> per type in v1
```

Render order: sort `entities` by `:layer` ascending, tiebreak by `:id` (the layer render
contract). `:color` → fill, `:scale` → size, `:pos` → `(x y)` placement.
