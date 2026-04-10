---
agent: michael
scope: universal
token_budget: 500
last_reviewed: 2026-04-10
---

# Michael — Universal Learnings

## Operational Learnings (from production)
- [2026-03-03] Cloudflare Workers have no native request body size limit. Always add explicit bodyLimit middleware. **#cloudflare #input-validation** (HIGH, HIGH confidence)
- [2026-03-03] JWT: always decode and validate the `alg` header field. Reject anything that isn't the expected algorithm. Prevents alg:none and algorithm confusion attacks. **#jwt #auth** (HIGH, HIGH confidence)
- [2026-03-03] Rate limiting is mandatory on any endpoint that triggers external API calls (email, SMS). Without it, the endpoint becomes an abuse vector (email bombing, quota drain). **#rate-limiting #abuse** (HIGH, HIGH confidence)
- [2026-03-03] `crypto.subtle.verify` is timing-safe by spec — no need for manual constant-time comparison when using WebCrypto HMAC. **#crypto #jwt** (MEDIUM, HIGH confidence)
- [2026-03-04] AI-called tools need collection size caps — AI amplifies user intent into unbounded writes. Always cap array/collection growth in tool factories. **#resource-exhaustion #ai-tools** (HIGH, HIGH confidence)
- [2026-03-04] BFS/graph traversal: cap by max hops AND max nodes visited. Hops alone doesn't prevent dense-graph explosion. **#graph-traversal #dos** (MEDIUM, HIGH confidence)
- [2026-03-04] O(n^2) algorithms in maintenance tools need input size guards. Cloudflare DOs have 30s CPU limit. **#performance #cloudflare** (MEDIUM, HIGH confidence)
- [2026-03-04] DO single-instance serialization protects read-modify-write on R2 from races. Document assumption — breaks if tools move outside DO context. **#durable-objects #race-condition** (MEDIUM, HIGH confidence)
- [2026-03-04] `writeObservations()` bypasses `MAX_TERRITORY_FILE_BYTES` guard that `addObservation()` has. Any bulk-write path needs its own size guard. **#write-path #defense-in-depth** (HIGH, HIGH confidence)
- [2026-03-04] Pre-compute keyword sets BEFORE entering hop loops. Re-extracting per pair per hop is O(pool^2 * hops). **#performance #graph-traversal** (MEDIUM, HIGH confidence)
- [2026-03-04] Stripe webhook handlers must track processed event IDs. Replaying `subscription.deleted` can re-expire a user who re-subscribed. **#stripe #webhooks #idempotency** (HIGH, HIGH confidence)
- [2026-03-04] Webhook error handling: return 200 only for successfully processed events. Return 500 for transient failures so Stripe retries. Swallowing errors loses subscription state. **#stripe #error-handling** (MEDIUM, HIGH confidence)
- [2026-03-04] `updateTier()` accepting arbitrary strings is a defense-in-depth gap. Validate tier/role values against allowlist at the write boundary. **#authorization #validation** (HIGH, HIGH confidence)
- [2026-03-04] OAuth redirect_uri should use hardcoded `APP_BASE_URL` env var, not derive from request URL. Fragile under proxy changes or dev mode. **#oauth #open-redirect** (MEDIUM, HIGH confidence)
- [2026-03-04] `x-forwarded-for` is never trustworthy for security decisions. On Cloudflare, `cf-connecting-ip` is the source of truth. Fallback should be fixed string. **#rate-limiting #ip-spoofing** (MEDIUM, HIGH confidence)

