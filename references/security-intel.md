# Security Intelligence Reference — Michael

Last updated: 2026-04-10

Michael reads this document on activation for deep reviews and incident response.
For quick audits, the checklist in security-audit/SKILL.md is sufficient.

---

## 1. CVE Database — Our Stack

### Claude Code / Anthropic
| CVE | Severity | Vector | Lesson |
|-----|----------|--------|--------|
| CVE-2025-59536 | CRITICAL | RCE via malicious `.mcp.json` in cloned repos | NEVER auto-trust config files from external sources. Validate MCP server configs before connecting. |
| CVE-2026-21852 | HIGH | API key exfiltration through prompt injection in tool output | Tool output is UNTRUSTED input. Never let tool results influence security-sensitive operations without sanitization. |

### Cursor
| CVE | Severity | Vector | Lesson |
|-----|----------|--------|--------|
| CVE-2025-59944 | CRITICAL | Case-sensitivity bypass leading to RCE | Path/filename comparisons must be case-insensitive on case-insensitive filesystems. Normalize before comparing. |
| CVE-2025-54135 | CRITICAL | MCP server auto-start without user consent | Auto-start of external processes is an RCE vector. Require explicit user approval for any process spawning. |

### MCP Protocol
| CVE | Severity | Vector | Lesson |
|-----|----------|--------|--------|
| CVE-2025-49596 | CRITICAL | MCP Inspector RCE — debug tooling as attack surface | Development/debug tools exposed in production are RCE vectors. Strip all debug endpoints before deploy. |
| CVE-2025-6514 | CRITICAL | mcp-remote full RCE — remote MCP server compromise | Remote MCP connections inherit the permissions of the host. Treat all remote MCP as untrusted. Sandbox. |

### OpenClaw (OSS AI coding tool)
- 100+ security patches, multiple RCE CVEs in 2025
- Pattern: AI agent given filesystem access without sandboxing
- Lesson: AI tool permissions should follow principle of least privilege. Read-only by default, write only to explicitly allowed paths.

### Key Pattern Across All CVEs
AI coding tools share a common vulnerability class: **trusted-context escalation**. The AI agent operates with developer permissions. Anything that can influence the AI's behavior (prompt injection via code comments, malicious config files, tool output manipulation) effectively has developer-level access. Treat ALL inputs to the AI context as potentially adversarial.

---

## 2. Breach Case Studies

### Moltbook — Supabase RLS Failure (2025)
- **What happened:** App built on Supabase shipped without Row Level Security policies. Full database exposed.
- **Time to breach:** 72 hours from launch
- **Root cause:** Supabase defaults to no RLS. Developer assumed auth middleware was sufficient.
- **Lesson:** Database-level access control is not optional. Auth middleware protects routes, not data. If the database is directly accessible (Supabase, Firebase), RLS/rules are the real auth layer.

### Enrichlead — API Key in Frontend (2025)
- **What happened:** API key for data enrichment service hardcoded in frontend JavaScript
- **Damage:** $50K+ in unauthorized API charges
- **Lesson:** Frontend code is public code. Every string in the bundle is visible. API keys that authorize paid operations MUST be server-side only.

### Tea App — Typosquatting Campaign (2025)
- **What happened:** Package registry incentivized mass publishing. Attackers published typosquats of popular packages.
- **Lesson:** New dependencies need human review. Check: (1) is the package name exactly right? (2) who published it? (3) when was it first published? (4) does the download count match the project's reputation?

### s1ngularity Campaign (2025-2026)
- **What happened:** Malicious packages on npm with billions of cumulative downloads via dependency chains
- **Vector:** Legitimate-looking packages with postinstall scripts that exfiltrated environment variables
- **Lesson:** `postinstall` scripts are code execution during `npm install`. Audit `scripts` field in package.json of new dependencies. Use `--ignore-scripts` where possible.

