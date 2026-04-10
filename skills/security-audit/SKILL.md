# Security Audit

Invoked via `/security-audit`, `/michael`, or when Rook dispatches for security review.

## Operating Modes

### Quick Audit (deploy gate, ~5 min)
Use before deploys or for rapid pass/fail assessment.
1. Grep for dangerous patterns (hardcoded secrets, innerHTML, eval, raw SQL)
2. Check auth on all new/changed endpoints
3. Verify input validation on new user inputs
4. Scan for new dependencies with known vulnerabilities
5. Verdict: PASS, PASS WITH NOTES, or BLOCK

### Deep Review (threat model, ~30 min)
Use after feature sprints or when new trust boundaries are introduced.
1. Map all entry points and data flows
2. Identify trust boundaries (client/server, server/database, service/service)
3. STRIDE threat analysis on each boundary
4. Run full 10-category checklist below
5. Test with curl where endpoints are accessible
6. Dependency/supply chain review on new packages
7. Full findings report with threat model summary

### Incident Response
Use when a breach is suspected or a relevant CVE is disclosed.
See `~/.claude/agents/references/security-intel.md` incident response playbook.

---

## 10-Category Audit Checklist

### 1. Path Traversal & File Access `[OWASP A01] [NIST PR.AC, PR.DS]`
- [ ] Every handler accepting path/file/territory/namespace params validates input
- [ ] Check for `../`, null bytes (`%00`), URL-encoded traversal (`%2e%2e%2f`)
- [ ] Paths/keys resolve within expected boundaries (allowlist, not blocklist)
- [ ] Validation on BOTH read AND write operations
- [ ] R2 object keys constructed from user input are validated (key traversal)

### 2. Authentication & Authorization `[OWASP A01, A07] [NIST PR.AC, PR.AA]`
- [ ] Every endpoint requires auth (no accidentally public routes)
- [ ] Auth comparison is timing-safe (`crypto.timingSafeEqual`, `crypto.subtle.verify`, or equivalent)
- [ ] API keys in `Authorization: Bearer` header, never in URL parameters
- [ ] Tokens not logged or included in error responses
- [ ] Trust boundary mapping: who authenticates at each boundary?
- [ ] JWT: `alg` header validated, expected algorithm enforced
- [ ] OAuth: `redirect_uri` hardcoded, state parameter present, PKCE recommended
- [ ] Role/tier values validated against allowlist at write boundary (never accept from client)
- [ ] WebSocket: auth on connection, not just first message
- [ ] IDOR prevention: verify resource ownership, not just authentication

### 3. Input Validation `[OWASP A03] [NIST PR.DS, DE.CM]`
- [ ] Request body size limits enforced (1MB default; Cloudflare Workers need explicit middleware)
- [ ] All user-supplied strings sanitized before use
- [ ] IDs/slugs validated against expected patterns
- [ ] No raw user input in file paths, shell commands, R2 keys, or query construction
- [ ] Array/collection inputs have size caps (AI tools amplify unbounded writes)
- [ ] Graph traversal: cap by max hops AND max nodes visited
- [ ] URL validation before server-side fetches (SSRF prevention — OWASP A10)

### 4. Error Handling & Information Disclosure `[OWASP A09] [NIST DE.AE, RS.AN]`
- [ ] Error responses don't leak stack traces, file paths, or internal state
- [ ] Generic error messages for auth failures (no user enumeration)
- [ ] Health endpoints verify dependencies without exposing credentials
- [ ] Webhook handlers return 200 only on success, 500 on transient failure
- [ ] Security events logged (auth failures, permission denials, input validation failures)

### 5. Output & Rendering `[OWASP A03] [NIST PR.DS]`
- [ ] Dynamic content uses `textContent`, never `innerHTML` with user data
- [ ] No raw user input reflected in HTML without escaping
- [ ] Content-Type headers set correctly on all responses
- [ ] CSP headers configured in production

### 6. Deployment Security `[OWASP A05] [NIST PR.IP, PR.PT]`
- [ ] Secrets in environment variables or secret stores, not in code or config files committed to git
- [ ] CORS configured for specific origins, not `*` in production
- [ ] Rate limiting on all public-facing endpoints
- [ ] Rate limiting mandatory on endpoints triggering external API calls (email, SMS, AI)
- [ ] Production deploys strip debug endpoints/logging
- [ ] Security headers present: CSP, HSTS, X-Content-Type-Options, X-Frame-Options, Referrer-Policy, Permissions-Policy

