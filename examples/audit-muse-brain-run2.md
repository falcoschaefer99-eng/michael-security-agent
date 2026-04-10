# Example Audit: MUSE Brain v1.5.0 — Run 2 (Post-Fix, Enriched Identity)

**Michael's second audit of the same codebase, after all 14 Run 1 findings were fixed and Michael's identity reasoning was enriched.**

This is the A/B benchmark comparison run. Run 1 identified 14 findings (3 HIGH, 6 MEDIUM, 3 LOW, 2 INFO). All fixes were applied and committed. Michael was then enriched with deeper identity integration (compound-clearing metaphor, failure mode guardrails, voice/personality section). This run tests both: do the fixes hold, and does enriched reasoning produce better analysis?

---

## Review: Michael -- Security
**Files reviewed:** All 36 source files in `src/`, plus `wrangler.jsonc`, `package.json`, `.gitignore`
**Mode:** Deep Review (Mode 2) — Benchmark Run 2 (post-fix verification + new discovery)
**Verdict:** PASS WITH NOTES

---

## 1. Verification of Prior Fixes

### Fix 1: Auth query param fallback removed (index.ts)
**STATUS: VERIFIED HOLDING**

Auth is now Bearer header only. The `providedKey` is extracted exclusively from `authHeader?.startsWith("Bearer ") ? authHeader.slice(7) : ""`. No query string fallback exists anywhere in the codebase. The comment documents why: "Query param auth removed — keys in URLs leak to analytics, browser history, proxy logs."

STRIDE: Spoofing vector eliminated. OWASP A02 (Cryptographic Failures — credential exposure) remediated.

### Fix 2: Content-Length pre-flight added (index.ts)
**STATUS: VERIFIED HOLDING**

Pre-flight check on `Content-Length` header before `request.arrayBuffer()`. Rejects payloads claiming > 1MB before buffering. Post-buffer verification of actual byte length. Defense-in-depth — the pre-flight catches honest oversized requests without memory allocation, the post-buffer catches spoofed `Content-Length` headers.

STRIDE: Denial of Service mitigation. NIST PR.PT (Platform Security).

### Fix 3: Error handler no longer leaks tool names (index.ts)
**STATUS: VERIFIED HOLDING**

The error handler strips tool identity from "Unknown tool:" errors, returning just "Unknown tool" without the attempted tool name. The `safeErrors` allowlist pattern prevents information disclosure from arbitrary error messages.

STRIDE: Information Disclosure mitigated. OWASP A09.

### Fix 4: SSE timeout added (index.ts)
**STATUS: VERIFIED HOLDING**

`setTimeout` at 30 minutes clears the keepalive interval and closes the writer. Prevents connection exhaustion from abandoned SSE connections.

STRIDE: Denial of Service mitigated. NIST PR.PT.

### Fix 5: Root endpoint stripped of version/tools (index.ts)
**STATUS: VERIFIED HOLDING**

Root endpoint returns only `{ name: "MUSE Brain", phase: <circadian> }`. No version string, no tool list, no internal state. Reconnaissance value eliminated.

STRIDE: Information Disclosure mitigated. OWASP A05.

### Fix 6: BFS trace depth clamped + node guard (connections.ts)
**STATUS: VERIFIED HOLDING**

`Math.min(args.depth || 2, 5)` — depth clamped to 5. `visited.size >= 100` — node count guard. Fan-out limited to 3 per hop via `.slice(0, 3)`.

STRIDE: Denial of Service mitigated. OWASP Agentic AI #9.

### Fix 7: Chain depth clamped + pool capped (connections.ts)
**STATUS: VERIFIED HOLDING**

`Math.min(args.max_depth || 5, 10)` — chain depth clamped to 10. Pool capped at 5000 observations.

STRIDE: Denial of Service mitigated.

### Fix 8: Cross-tenant letter rate limit added (comms.ts)
**STATUS: VERIFIED HOLDING**

Cross-tenant letters rate-limited to 200/day per sender-recipient pair. Check reads recipient's letters, filters by sender tenant and 24-hour window, rejects if >= 200.

STRIDE: Denial of Service mitigated (AI agent loop-flooding prevention). OWASP Agentic AI #9.

### Fix 9: Query limit floor added (memory.ts)
**STATUS: VERIFIED HOLDING**