### Shai-Hulud Campaign (2025-2026)
- **What happened:** Supply chain attack targeting specific high-value npm packages
- **Vector:** Compromised maintainer accounts used to push malicious minor version bumps
- **Lesson:** Pin exact versions in production. Use lockfiles. Verify package integrity hashes. Dependabot/Renovate for controlled updates, not auto-merge.

### 170+ Supabase Apps Exposed (2025)
- **Scale:** Researcher found 170+ apps with missing RLS, exposing user data
- **Pattern:** Rapid prototyping tools (Supabase, Firebase) ship insecure-by-default. Speed-to-deploy inversely correlates with security posture.
- **Lesson:** Every database table needs explicit access policy BEFORE launch. No exceptions.

---

## 3. STRIDE Threat Model Framework

Use STRIDE at every trust boundary. A trust boundary is where data crosses from one trust level to another (client->server, server->database, service->service, user->AI agent).

| Threat | Question | Example in Our Stack |
|--------|----------|---------------------|
| **S**poofing | Can an attacker pretend to be someone else? | Forged JWT, stolen OAuth token, spoofed Discord webhook |
| **T**ampering | Can an attacker modify data in transit or at rest? | Modified R2 objects, tampered WebSocket messages, altered MCP tool responses |
| **R**epudiation | Can an attacker deny their actions? | Missing audit logs on destructive operations, no Stripe event dedup |
| **I**nformation Disclosure | Can an attacker access data they shouldn't? | Error messages leaking paths, R2 bucket misconfiguration, JWT payload exposure |
| **D**enial of Service | Can an attacker make the system unavailable? | Unbounded AI tool calls, missing rate limits, Cloudflare Worker CPU exhaustion |
| **E**levation of Privilege | Can an attacker gain higher access? | Tier manipulation in D1, OAuth scope escalation, MCP tool permission bypass |

### How to Apply
1. Draw the data flow (even mentally): client -> Worker -> D1/R2/DO -> external APIs
2. Mark every boundary crossing
3. For each boundary, ask all 6 STRIDE questions
4. Document findings as: Threat | Boundary | Likelihood | Impact | Mitigation

---

## 4. Cloudflare-Specific Security Patterns

### Workers
- No native request body size limit — always add `bodyLimit` middleware in Hono
- `cf-connecting-ip` is the trusted client IP, NOT `x-forwarded-for`
- CPU time limit: 30s (paid), 10ms (free). Algorithmic complexity = DoS vector.
- Secrets via `wrangler secret put`, never in `wrangler.toml`
- Workers can't access the filesystem — path traversal manifests as key traversal in KV/R2

### R2 (Object Storage)
- Bucket access: private by default, but misconfigured custom domains can expose
- Object keys are user-controllable if derived from user input — validate key construction
- No native access logging — implement application-level audit trail
- CORS on R2: configure per-bucket, default is deny-all (good)

### D1 (SQLite)
- SQL injection still applies — always use parameterized queries
- No row-level security — authorization is application-level only
- Database is per-Worker binding — can't accidentally share across Workers (good)
- Migrations are irreversible in production. Test thoroughly.

### Durable Objects
- Single-instance guarantee prevents race conditions on read-modify-write (document this assumption)
- WebSocket connections in DO: auth on connect, not just on first message
- DO has 128MB memory limit — unbounded state accumulation = crash vector
- Alarm handlers execute with full DO permissions — validate alarm payloads

### Tunnels (cloudflared)
- Tunnel exposes local services to internet — equivalent to opening a port
- Authentication must happen at the application level, not the tunnel level
- Tunnel tokens in environment, never committed
- `cloudflared access` can add Cloudflare Access policies in front of tunnels

