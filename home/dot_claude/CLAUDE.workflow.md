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

## Documented unknown — quota vs cache-reads

API *billing* discounts cache-reads to `0.1×`. Whether the **subscription weekly quota** counts cache-read tokens at that discount or flat is **not documented** (support docs only say overage bills at "standard API rates"). Don't assert a number. To actually measure: run one warm-cache session and one `DISABLE_PROMPT_CACHING` session doing equivalent work, and diff the `/usage` weekly delta.
