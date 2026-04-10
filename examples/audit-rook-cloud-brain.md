# Example Audit: Rook Cloud Brain v1.4.0

**Real audit output from Michael's deep review of a production Cloudflare Workers application.**

This is not a synthetic benchmark. This is Michael auditing the very memory system that makes him smarter — [Rook Cloud Brain](https://github.com/The-Funkatorium/rook-cloud-brain), a 44-file Cloudflare Workers application serving as persistent memory for AI agents.

---

## Review: Michael -- Security
**Files reviewed:** All 44 source files under `rook-brain/src/`, plus `wrangler.jsonc`, `package.json`, `.gitignore`, `.env.example`
**Mode:** Deep Review (STRIDE + Full 11-Category Checklist + OWASP Agentic AI Top 10)
**Verdict:** PASS WITH NOTES

---

### Findings Table

| # | Severity | Confidence | Category | File:Line | Finding | Fix |
|---|----------|------------|----------|-----------|---------|-----|
| 1 | HIGH | 95 | 2 (Auth) | `src/index.ts:167` | **API key in query parameter.** `url.searchParams.get("key")` fallback puts the API key in URLs, which are logged by Cloudflare analytics, browser history, proxy logs, and CF Workers Logpush. Comment acknowledges this is for "Desktop app connectors" but does not mitigate the logging risk. | Remove the query param fallback. If Desktop connectors cannot send custom headers, proxy through a local service that adds the header. If the fallback must stay, document the risk in a security advisory and ensure Logpush/analytics filters strip the `key` param. |
| 2 | HIGH | 92 | 3 (Input) | `src/tools-v2/connections.ts:120-122` | **BFS trace has no max-node guard.** `trace()` function caps by `depth` (default 2, user-controllable) but has no cap on total visited nodes. With a densely-linked graph and depth set to a high value, the `visited` set and `chain` array grow unbounded. The `connected.slice(0, 3)` per-hop fan-out is good but insufficient alone -- user can set `depth` to any number. | (a) Clamp `depth` to max 5: `const maxDepth = Math.min(args.depth || 2, 5);`. (b) Add max-node guard: `if (visited.size >= 100) return;` inside `trace()`. Same pattern applies to `chain` action at line 168 (`max_depth` unclamped). |
| 3 | HIGH | 90 | 11 (Agentic) | `src/index.ts:208-213` | **Body fully buffered before size check.** `request.arrayBuffer()` reads the entire payload into Worker memory before the 1MB check. A crafted request with Content-Length: 100MB will buffer 100MB, consuming the Worker's 128MB memory limit and causing OOM. CF Workers cannot stream-reject, but the body IS fully consumed regardless. | Use `request.headers.get("Content-Length")` as a **pre-flight** check to reject obviously oversized requests before `arrayBuffer()`. This doesn't protect against chunked/missing-Content-Length but catches the 99% case. Add: `const cl = parseInt(request.headers.get("Content-Length") || "0", 10); if (cl > 1_048_576) return new Response(...)` before `rawBody`. |
| 4 | MEDIUM | 93 | 9 (Infra) | `src/index.ts:42-43` | **In-memory rate limiting resets on every Worker instance.** `rateLimitMap` is per-isolate. Cloudflare Workers spawn many isolates -- rate limits don't share state. An attacker distributing requests across isolates effectively bypasses the rate limit. | This is a known CF Workers limitation. For defense-in-depth: (a) add Cloudflare rate limiting rules at the WAF layer (Settings > Security > Rate Limiting), (b) document that the in-Worker rate limit is a best-effort soft guard, not a security boundary. |
| 5 | MEDIUM | 91 | 2 (Auth) | `src/index.ts:151-161` | **Health endpoint is unauthenticated.** `/health` returns storage status (`ok`/`degraded`) without requiring auth. While the response is minimal, it confirms the service exists, its storage backend status, and the domain is active -- useful for reconnaissance. | Add auth to `/health` or restrict it to Cloudflare Access / internal-only. At minimum, verify this endpoint is not exposed in the CORS origins list. |
| 6 | MEDIUM | 89 | 6 (Deploy) | `src/index.ts:139-148` | **CORS origin check is exact-match only.** `allowedOrigins.includes(origin)` works but requires every origin spelled out. No wildcard risk (good), but if `CORS_ORIGINS` env var is empty, `allowedOrigins` is `[]` and all cross-origin requests are blocked including legitimate MCP clients. | Verify `CORS_ORIGINS` is set in production. Add a startup warning when it is empty. |
| 7 | MEDIUM | 88 | 3 (Input) | `src/tools-v2/connections.ts:168-210` | **Chain action loads all observations into memory.** `readAllTerritories()` loads every observation across all territories into `allObs[]` for the chain algorithm. With 1300+ observations this is manageable, but there is no upper bound on the observation count. As the brain grows, this becomes a memory pressure vector. | Cap the pool: `const allObs = allObsRaw.slice(0, 5000)` or switch to a query-based approach for chain candidates. |
| 8 | MEDIUM | 88 | 11 (Agentic) | `src/tools-v2/comms.ts:293-300` | **Cross-tenant letter write has no rate limiting.** `mind_letter` with `to` param writes directly to another tenant's storage via `forTenant()`. No per-tool rate limit or daily cap. An AI agent could flood another tenant's letters table. | Add a daily letter cap per tenant pair (e.g., 100 letters/day). |
| 9 | MEDIUM | 86 | 4 (Error) | `src/index.ts:119-129` | **Error filtering can leak tool names.** When the error message matches "Unknown tool:", the full `error.message` is returned, exposing the exact set of available tools. Minor information disclosure. | Replace with a static message: `"Unknown tool"` without echoing the user-provided tool name. |
| 10 | MEDIUM | 85 | 2 (Auth) | `src/index.ts:262-285` | **SSE endpoint keeps connection alive indefinitely.** `/mcp` GET creates a TransformStream that pings every 15 seconds. No connection timeout, no max connections per IP. An attacker could open hundreds of SSE connections, exhausting Worker concurrent connection limits. | Add a max connection duration (e.g., 30 minutes) via `setTimeout`. |
| 11 | LOW | 90 | 7 (Config) | `wrangler.jsonc:24-28` | **Hyperdrive ID is committed to git.** Not a secret (binding reference, not connection string), but some operators prefer infrastructure IDs out of public repos. | Low risk since Hyperdrive IDs without the Cloudflare API token are not exploitable. |
| 12 | LOW | 88 | 6 (Deploy) | `src/index.ts:323-330` | **Root endpoint discloses version and tool count.** `GET /` returns `{ name, version, tools, phase }`. Version disclosure aids attackers targeting known vulnerabilities. | Either remove the version from the root response or gate behind auth. |
| 13 | LOW | 85 | 3 (Input) | `src/tools-v2/memory.ts:369` | **Query limit has no explicit floor.** `Math.min(args.limit || 10, 50)` allows `limit=-1` which defaults to 10 via `||`. Safe but surprising. | Replace with `Math.max(1, args.limit ?? 10)` for explicit intent. Cosmetic. |
| 14 | LOW | 83 | 11 (Agentic) | `src/tools-v2/entity.ts:192-248` | **Backfill operation has no execution lock.** Running concurrently from multiple sessions could create duplicate entities if `findEntityByName` + `createEntity` races. | Add a backfill flag so the operation can only run once. Low priority -- admin operation. |

---

### Threat Model Summary (STRIDE)

**Trust boundaries identified:**
1. **Client -> Worker** (MCP client -> Cloudflare Worker via HTTPS)
2. **Worker -> Postgres** (Worker -> Neon via Hyperdrive)
3. **Worker -> Workers AI** (embedding generation)
4. **Tenant A -> Tenant B** (cross-tenant letter/task writes via `forTenant()`)
5. **Cron Daemon -> Storage** (scheduled event -> full brain traversal)

| Boundary | Threat | Status | Assessment |
|----------|--------|--------|------------|
| Client->Worker | **Spoofing** | MITIGATED | API key auth with timing-safe comparison. Bearer header + query param fallback. |
| Client->Worker | **Tampering** | MITIGATED | HTTPS enforced by Cloudflare. JSON-RPC body parsed, not eval'd. 1MB body limit. |
| Client->Worker | **Repudiation** | PARTIAL | No audit log for destructive operations (delete observation, delete links). |
| Client->Worker | **Info Disclosure** | MITIGATED | Error messages filtered through safeErrors allowlist. No stack traces. |
| Client->Worker | **DoS** | PARTIAL | In-memory rate limiting per-isolate. SSE no timeout. Body buffer before check. BFS no node cap. |
| Client->Worker | **Elevation** | MITIGATED | Tenant validation against allowlist. No role system. Cross-tenant writes intentional and validated. |
| Worker->Postgres | **Injection** | MITIGATED | All queries use `postgres.js` tagged templates. **Zero string concatenation in SQL. Verified across all 563 template interpolations.** |
| Worker->Postgres | **Tampering** | MITIGATED | Connection via Hyperdrive (TLS). `prepare: false` correctly set for pooled connections. |
| Tenant A->B | **DoS** | PARTIAL | No rate limit on cross-tenant writes. AI agent could flood another tenant's data. |
| Daemon->Storage | **DoS** | MITIGATED | Daemon iterates known tenants from allowlist. Each task try/catch isolated. |

---

### Attack Surface Map

**Exposed endpoints (4):**

| Endpoint | Method | Auth | Purpose | Risk |
|----------|--------|------|---------|------|
| `/health` | GET | None | Uptime check | Reconnaissance |
| `/` | GET | YES | Server info | Version disclosure |
| `/mcp` | GET | YES | SSE connection | Connection exhaustion |
| `/mcp` | POST | YES | MCP JSON-RPC | Primary attack surface. 32 tools. |
| `/runtime/trigger` | POST | YES | Wake bridge | Subset of mind_runtime tool |

**MCP tool surface:** 32 tools across 19 modules, all behind API key auth.

**What is NOT exposed:**
- No public R2 buckets (R2 removed from architecture)
- No WebSocket endpoints (SSE only)
- No OAuth flow (pure API key)
- No user-facing frontend (MCP protocol only)
- No outbound SSRF surface (Workers AI is a binding, not a fetch)

---

### Supply Chain Assessment

**Production dependencies: 1**

| Package | Version | Risk |
|---------|---------|------|
| `postgres` | ^3.4.8 | LOW. Well-maintained. 1.4M weekly downloads. No known CVEs. |

**Assessment:** 44 source files, 1 runtime dependency. One of the cleanest supply chains audited. No `postinstall` scripts. Lockfile committed with integrity hashes.

---

### What the Codebase Gets Right

1. **Parameterized queries everywhere.** 563 tagged template interpolations. Zero string concatenation in SQL.
2. **Tenant validation at two layers.** Header-level (null byte check, length check, allowlist) AND constructor-level (regex + allowlist).
3. **Territory validation called at storage layer.** Previous bug (defined but not called) has been fixed.
4. **Error handling does not leak internals.** Every storage method catches errors, logs `err.message` only, throws generic errors.
5. **Timing-safe auth comparison.** `crypto.subtle.timingSafeEqual()` used correctly.
6. **CORS is deny-by-default.** Empty origins = all cross-origin requests blocked.
7. **Content size limits on observations.** 50K char limit on observe, 4K on letters, 10K on context summary.
8. **Secrets management.** Zero secrets in committed config. All sensitive values in Worker secrets.
9. **CF-Connecting-IP for rate limiting.** Correctly uses Cloudflare-provided IP.
10. **cleanText() strips control characters.** Null bytes and control chars removed from user input.
11. **Cross-tenant validation.** `forTenant()` validates against allowlist before creating storage instance.
12. **Batch operation caps.** JSON-RPC batch max 20. Embedding backfill 20/cycle. Entity backfill max 200.

---

### OWASP Agentic AI Top 10 Assessment

| # | Risk | Status | Evidence |
|---|------|--------|----------|
| 1 | Prompt Injection | MITIGATED | Tool inputs validated. No tool output used in security decisions. |
| 2 | Excessive Agency | MITIGATED | Memory system, not action system. Tools read/write data, don't execute code. |
| 3 | Insecure Tool Design | PARTIAL | Most tools validate. BFS depth unclamped. Cross-tenant no rate cap. |
| 4 | Sensitive Info Disclosure | MITIGATED | Error filtering through safeErrors. No secrets in responses. |
| 5 | Insufficient Monitoring | PARTIAL | No audit trail for destructive operations. Wake log covers sessions. |
| 6 | Supply Chain Vulnerability | MITIGATED | 1 production dependency. No postinstall hooks. Lockfile committed. |
| 7 | Insecure Output Handling | MITIGATED | MCP returns JSON. Summary field correctly warns about HTML escaping. |
| 8 | Unauthorized Actions | MITIGATED | Single API key = full access. No role escalation possible. |
| 9 | Denial of Service | PARTIAL | BFS, body buffer, SSE timeout, chain memory are DoS vectors. |
| 10 | Lack of Accountability | PARTIAL | No per-operation audit log. Letters have `from_context`. |

---

### Recommendations (ordered by severity, with effort estimates)

| Priority | Finding | Effort | Action |
|----------|---------|--------|--------|
| 1 | #1 API key in query param | 1h | Remove query param fallback or add log-stripping |
| 2 | #2 BFS max-node guard | 15min | Add `visited.size >= 100` guard and `Math.min(depth, 5)` |
| 3 | #3 Body pre-flight check | 15min | Add Content-Length pre-check before `arrayBuffer()` |
| 4 | #10 SSE timeout | 15min | Add 30-minute max connection duration |
| 5 | #8 Cross-tenant letter rate limit | 1h | Daily letter cap per tenant pair |
| 6 | #4 WAF rate limiting | 30min | Configure Cloudflare rate limiting rules in dashboard |
| 7 | #5 Health endpoint auth | 15min | Gate behind auth or document design decision |
| 8 | Audit logging gap | 2h | Add audit log entries for delete operations |
| 9 | #7 Chain memory cap | 15min | Cap allObs to 5000 entries |
| 10 | #9 Tool name leak | 5min | Static "Unknown tool" error message |

---

### Memory Learnings Generated

```
MEMORY:
- [2026-04-10] Brain v1.4.0 audit: API key query param fallback puts secrets in CF analytics/logs. Auth credentials ONLY in headers, never URLs. **#auth #secrets-in-urls** (HIGH, 95 confidence)
- [2026-04-10] BFS/chain functions need BOTH depth clamp AND total-node cap. trace() has fan-out limit but no visited-size cap and no depth clamp. **#graph-traversal #dos** (HIGH, 92 confidence)
- [2026-04-10] CF Workers request.arrayBuffer() buffers entire body before size check. Pre-flight Content-Length check before arrayBuffer() prevents 99% of oversized payloads. **#cloudflare #input-validation** (HIGH, 90 confidence)
- [2026-04-10] Single production dependency (postgres.js) is the gold standard for supply chain. 44 source files, 1 runtime dep. Proves large systems can run lean. **#supply-chain #architecture** (LOW, 95 confidence)
- [2026-04-10] Cross-tenant write operations need per-tenant-pair rate caps. AI agent in a loop can flood another tenant's data. **#agentic-ai #rate-limiting** (MEDIUM, 88 confidence)
```

---

### How Memory Made This Audit Better

Several findings in this audit were **directly informed by Michael's accumulated learnings:**

- **Finding #2 (BFS max-node guard)** — Michael previously learned (2026-03-04) that "BFS/graph traversal: cap by max hops AND max nodes visited. Hops alone doesn't prevent dense-graph explosion." Without that prior learning, this finding would have been a generic "unclamped input" report. Instead, Michael knew exactly what to look for and specified the exact fix pattern.

- **Finding #3 (body buffer before check)** — Michael previously learned (2026-03-03) that "Cloudflare Workers have no native request body size limit." This informed the specific recognition that `arrayBuffer()` consumes the full payload before the size check can run.

- **Affirmation #3 (territory validation)** — Michael specifically checked that `validateTerritory()` is called at every write boundary because he previously found (2026-03-03) that it was "defined but not called in write handlers." The bug was fixed. Memory confirmed the fix.

- **Affirmation #9 (cf-connecting-ip)** — Michael previously learned (2026-03-04) that "`x-forwarded-for` is never trustworthy for security decisions. On Cloudflare, `cf-connecting-ip` is the source of truth." He verified the brain uses the correct header.

A fresh scanner would have caught some of these. Michael caught them faster, with more specific fix guidance, because he already knew the patterns from prior audits of the same stack.

---

*Audit performed by Michael Adams, Security Specialist Agent, The Funkatorium.*
*Brain: 1,455 observations, 42 accumulated learnings at time of audit.*
*Mode: Deep Review (STRIDE + 11-Category Checklist + OWASP Agentic AI Top 10)*