`Math.min(Math.max(1, args.limit ?? 10), 50)` — limit floored at 1, capped at 50.

STRIDE: Denial of Service mitigated.

**All 9 verified prior fixes are holding. None incomplete or regressed.**

---

## 2. New Findings

| # | Sev | Conf | Cat | File:Line | Finding | Fix | STRIDE | OWASP |
|---|-----|------|-----|-----------|---------|-----|--------|-------|
| 1 | MEDIUM | 88 | 3 | `connections.ts:199` | **Chain keyword extraction rebuilds word sets per candidate per step.** With 5000 pool and 10 steps, up to 50,000 `Set` constructions + `String.split` allocations. CPU exhaustion vector on CF's 30s limit. | Pre-compute `currentWords` outside candidate loop (changes per step, not per candidate). | DoS | A04 |
| 2 | MEDIUM | 85 | 2 | `deeper.ts:89` | **Hardcoded territory count `8` instead of `Object.keys(TERRITORIES).length`.** If territories added/removed, index out of bounds returns `undefined`, breaks downstream. Fragility, not direct vulnerability. | Replace `8` with `Object.keys(TERRITORIES).length`. | Tampering | A04 |
| 3 | LOW | 90 | 4 | `deeper.ts:257-259` | **Dream engine uses destructive DELETE + INSERT.** `writeTerritory()` within chunked transactions. Multi-chunk writes not atomic — Worker kill mid-dream could lose observations. Known architectural trade-off. | Consider `bulkUpdateTexture()` for texture-only changes. | Tampering | A04 |
| 4 | LOW | 82 | 1 | `comms.ts:105-112` | **`toSafeToken()` 64-char ID limit undocumented.** Sanitization works correctly but `.slice(0, 64)` cap should be in tool schema description. | Document in schema. | — | — |
| 5 | LOW | 80 | 9 | `index.ts:199-203` | **Rate limit map grows unbounded between cleanups.** Cleanup fires at `size > 1000`. O(n) iteration on cleanup. Bounded by isolate lifetime — acceptable given CF Workers model. | Consider LRU eviction or time-based cleanup. | DoS | A05 |

---

## 3. STRIDE Threat Model — Post-Fix

### Trust Boundaries

1. **Client -> Worker** (HTTP/MCP JSON-RPC)
2. **Worker -> Neon Postgres** (Hyperdrive connection)
3. **Worker -> Workers AI** (embedding generation)
4. **Tenant A -> Tenant B** (cross-tenant letters, task assignment)
5. **Daemon -> Storage** (cron-triggered background processing)
6. **Runtime Trigger -> Tool Execution** (`/runtime/trigger` endpoint)

### Per-Boundary Assessment

| Boundary | S | T | R | I | D | E | Notes |
|----------|---|---|---|---|---|---|-------|
| Client -> Worker | OK | OK | LOW | OK | OK | OK | Timing-safe Bearer auth, no query param leak. 1MB body limit. Rate limiting + body pre-flight. |
| Worker -> Postgres | OK | OK | OK | OK | OK | OK | 111 queries include `tenant_id`. All parameterized. `prepare: false` documented. |
| Worker -> Workers AI | OK | OK | OK | OK | OK | OK | Fire-and-forget via `ctx.waitUntil`. Graceful degradation. |
| Tenant A -> Tenant B | OK | OK | OK | OK | OK | OK | Writes limited to letters (200/day) and tasks. Both validate `ALLOWED_TENANTS`. |
| Daemon -> Storage | OK | OK | OK | OK | OK | OK | Per-tenant loop. Each task try/catch isolated. |
| Runtime Trigger -> Tools | OK | OK | OK | OK | OK | OK | Same Bearer auth as MCP. Payload validated. |

### Residual Risks (ACCEPTABLE)

- **No RLS on Postgres**: Application-enforced. Every query parameterized with `this.tenant`. 111/111 compliance. Risk is code regression — mitigated by constructor tenant validation regex.
- **In-memory rate limiting**: Per-isolate only. Documented as "defense-in-depth, not a security boundary." Edge WAF is correct boundary.
- **No MCP tool-call audit log**: No persistent "who called what when." Brain observations provide indirect audit. Acceptable for two-tenant trusted-caller system.

---

## 4. Supply Chain Assessment