### 7. Configuration File Security `[OWASP A05] [NIST PR.IP, ID.AM]`
- [ ] `.mcp.json` — no auto-trust of MCP server configs from external sources
- [ ] `.env` — not committed to git, `.gitignore` verified
- [ ] `wrangler.toml` — no secrets, only bindings and config
- [ ] IDE configs (`.cursor/`, `.vscode/`) — no credentials, no auto-execute settings
- [ ] `Dockerfile` / `docker-compose.yml` — no secrets in build args or environment
- [ ] OAuth config — redirect URIs are hardcoded, not dynamic
- [ ] Agent definition files (`.md`) — no executable content from untrusted sources

### 8. Supply Chain & Dependencies `[OWASP A06, A08] [NIST ID.SC, PR.DS]`
- [ ] New dependencies reviewed: correct name? Reputable publisher? Recent first-publish is a red flag.
- [ ] `package-lock.json` / lockfile committed and integrity hashes present
- [ ] Check `scripts` field in new dependency's `package.json` for `postinstall` hooks
- [ ] Run `npm audit` and review HIGH/CRITICAL findings
- [ ] No wildcard version ranges (`*`, `>=`) in production dependencies
- [ ] Pinned versions preferred for critical dependencies
- [ ] SBOM assessment: total dependency count, abandonment check, license audit (see `security-intel.md` § SBOM)

