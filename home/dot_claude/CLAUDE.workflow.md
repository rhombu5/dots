# Workflow & orchestration — cache economy and fan-out cost

How to run efficiently when a session is subagent-heavy, long-lived, or high-context. Loaded before dispatching a `Workflow` / parallel fan-out, or before switching model or effort mid-session — the moments that move token/cache cost most.

## The cache is a growing prefix, billed per turn

Anthropic prompt caching is **prefix-based**. Claude Code maintains three cache layers, ordered by how often they change:

1. **System prompt + tools** — busts on model switch, effort change, tool-set change, MCP connect/disconnect, CC upgrade.
2. **Project context** (CLAUDE.md, memory) — busts on `/clear` or `/compact`.
3. **Conversation** — appended every turn; the prior prefix is reused.

**Per-turn accounting** (multipliers vs base input): cache-read `0.1×`, cache-write `1.25×` (5-min TTL) or `2×` (1-h TTL), fresh input `1×`, output `~5×`. Each turn:

- The **entire transcript so far** (system + context + all prior turns) is re-read at **`0.1×`** — cheap per token, but applied to an **ever-growing base**. This is the compounding cost: by turn 50 of a 150k-token session you re-read ~150k at 0.1× *every turn*. Long 8h / high-context sessions are expensive for this reason — not because any single turn is pricey, but because the whole growing history is re-read on every one.
- The **new delta** since the last breakpoint — your message **plus** the previous assistant turn **plus** any tool results (file reads, subagent returns) — is written at **`1.25×`**. A turn with big tool output writes a big delta; it isn't just your typed text.
- Output (including thinking) bills separately at **`~5×`** and becomes cached history for the next turn.
- **TTL matters.** Past the 5-min window with no activity, the next turn re-pays the whole prefix **fresh (`1×`)** + rewrite (`1.25×`), not `0.1×`. Idle gaps (lunch, a context-switch) are silently expensive.

## Cache-hygiene levers (biggest first)

- **Don't switch model or effort mid-task.** Each flip busts layer 1 and re-pays the system-prompt prefix fresh. The most common silent cache-buster.
- **Keep a live session moving; don't idle past ~5 min** mid-conversation, or the warm prefix expires and the next turn re-reads everything at `1×`.
- **`/compact` at task boundaries, not mid-work** — it rebuilds layers 2–3. Corollary: CLAUDE.md edits don't take effect until `/clear` or restart anyway, so never compact just to pick up a prefs change.
- **`/rewind`, not `/compact`, to abandon a dead path** — rewind returns to an already-cached prefix; compact writes a new one.
- **Keep MCP servers stable** — connect/disconnect busts layer 1. Deferred / tool-search tools don't (they load lazily), which is why the fnclaude and chrome tools are deferred.
- **Batch related work in one session** rather than resuming repeatedly from cold.

## Fan-out cost structure

Each parallel subagent is a fresh window paying its own **base context** (system prompt + tools + any shared briefing). For N same-domain agents:

- **Input**: base context is duplicated N× in token *count*. With caching it collapses toward **~2× on cost** — *if* the shared prefix is genuinely identical **and warm**: the first agent writes the cache (`1.25×`), the rest read it (`0.1×`). Two failure modes kill the discount: (a) per-agent briefings that **diverge early** — only the common prefix caches; and (b) a **cold simultaneous burst** where agents 2..N start before agent 1's write lands, so they all pay fresh/write. The cross-agent discount is reliable only when the prefix is *already* warm (e.g. the static system prompt).
- **Output/thinking is conserved only if the work partitions cleanly.** Same-domain slices tend to **re-derive shared facts** — that's duplicated *thinking* (output, the `5×` kind), not just duplicated input. The parent also pays synthesis output reading N returns. Same-domain fan-out is the case most likely to leak conserved-thinking into duplicated-thinking.

**So fan-out saves tokens only when each unit is genuinely self-contained and returns small.** If subagents run hot and hand back fat payloads, you pay for the fleet *and* the context — the worst case, and the shape a quota-heavy week usually shows.

## Structuring subagent prompts

- **Front-load everything shared; diverge into per-agent slices late.** The identical prefix is the only part that caches across agents.
- **Tight scope + terse return** on every subagent, so the fan-out actually offloads context instead of relocating a big window and paying to synthesize it back.
- **Right-size the model** (prose → sonnet, mechanical → haiku) so the duplicated base context is paid at the cheaper tier.
- **Tier every `agent()` call on both dials — `model` *and* `effort`.** Set them per stage: cheap `model`/`effort: low` on the rote fan-out stages (transform, scan, mechanical migrate), opus/`high`/`max` only on the few genuinely hard stages (verify, judge, design). Omitting `model` inherits the session model (usually opus) — so an unset `model` on a large fan-out silently pays opus × N; set it explicitly to the cheapest tier that clears the bar. Same right-sizing as a hand-dispatched subagent ([`CLAUDE.md`](CLAUDE.md) § "Subagent model selection"), applied inside the script.

## The design-debate pattern — default for brainstorm/design work

The brainstorm/design instantiation of the standing ultracode default
([`CLAUDE.md`](CLAUDE.md) § "Default to ultracode for non-trivial coding tasks"). **Trigger:** a
brainstorm, design exploration, architecture decision, or competing-approaches question
("adversarial brainstorm", "how should we architect X") — default to this `Workflow` shape rather
than answering inline. Established 2026-07-16 (the transforms-plugin-architecture run in
std@fnioc).

Five stages, tiered per-stage on **both** model and effort — never all-fable:

- **1. Research** (sonnet/high, parallel — one agent per evidence domain: primary sources, local
  code spelunking, web prior art). Front-load the shared `CONTEXT` block across every prompt (the
  cache rule above). Each agent writes a browsable file **and** returns full markdown — the return
  is the real channel, since downstream stages embed it verbatim; the file is convenience only.
  RUN SILENT.
- **2. Frame** (fable/high, structured output `{angles: [{key, stance}], dropped: []}`). Reads all
  research and defines the proposal slate: 2–4 maximally-DISTINCT, evidence-grounded stances that
  disagree on core mechanism, each a self-contained marching order. Pre-research guesses pass
  through only as seed candidates to keep/rework/drop, drops recorded with reasons. **Never
  pre-commit the slate before research lands** — the load-bearing insight; a hardcoded slate wastes
  proposers on evidence-dead angles and misses angles research surfaces. No slate back → abort the
  workflow.
- **3. Propose** (opus/high, one agent per stance, parallel via `pipeline()`). Full design per
  stance, grounded in the research, stating what evidence would falsify it.
- **4. Debate** (iterated per proposal, attack vs. rebut, both structured output, tiered by round —
  opus/high for rounds 1–2, fable/high for rounds 3–4). Attack round 1 is comprehensive: HOLDS/BREAKS/NEEDS-VERIFICATION verdicts, one-line
  evidence each, every point tagged NEW or CARRYOVER. Rebuttal answers each open point with exactly
  one of DEFEND (citation required), AMEND (concrete, buildable revision), or CONCEDE, then reports
  a debate-level `verdict`: `stands` (continues), `stands-amended` (continues, attacks now target
  the amendments), `dominated` (still repairable within the stance, but the designer no longer
  believes it should win — ends the debate; the judge inherits the designer's stated reasons and
  weighs the proposal accordingly), or `dead` (an unrepairable kill-shot holds — eliminated). This
  replaced a flat `conceded` boolean (revised 2026-07-17, evidence from five completed debates):
  point-level concessions front-load into round 1, while later rounds attack the amendments
  themselves (drawing DEFEND/AMEND, not fresh CONCEDEs); wholesale concession never fired at all —
  "repairable within stance" is nearly always true — so `dominated` was the real state recurring
  unexpressed (one designer argued against its own design four rounds running without ever
  conceding). Later attack rounds raise only new-or-unresolved points (repeating a conceded or
  evidence-defended point with no new evidence is forbidden). **Convergence**: the debate ends two
  rounds after the last AMEND — a rebuttal with no AMEND (DEFEND/CONCEDE only) forces the next
  attack round to bring genuinely new evidence or declare `settled: true`; re-litigating a resolved
  point is forbidden. Hard cap stays ~4 rounds: evidence shows round 4 earns its cost only while
  amendments keep creating fresh attack surface (a round-3 amendment produced a genuine round-4
  contradiction in one debate; a four-round falsification streak was itself the eliminating
  evidence in another), and late rounds are cheap (attack sizes shrink ~3× by round 4). The cap
  doesn't fix wrong EARLY settlement, though — one debate settled at round 3 on a blind spot both
  sides shared, caught only by cross-debate evidence — which is why parallel debates plus a
  verifying judge stay part of the pattern. Status travels with the transcript as SETTLED /
  DOMINATED / DEAD / UNSETTLED-at-cap.
- **5. Synthesize** (fable/xhigh, one agent). Scores surviving designs on stated axes in their
  final AMENDED form, not the original pitch; a dead proposal is eliminated but its transcript
  gets mined for salvageable ideas, a dominated one is retained but weighted by the designer's
  stated reasons; UNSETTLED points get adjudicated on the evidence; citation-less DEFENDs are
  penalized. Output: a recommendation, a migration/verification checklist ordered
  cheapest-to-falsify first, and OPEN QUESTIONS that genuinely need my call.

**Mechanics**: `pipeline()` across stances — debates serialize within a stance, run parallel across
stances. The workflow returns only the synthesis plus a file index; full research/proposals stay
out of the parent context (`journal.jsonl` is the durable copy of every agent return, scratchpad
files are `/tmp` and don't survive reboot).

**Tiering** (revised 2026-07-17, supersedes the 2026-07-16 all-fable rebut flip): attack and rebut
split by round — opus/high for rounds 1–2, fable/high for rounds 3–4. Early rounds harvest blind
spots, where verified evidence does the work; late rounds argue against deliberately-amended
designs, where the subtler reasoning earns its cost. Frame and judge stay fable; propose stays
opus; research stays sonnet. Never all-fable.

**Scale to the decision's weight.** The full five-stage shape is for consequential/architectural
calls. For a smaller design question, shrink it — 2 stances, a single debate round, or collapse
straight to a plain judge panel — rather than skip the pattern outright. If even the shrunk shape
feels disproportionate, say so and propose the lighter version before firing.

**Spikes are written as future deliverable code** (owner rule, 2026-07-17). A feasibility spike
called for by a checklist or debate goes into the real package/module layout under
production-shaped names, its probes as actual unit tests, committed conventionally on the work's
branch/worktree — never throwaway scratch. A pass is banked foundation the implementer inherits
and extends; a fail costs the same either way it was written. Exception, to justify not default:
probes that genuinely can't live in deliverable shape (a one-off environment check) stay scratch.

## Documented unknown — quota vs cache-reads

API *billing* discounts cache-reads to `0.1×`. Whether the **subscription weekly quota** counts cache-read tokens at that discount or flat is **not documented** (support docs only say overage bills at "standard API rates"). Don't assert a number. To actually measure: run one warm-cache session and one `DISABLE_PROMPT_CACHING` session doing equivalent work, and diff the `/usage` weekly delta.