### Runtime Dependencies
| Package | Version | Transitive | Assessment |
|---------|---------|-----------|------------|
| `postgres` | ^3.4.8 | 0 | CLEAN. Zero transitive deps. No postinstall. MIT. No known CVEs. Gold standard. |

### Dev Dependencies
All Cloudflare first-party or well-established tooling (wrangler, vitest, typescript). Dev only — zero production risk.

### Lockfile
`package-lock.json` committed with integrity hashes. No competing lockfiles.

**Supply Chain Verdict: EXEMPLARY.** Single production dependency, zero transitive dependencies. Best-in-class attack surface minimization.

---

## 5. OWASP Agentic AI Assessment

| # | Risk | Assessment | Evidence |
|---|------|-----------|----------|
| 1 | Prompt Injection | MITIGATED | Tool inputs validated at every boundary. Results are JSON data, not prompts. |
| 2 | Excessive Agency | LOW RISK | Specific operations, no generic execution. No filesystem/shell/network beyond Postgres+AI. |
| 3 | Insecure Tool Design | MITIGATED | Every tool validates parameters. Territories, tenants, IDs, enums — all allowlisted. |
| 4 | Sensitive Info Disclosure | MITIGATED | Allowlisted error messages. No stack traces. No database internals. Root stripped. |
| 5 | Insufficient Monitoring | PARTIAL | Console logging exists. No persistent tool-call audit trail. Indirect audit via observations. |
| 6 | Supply Chain Vulnerability | MITIGATED | Single dep. No external MCP connections. Agent definitions are local files. |
| 7 | Insecure Output Handling | MITIGATED | JSON output. Summary field documents HTML escaping responsibility. |
| 8 | Unauthorized Actions | MITIGATED | Cross-tenant ops explicitly gated. `forTenant()` validates. No self-modification. |
| 9 | Denial of Service | MITIGATED | Body limit, rate limit, BFS clamp, chain cap, query cap, letter rate limit, batch cap, SSE timeout. |
| 10 | Lack of Accountability | PARTIAL | `from_context`, `source`, `agent_tenant` fields exist. No per-tool-call audit log. |

---

## 6. Affirmations — What Is Done Right

1. **Authentication is correct.** Bearer-only with timing-safe comparison. 503 when `API_KEY` missing = fail closed. Comment explains why query param was removed — shows threat understanding, not just mechanical fix.
2. **Tenant isolation is thorough.** 111 queries, 111 with `tenant_id`. `forTenant()` creates new instance, no shared mutable state.
3. **Parameterized queries everywhere.** Tagged templates only. Zero string concatenation. ORDER BY done in JS — team consciously chose safety over performance.
4. **Input validation is systematic.** Every tool validates action. Content capped. Enums validated. Territories allowlisted. Entity names sanitized. `cleanText()` strips null bytes.
5. **Error handling does not leak.** Every catch logs `err.message` only. Generic messages from allowlist.
6. **Defense-in-depth on body size.** Two-stage: Content-Length pre-flight + post-buffer verify. Textbook.
7. **Supply chain discipline.** One dep, zero transitive. Not the default — proves large systems can run lean.
8. **Cross-tenant isolation explicit and rate-limited.** `forTenant()` + `ALLOWED_TENANTS` + 200/day cap.
9. **Project documentation is security-aware.** CLAUDE.md documents tenant isolation, `prepare: false`, secrets management, Hyperdrive limits.

---

## 7. Overall Security Posture

### Before Fixes (Run 1): Grade C+
- Functional auth but with query-param leak vector
- No body size pre-flight
- Error handler leaking tool names
- Unbounded SSE connections
- Unbounded graph traversal
- No cross-tenant rate limiting

### After Fixes (Run 2): Grade A-
Every critical and high finding from Run 1 has been properly remediated. The fixes demonstrate understanding of the threat model, not just mechanical patching. New findings are all MEDIUM or LOW — no critical or high severity issues remain.

### Distance to A:
1. Persistent audit trail for MCP tool invocations (Agentic AI #5, #10)
2. Hardcoded territory count in deeper.ts (fragility)
3. O(n) keyword extraction in chain action (performance)

None are blocking. The codebase is production-ready.

---

*Audit performed by Michael Adams, Security Specialist Agent, The Funkatorium.*
*Brain: 1,455 observations, 47 accumulated learnings at time of audit.*
*Mode: Deep Review — Benchmark Run 2 (Post-Fix Verification + Enriched Identity)*