### 9. Infrastructure Security `[OWASP A05] [NIST PR.PT, PR.AC]`
- [ ] Cloudflare Workers: `bodyLimit` middleware, `cf-connecting-ip` for client IP
- [ ] R2 buckets: private access, CORS per-bucket, keys validated
- [ ] D1: parameterized queries only, application-level authorization
- [ ] Durable Objects: auth on WebSocket connect, state size bounded, alarm payloads validated
- [ ] Tunnels: application-level auth (tunnel itself doesn't authenticate)
- [ ] DNS: no dangling CNAMEs (subdomain takeover risk)
- [ ] HTTPS enforced on all endpoints

### 10. Incident Response Readiness `[OWASP A09] [NIST RS.RP, RC.RP]`
- [ ] All secrets can be rotated without code changes (env vars / secret stores)
- [ ] Key rotation documented: what breaks, how to restore
- [ ] Logs retained long enough for forensics (Cloudflare: check analytics retention)
- [ ] Stripe webhook event IDs tracked for idempotency (prevents replay attacks)
- [ ] Recovery path exists: can the system be restored from a compromised state?
- [ ] User notification plan: GDPR 72-hour window if PII exposed

### 11. Agentic AI Security `[OWASP Agentic AI Top 10]`
For projects using AI agents, MCP servers, or tool-calling systems:
- [ ] Agent tool permissions follow least privilege (read-only agents have NO write tools)
- [ ] All tool parameters validated inside the tool, not by the calling agent
- [ ] Tool output treated as untrusted input — never influences security decisions directly
- [ ] Agent definitions loaded only from version-controlled sources
- [ ] MCP server configs NOT auto-trusted from cloned repos or external sources
- [ ] Agent actions logged with attribution (which agent, what action, when)
- [ ] Collection/batch operations have size caps (AI amplifies unbounded writes)
- [ ] No agent can modify its own definition or escalate its own permissions
- [ ] Third-party MCP servers default BLOCK until auth verified
- [ ] Prompt injection mitigations on all agent input surfaces

---

## OpenAPI Testing Patterns

When a project contains `openapi.json`, `openapi.yaml`, `swagger.json`, or similar:

```bash
# 1. Enumerate all endpoints from spec
# Parse the spec and list: method, path, auth requirement, parameters

# 2. Auth bypass — test every endpoint without credentials
for endpoint in $(parse_endpoints); do
  curl -s -o /dev/null -w "%{http_code}" "$BASE_URL$endpoint"
  # Expect: 401 or 403 for all protected endpoints
done

# 3. IDOR — test resource endpoints with wrong user's ID
curl -H "Authorization: Bearer $USER_A_TOKEN" "$URL/api/users/$USER_B_ID"
# Expect: 403, not 200 with User B's data

# 4. Method confusion — try unexpected HTTP methods
curl -X DELETE -H "Authorization: Bearer $TOKEN" "$URL/api/resource/123"
curl -X PUT -H "Authorization: Bearer $TOKEN" "$URL/api/readonly-resource/123"
# Expect: 405 for unsupported methods, not silent success

# 5. Schema violation — send data that violates the spec
curl -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"email": "not-an-email", "age": -1, "name": ""}' "$URL/api/users"
# Expect: 400 with validation error, not 200

# 6. Shadow API detection — find endpoints in code but not in spec
grep -rn 'app\.\(get\|post\|put\|delete\|patch\)' src/ | grep -v test
# Compare against spec endpoints — undocumented endpoints are shadow APIs

# 7. Pagination abuse
curl -H "Authorization: Bearer $TOKEN" "$URL/api/items?limit=999999&offset=0"
# Expect: capped limit, not unlimited data dump
```

### Systematic API Security Checklist
- [ ] Every endpoint in spec has auth declared AND enforced
- [ ] Every endpoint in code exists in spec (no shadow APIs)
- [ ] Request schemas enforce type, length, and format constraints
- [ ] Response schemas don't include internal fields (password hash, internal IDs)
- [ ] Pagination is enforced with maximum limits
- [ ] Bulk endpoints have batch size limits
- [ ] Rate limiting applied per-endpoint based on cost (expensive ops = lower limits)
- [ ] API versioning strategy doesn't expose deprecated insecure endpoints

---

## Curl Test Patterns

```bash
# Path traversal
curl -H "Authorization: Bearer $KEY" "$URL/territory/../../etc/passwd"

# Missing auth
curl "$URL/sensitive-endpoint"

# Oversized payload
curl -H "Authorization: Bearer $KEY" -d "$(python3 -c 'print("x"*2000000)')" "$URL/endpoint"

# SQL injection probe
curl -H "Authorization: Bearer $KEY" "$URL/user/1' OR '1'='1"

# Header injection
curl -H "Authorization: Bearer $KEY" -H "X-Forwarded-For: 127.0.0.1" "$URL/rate-limited-endpoint"

# WebSocket auth bypass
wscat -c "ws://localhost:PORT/ws" -H "Authorization: Bearer invalid"

# CORS probe
curl -H "Origin: https://evil.com" -I "$URL/api/endpoint"
```

## Tooling (when available)

```bash
# Static analysis
semgrep scan --config auto --severity ERROR --severity WARNING .

# Secret scanning (current files)
trufflehog filesystem . --only-verified

# Secret scanning (git history)
gitleaks detect --source . --verbose

# Dependency audit
npm audit --json | jq '.vulnerabilities | to_entries[] | select(.value.severity == "critical" or .value.severity == "high")'
```

## Output Format

**Security Assessment: [Name]**
**Mode:** Quick Audit | Deep Review | Incident Response
**Verdict:** PASS | PASS WITH NOTES | BLOCK

| Severity | Category | Finding | File:Line | Fix |
|----------|----------|---------|-----------|-----|
| CRITICAL | [1-10] | [description] | [location] | [specific fix] |
| HIGH | [1-10] | [description] | [location] | [specific fix] |
| MEDIUM | [1-10] | [description] | [location] | [specific fix] |
| LOW | [1-10] | [description] | [location] | [specific fix] |

- **Threat model summary** (deep review only)
- **Attack surface map**
- **Supply chain notes**
- **Recommendations** — ordered by severity, with effort estimates

## Lessons From Our Bugs

- `validateTerritory()` was defined but not called in write handlers — always grep for validation functions and verify they're actually invoked at every call site
- Health endpoint returned `"degraded"` when R2 wasn't bound — make sure error messages are actionable without leaking internals
- Extension security: `sender` validation + action allowlists prevent injection through browser message passing
- AI-called tools need collection size caps — AI amplifies user intent into unbounded writes
- `writeObservations()` bypassed `MAX_TERRITORY_FILE_BYTES` guard — any bulk-write path needs its own size guard
- Stripe webhooks without event ID tracking allow replay of `subscription.deleted` against re-subscribed users
- `x-forwarded-for` is spoofable; on Cloudflare, `cf-connecting-ip` is truth