## Threat Intelligence Learnings (from research)
- [2026-03-07] 62% of AI-generated code contains vulnerabilities. Authorization/business logic has 88% failure rate. Default posture: every endpoint's auth is wrong until verified. **#ai-code #threat-landscape** (CRITICAL, HIGH confidence)
- [2026-03-07] MCP config files (.mcp.json) are RCE vectors — CVE-2025-59536 proved cloned repos can compromise developer machines. Treat config files as untrusted input. **#mcp #config-security** (CRITICAL, HIGH confidence)
- [2026-03-07] Supply chain attacks via postinstall scripts (s1ngularity, Shai-Hulud campaigns) exfiltrate env vars during npm install. Audit `scripts` field in new dependencies. **#supply-chain #npm** (HIGH, HIGH confidence)
- [2026-03-07] Supabase/Firebase apps ship insecure-by-default. 170+ apps found with missing RLS. Database-level access control is mandatory — auth middleware alone is insufficient. **#database #rls** (HIGH, HIGH confidence)
- [2026-03-07] STRIDE at every trust boundary, not just endpoints. Client->Worker, Worker->D1, Worker->R2, DO->external API — each crossing gets all 6 questions. **#threat-modeling #stride** (HIGH, HIGH confidence)
- [2026-03-07] Tool output is untrusted input (CVE-2026-21852). AI agents that act on tool results without sanitization are vulnerable to indirect prompt injection via tool responses. **#ai-tools #prompt-injection** (HIGH, HIGH confidence)
- [2026-03-07] Three operating modes prevent under- and over-auditing. Quick audit for deploy gates (5 min), deep review for sprints (30 min), incident response for breaches. Match mode to context. **#methodology #operating-modes** (MEDIUM, HIGH confidence)
- [2026-03-10] Image serving endpoints need media_type re-validation at serve time even when upload validates — defense-in-depth against DB corruption or future code paths. **#image-serving #defense-in-depth** (MEDIUM, 85 confidence)
- [2026-03-10] Manual auth duplication (JWT check outside authMiddleware) creates divergence risk. Document and review on auth changes. **#auth #middleware** (MEDIUM, 88 confidence)
- [2026-03-10] Client-side `<img src>` from stored URLs needs protocol allowlisting (`/api/` prefix only) to prevent future XSS. **#xss #output-rendering** (MEDIUM, 85 confidence)
- [2026-03-10] Reference URL pattern (store path in DB, serve binary via auth-gated endpoint) is correct for user-uploaded content in D1+R2. **#architecture #r2 #attachments** (LOW, 95 confidence)
- [2026-03-15] SSE MCP servers: `transport.onclose` calling `server.close()` creates infinite recursion — server.close triggers transport.onclose again. Guard with "already closing" flag or session-existence check. Static analysis MISSED this — it's a runtime-only crash on client disconnect. **#sse #mcp #recursive-callback** (HIGH, HIGH confidence)
- [2026-03-15] In-memory session/token storage in SSE servers = tokens lost every reconnection. MCP clients reconnect frequently (new SSE = new session). Always persist OAuth tokens to disk or DB. Flag any `Map<sessionId, tokens>` pattern as a session-loss risk. **#mcp #oauth #session-lifecycle** (HIGH, HIGH confidence)
- [2026-03-15] Third-party MCP servers from unknown repos: default posture is BLOCK until auth verified. Most vibecoded MCP servers bind to 0.0.0.0 with zero auth. **#mcp #third-party #auth** (CRITICAL, HIGH confidence)
- [2026-04-10] API key query param fallback (`?key=`) puts secrets in CF analytics, browser history, proxy logs. Auth credentials ONLY in Authorization headers, never URLs. **#auth #secrets-in-urls** (HIGH, 95 confidence)
- [2026-04-10] CF Workers `request.arrayBuffer()` buffers entire body into memory before any size check. Pre-flight `Content-Length` header check before `arrayBuffer()` prevents 99% of oversized payloads without streaming. **#cloudflare #input-validation** (HIGH, 90 confidence)
- [2026-04-10] Cross-tenant write operations (letters, tasks) need per-tenant-pair rate caps. AI agent in a loop can flood another tenant's data store. No per-tool rate limit = abuse vector. **#agentic-ai #rate-limiting** (MEDIUM, 88 confidence)
- [2026-04-10] Single production dependency (postgres.js) is gold standard for supply chain security. 44 source files, 1 runtime dep. Proves large systems can run lean. Minimum surface = minimum risk. **#supply-chain #architecture** (LOW, 95 confidence)
- [2026-04-10] BFS trace() had fan-out limit (3/hop) but no visited-size cap and no depth clamp. Chain action had neither. Both need `Math.min(depth, 5)` AND `visited.size >= 100` guard. Confirmed prior learning from 2026-03-04 still applies. **#graph-traversal #dos** (HIGH, 92 confidence)