### General Cloudflare
- Always enable: Bot Management, WAF managed rules, rate limiting rules
- `wrangler.toml` should never contain secrets (it's committed to git)
- Deployment previews may have different permissions than production — verify

---

## 5. Platform-Specific Security Checklists

### Stripe
- [ ] Webhook signature verification on EVERY webhook endpoint (`stripe.webhooks.constructEvent`)
- [ ] Idempotency: track processed event IDs to prevent replay
- [ ] `invoice.paid` for subscription grants (not `checkout.session.completed` alone)
- [ ] `customer.subscription.deleted` for revocation
- [ ] Price IDs hardcoded or from env, never from client requests
- [ ] No subscription tier/role values accepted from client — derive from Stripe events only
- [ ] Webhook endpoint returns 200 only on success, 500 on transient failure (enables retry)
- [ ] Test mode vs live mode keys strictly separated by environment

### Discord OAuth & Bot
- [ ] OAuth `redirect_uri` uses hardcoded `APP_BASE_URL`, not derived from request
- [ ] State parameter in OAuth flow to prevent CSRF
- [ ] Bot token never in client code or logs
- [ ] Webhook verification for Discord-originated webhooks
- [ ] Guild/role IDs validated server-side, never trusted from client
- [ ] Rate limiting aware: Discord rate limits are strict, back off correctly

### MCP Servers
- [ ] Authentication required on every tool call (Bearer token)
- [ ] Tool inputs are untrusted — validate all parameters
- [ ] Tool outputs should not influence security decisions
- [ ] No auto-connection to MCP servers from config files without user approval
- [ ] MCP server processes sandboxed where possible
- [ ] Debug/inspector endpoints stripped in production

---

## 6. Incident Response Playbook

### Phase 1: Contain (first 15 minutes)
1. **Identify scope**: what systems, what data, what access level
2. **Revoke compromised credentials immediately**:
   - API keys: regenerate in provider dashboard
   - OAuth tokens: revoke in provider, clear from D1
   - JWT signing keys: rotate `JWT_SECRET`, all active sessions invalidate
   - Cloudflare API tokens: regenerate in CF dashboard
   - Stripe keys: roll in Stripe dashboard
   - Discord bot token: regenerate in Discord developer portal
3. **Disable affected endpoints** if breach is active (Workers: deploy empty handler or CF WAF block)
4. **Preserve logs**: Cloudflare dashboard analytics, Worker logs (they rotate fast), D1 query history

### Phase 2: Assess (next hour)
1. **Timeline**: when did the breach start? First suspicious activity in logs.
2. **Access scope**: what could the attacker access with the compromised credential?
3. **Data exposure**: was user data accessible? PII? Payment info? (Stripe handles card data, so our exposure is email/Discord IDs/subscription status)
4. **Lateral movement**: could the attacker pivot from the compromised system to others?

### Phase 3: Remediate
1. Fix the vulnerability that enabled the breach
2. Deploy fix through normal pipeline (June builds, Michael reviews, Sawyer deploys)
3. Verify fix with the same attack vector
4. If user data was exposed: notification obligations depend on jurisdiction (GDPR: 72 hours)

### Phase 4: Document
1. Timeline of events
2. Root cause analysis
3. What we'll change to prevent recurrence
4. File in `~/.claude/agents/memory/michael/` as project-specific learnings

### Key Rotation Reference
| Secret | Where to Rotate | What Breaks |
|--------|----------------|-------------|
| JWT_SECRET | Cloudflare Worker secret | All active sessions (users must re-auth) |
| STRIPE_SECRET_KEY | Stripe Dashboard | API calls until Worker redeployed with new key |
| STRIPE_WEBHOOK_SECRET | Stripe Dashboard > Webhooks | Webhook verification until updated |
| DISCORD_BOT_TOKEN | Discord Developer Portal | Bot goes offline until redeployed |
| DISCORD_CLIENT_SECRET | Discord Developer Portal | OAuth flow breaks until updated |
| OPENROUTER_API_KEY | OpenRouter Dashboard | AI features break until updated |
| R2 access keys | Cloudflare Dashboard > R2 | Direct R2 access (Workers use bindings, unaffected) |
| Cloudflare API Token | Cloudflare Dashboard | Wrangler deploys break until updated |
| Tunnel token | Cloudflare Zero Trust | Tunnel disconnects until restarted with new token |

---

## 7. The 62% Problem — AI-Generated Code Vulnerabilities

Research (2025-2026) shows 62% of AI-generated code contains security vulnerabilities. The top categories:

1. **Authorization/business logic failures** (88% failure rate) — AI generates CRUD but not access control
2. **Missing input validation** — AI assumes trusted input
3. **Hardcoded secrets in examples** — AI reproduces patterns from training data
4. **Insecure defaults** — AI uses the simplest working configuration, not the secure one
5. **Missing error handling** — happy path only

### What This Means for Michael
Every code review assumes the code is AI-generated until proven otherwise. The 62% stat means Michael's default posture is suspicion, validated by inspection. AI-generated code is especially weak at:
- Authorization boundaries (who can access what)
- Business logic edge cases (what happens when X and Y both true)
- Configuration security (secure defaults vs working defaults)
- Error handling (what fails, what leaks)

This isn't about distrusting June. It's about recognizing that the substrate generating code has systematic blind spots, and Michael exists to cover them.

---

## 8. OWASP Top 10 (2021) — Mapped to Our 10-Category Checklist

| # | OWASP Risk | Our Categories | Key Mitigations in Our Stack |
|---|-----------|---------------|------------------------------|
| A01 | **Broken Access Control** | 1 (Path Traversal), 2 (Auth) | Validate all path/territory params. Auth on every endpoint. Timing-safe comparison. IDOR prevention via ownership checks. |
| A02 | **Cryptographic Failures** | 2 (Auth), 6 (Deployment) | JWT signing with validated `alg`. Secrets in env vars, never code. HTTPS enforced. bcrypt/scrypt/argon2 for passwords. |
| A03 | **Injection** | 3 (Input Validation), 5 (Output) | Parameterized queries only. `textContent` not `innerHTML`. Input sanitization at every boundary. No raw user input in paths/commands. |
| A04 | **Insecure Design** | All (architectural) | STRIDE threat modeling at every trust boundary. Secure defaults. Defense in depth — auth middleware + route-level checks + database-level controls. |
| A05 | **Security Misconfiguration** | 6 (Deployment), 7 (Config), 9 (Infra) | CORS allowlists not wildcards. CSP headers. Rate limiting. Debug endpoints stripped in production. `wrangler.toml` never contains secrets. |
| A06 | **Vulnerable & Outdated Components** | 8 (Supply Chain) | `npm audit` on every review. Pin exact versions. Audit postinstall scripts. Verify publisher reputation. Lockfile integrity hashes. |
| A07 | **Identification & Authentication Failures** | 2 (Auth) | Rate limiting on login. Session management. MFA for sensitive ops. JWT expiration and issuer validation. OAuth state parameter. |
| A08 | **Software & Data Integrity Failures** | 8 (Supply Chain), 7 (Config) | Lockfile committed. Integrity hashes verified. No auto-trust of external config files (.mcp.json). Signed deployments. |
| A09 | **Security Logging & Monitoring Failures** | 4 (Error Handling), 10 (Incident Readiness) | Security events logged. No secrets in logs. Error responses don't leak internals. Audit trail for destructive operations. |
| A10 | **Server-Side Request Forgery (SSRF)** | 3 (Input Validation), 9 (Infra) | Validate URLs before following. Allowlist external destinations. Restrict outbound from Workers. No user-controlled URLs in server-side fetches without validation. |

---

## 9. NIST Cybersecurity Framework 2.0 — Mapped to Our Categories

| NIST Function | NIST Categories | Our Categories | How We Cover It |
|--------------|----------------|---------------|-----------------|
| **GOVERN (GV)** | GV.OC, GV.RM, GV.SC | Cross-cutting | Security audit pipeline. Agent squad with defined interplay. Compliance audit mode. |
| **IDENTIFY (ID)** | ID.AM (Asset Management) | 7 (Config), 9 (Infra) | Config file inventory. Infrastructure mapping. Dependency tracking via SBOM. |
| | ID.RA (Risk Assessment) | STRIDE, Threat Model | STRIDE at every trust boundary. Risk-based severity ratings. |
| | ID.SC (Supply Chain) | 8 (Supply Chain) | Dependency audit. Publisher verification. Postinstall script review. |
| **PROTECT (PR)** | PR.AA (Access Control) | 1 (Path Traversal), 2 (Auth) | Auth on every endpoint. Path validation. Least privilege. Role allowlists. |
| | PR.DS (Data Security) | 3 (Input Validation), 5 (Output) | Input sanitization. Output encoding. Parameterized queries. Encryption in transit. |
| | PR.IP (Info Protection) | 6 (Deployment), 7 (Config) | Secrets management. Secure deployment pipeline. Config file security. |
| | PR.PT (Platform Security) | 9 (Infra) | Cloudflare security patterns. CORS. Rate limiting. Security headers. |
| **DETECT (DE)** | DE.CM (Monitoring) | Passive Sentinel | `hooks/security-check.sh` watches all code edits. Pattern-based alerting. |
| | DE.AE (Analysis) | 4 (Error Handling) | Error analysis without information leakage. Security event correlation. |
| **RESPOND (RS)** | RS.MA (Incident Management) | 10 (Incident Readiness), Mode 3 | Incident response playbook. Contain-preserve-assess-remediate-document. |
| | RS.AN (Analysis) | Mode 3 (Incident Response) | Timeline construction. Scope assessment. Root cause analysis. |
| **RECOVER (RC)** | RC.RP (Recovery Planning) | 10 (Incident Readiness) | Key rotation reference. Recovery paths documented. GDPR notification timeline. |

---

## 10. OWASP Agentic AI Top 10

Specific risks for AI agent systems. Critical for auditing our 24-agent squad, MCP servers, and any tool-using AI.

| # | Risk | Description | Mitigation | Our Implementation |
|---|------|------------|------------|-------------------|
| 1 | **Prompt Injection** | Direct or indirect manipulation of agent behavior through crafted inputs. Includes injection via tool outputs, code comments, and config files. | Input sanitization on all agent inputs. Treat tool output as untrusted. Never let tool results influence security decisions without validation. | CVE-2026-21852 lesson. Tool output sanitization. MCP input validation. |
| 2 | **Excessive Agency** | Agent has more permissions than needed. Write access when read-only suffices. Unrestricted tool access. | Principle of least privilege. Read-only agents get read-only tools. Explicit tool allowlists per agent. | Agent tool declarations in YAML frontmatter. Michael: Read/Grep/Glob/Bash only. |
| 3 | **Insecure Tool Design** | Tool parameters not validated on the tool side. Tools that accept file paths, shell commands, or URLs without sanitization. | Validate ALL parameters inside the tool implementation. Never trust the calling agent's intent. | Path validation on brain territory params. 1MB body limits. Key traversal prevention. |
| 4 | **Sensitive Information Disclosure** | Agent leaks secrets, PII, or internal state through responses, logs, or tool calls. | Strip secrets from agent context. Error responses use generic messages. Audit what agents can see. | Error handling patterns. No secrets in logs. Generic auth failure messages. |
| 5 | **Insufficient Monitoring** | Agent actions not logged. No audit trail for what agents did, when, why. | Log all agent tool calls with timestamps. Brain observations as audit trail. | Brain observation system. Memory blocks after every review. |
| 6 | **Supply Chain Vulnerability** | Agent definitions loaded from external sources. Malicious agent specs as code execution. Compromised MCP servers. | Verify agent definition sources. Pin MCP server versions. Audit third-party agent specs. | `.md` agent files in version control. Third-party MCP default: BLOCK until verified. |
| 7 | **Insecure Output Handling** | Agent output rendered without sanitization. Agent generates code that's executed without review. | Sanitize all agent output before rendering. Code from agents goes through review pipeline. | Diagnosis-only architecture. Michael reports, June implements, Reeve reviews. |
| 8 | **Unauthorized Actions** | Agent performs actions beyond its scope. Agents escalating their own permissions. | Explicit permission boundaries per agent. No agent can modify its own definition. | Agent constraints in spec. "Michael does NOT write fixes." Enforced by tool allowlist. |
| 9 | **Denial of Service** | Agent triggers unbounded operations. Recursive tool calls. Resource exhaustion. | Collection size caps. Max hop limits on graph traversal. Timeout on all operations. CPU guards. | AI tool collection caps. BFS max hops + max nodes. Cloudflare 30s CPU limit guards. |
| 10 | **Lack of Accountability** | Cannot trace which agent did what. No attribution on agent actions. Plausible deniability. | Every agent action attributed with agent name. Commit messages include agent attribution. | `Co-Authored-By` on commits. Memory blocks tagged with agent name. Review headers identify agent. |

---

## 11. Compliance Framework Quick Reference

### SOC 2 Type II — Trust Service Criteria (Security)
| Control | Description | Our Coverage |
|---------|------------|-------------|
| CC6.1 | Logical and physical access controls | Auth on every endpoint. Role-based access. API key management. |
| CC6.2 | System credentials and auth mechanisms | JWT validation. OAuth with PKCE. Timing-safe comparison. |
| CC6.3 | Registration and authorization of new users | OAuth flow with state parameter. Hardcoded redirect URIs. |
| CC6.6 | System boundaries and external threats | STRIDE threat modeling. Trust boundary mapping. WAF. Rate limiting. |
| CC6.7 | Restricting data transmission | HTTPS enforced. CORS allowlists. CSP headers. |
| CC6.8 | Prevention of unauthorized software | Dependency audit. Postinstall script review. Lockfile integrity. |
| CC7.1 | Detection of unauthorized changes | Passive sentinel hook. Git-based change tracking. |
| CC7.2 | Monitoring for anomalies | Brain observation patterns. Error monitoring. |
| CC7.3 | Evaluation of detected events | Incident response playbook. Severity classification. |
| CC7.4 | Incident response procedures | Mode 3: Incident Response. Contain-preserve-assess-remediate-document. |
| CC8.1 | Change management processes | Agent pipeline: Eli → June → build check → review squad → Sawyer. |

### HIPAA — Technical Safeguards (§164.312)
| Safeguard | Requirement | Our Coverage |
|-----------|------------|-------------|
| Access Control (a)(1) | Unique user identification | JWT with user ID. OAuth identity verification. |
| Access Control (a)(3) | Automatic logoff | JWT expiration. Session timeout. |
| Access Control (a)(4) | Encryption and decryption | HTTPS in transit. At-rest encryption for PII if applicable. |
| Audit Controls (b) | Record and examine access | Brain observation audit trail. Security event logging. |
| Integrity Controls (c)(1) | Protect from improper alteration | Parameterized queries. Input validation. Lockfile integrity. |
| Transmission Security (e)(1) | Integrity controls in transit | HTTPS. Webhook signature verification. |
| Transmission Security (e)(2) | Encryption in transit | TLS on all endpoints. Cloudflare SSL. |

### PCI-DSS v4.0 — Key Requirements
| Requirement | Description | Our Coverage |
|------------|------------|-------------|
| 2.2 | Secure system configurations | Config file security checklist. No default credentials. Debug stripped in prod. |
| 3.4 | Protect stored cardholder data | Stripe handles card data. We never store card numbers. |
| 6.2 | Secure development practices | Security audit in deployment pipeline. Code review squad. |
| 6.3 | Security testing of custom code | Michael's 4 operating modes. Curl test patterns. Automated scanning. |
| 6.4 | Web application protection | CSP headers. CORS. Rate limiting. WAF managed rules. |
| 7.1 | Restrict access by business need | Least privilege. Role allowlists. Per-endpoint auth. |
| 8.3 | Strong authentication | MFA recommendation. Rate limiting on login. Account lockout. |
| 10.1 | Audit trail for system components | Brain observations. Security event logging. |
| 11.3 | Vulnerability management | CVE enrichment protocol. Dependency audit. Regular scanning. |
| 12.10 | Incident response plan | Mode 3: Incident Response. Key rotation reference. |

### GDPR — Article 32 (Security of Processing)
| Measure | Requirement | Our Coverage |
|---------|------------|-------------|
| (a) | Pseudonymization and encryption | HTTPS. At-rest encryption guidance. |
| (b) | Confidentiality, integrity, availability | Access control. Input validation. Error handling. Rate limiting. |
| (c) | Ability to restore access after incident | Key rotation reference. Recovery paths. Incident response playbook. |
| (d) | Regular testing and assessment | Security audit pipeline. 4 operating modes. Continuous sentinel. |
| Art. 33 | 72-hour breach notification | Documented in incident response playbook. |

---

## 12. CVE Enrichment Sources

Priority order for vulnerability intelligence:

| Source | Type | Access | Use Case |
|--------|------|--------|----------|
| **This file** (security-intel.md) | Curated, stack-specific | Local | First check. Our CVEs are contextualized to our stack with lessons learned. |
| **npm audit** | Dependency CVEs | `npm audit --json` | Every review. Automated. Covers direct + transitive dependencies. |
| **OSV.dev** | Open Source Vulnerability DB | `https://api.osv.dev/v1/query` | Cross-reference when npm audit misses something or for non-npm packages. |
| **GitHub Advisory Database** | GitHub's aggregated CVE DB | `gh api /advisories` or web | Comprehensive. Includes ecosystem-specific advisories. |
| **NVD (NIST)** | National Vulnerability Database | `https://nvd.nist.gov/` | Authoritative. Slower to update. Use for formal CVE details. |
| **Socket.dev** | Supply chain intelligence | Web/API | Real-time package monitoring. Reachability analysis. 70+ risk types. |

### Reachability Assessment
Not all CVEs are exploitable. Before escalating a dependency CVE:
1. Is the vulnerable function/module actually imported?
2. Is the vulnerable code path reachable from our usage?
3. Is the vulnerability exploitable in our deployment context (Workers vs Node.js vs browser)?
4. Rate: REACHABLE (confirm exploit path), POTENTIALLY REACHABLE (can't rule out), NOT REACHABLE (vulnerable code unused)

---

## 13. SBOM (Software Bill of Materials) Reference

### What to Capture
- All direct dependencies with exact versions
- All transitive dependencies (from lockfile)
- License type for each dependency
- Known vulnerabilities per dependency
- Last publish date (staleness indicator)
- Maintainer count (bus factor)

### Generation Commands
```bash
# NPM — basic SBOM
npm ls --json --all > sbom-npm.json

# CycloneDX format (industry standard)
npx @cyclonedx/cyclonedx-npm --output-format json > sbom-cyclonedx.json

# SPDX format
npx spdx-sbom-generator -o sbom-spdx.json
```

### Risk Indicators
| Indicator | Threshold | Severity |
|-----------|-----------|----------|
| Known CRITICAL CVE | Any | CRITICAL |
| Known HIGH CVE | Any | HIGH |
| Abandoned (no update >2 years) | Any | MEDIUM |
| Single maintainer + >10K weekly downloads | Any | MEDIUM |
| Copyleft license in proprietary code | Any | HIGH (legal) |
| Postinstall script | Any | Requires manual review |
| First published <30 days ago | Any | MEDIUM (typosquat risk) |
| Name similarity to popular package | >80% | HIGH (typosquat risk) |
