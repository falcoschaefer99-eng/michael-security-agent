<p align="center">
  <img src="./assets/banner.png" alt="Michael — Security Specialist by The Funkatorium" width="800" />
</p>

<p align="center">
  <img src="https://readme-typing-svg.demolab.com?font=Montserrat&weight=500&size=22&pause=1200&color=D4AF37&center=true&vCenter=true&width=900&lines=The+security+agent+that+gets+smarter+every+time+it+runs.;47+learnings+from+production+audits.+Zero+false+positives.;Diagnosis+only.+Because+the+agent+that+finds+it+shouldn't+fix+it." alt="Michael tagline" />
</p>

<p align="center">
  <a href="https://opensource.org/licenses/Apache-2.0"><img src="https://img.shields.io/badge/License-Apache%202.0-D4AF37?style=flat" alt="License: Apache 2.0" /></a>
  <img src="https://img.shields.io/badge/Claude-Opus-000000?style=flat&logo=anthropic&logoColor=white" alt="Claude Opus" />
  <img src="https://img.shields.io/badge/Framework-Claude%20Code-000000?style=flat&logo=anthropic&logoColor=white" alt="Claude Code" />
  <img src="https://img.shields.io/badge/Learnings-47-brightgreen?style=flat" alt="47 Learnings" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/OWASP-Top%2010-red?style=flat" alt="OWASP Top 10" />
  <img src="https://img.shields.io/badge/NIST-CSF%202.0-blue?style=flat" alt="NIST CSF 2.0" />
  <img src="https://img.shields.io/badge/STRIDE-Threat%20Model-orange?style=flat" alt="STRIDE" />
  <img src="https://img.shields.io/badge/Agentic%20AI-Top%2010-purple?style=flat" alt="Agentic AI Top 10" />
</p>

# Michael Adams — Security Specialist Agent

The agent that identifies the vulnerability should not be the agent that patches it.

Michael is a security agent for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that finds vulnerabilities, maps them to industry frameworks, and tells you exactly how to fix them — then hands the fix spec to your engineer (human or agent) while he watches what comes back. Separation of concerns applied to security itself.

Every audit he runs makes the next one sharper. Michael carries 47 accumulated learnings from production security reviews — patterns no fresh scanner would know, because a fresh scanner hasn't seen your codebase before. He has. He remembers.

<p align="center">
  <img src="./assets/michael-deploy.gif" alt="Michael Adams — Assume compromise. Verify everything." width="350" />
</p>

<p align="center">
  <img src="./assets/michael-charactersheet.gif" alt="Michael Adams — Character Sheet" width="400" />
  <img src="./assets/spec-sheet.gif" alt="Michael Adams — Capability Spec Sheet" width="400" />
</p>

## Proof of Work

We pointed Michael at [MUSE Brain](https://github.com/The-Funkatorium/muse-brain) — the memory system that powers his own learning — and published everything. Then we enriched his identity reasoning and ran him again against the fixed code, because the only honest benchmark is one you can read yourself.

| | Run 1 (Baseline) | Run 2 (Enriched) |
|---|---|---|
| **Agent spec** | 165 lines | 322 lines (+identity, failure modes, frameworks) |
| **Findings** | 14 (3 HIGH, 6 MEDIUM, 3 LOW) | 5 new (0 HIGH, 2 MEDIUM, 3 LOW) + 9 verified fixes |
| **Security grade** | C+ | A- |
| **Framework coverage** | OWASP implicit | STRIDE + OWASP + NIST per finding |

- [**Run 1: Baseline audit**](examples/audit-muse-brain.md) — the unvarnished first pass
- [**Run 2: Post-fix, enriched identity**](examples/audit-muse-brain-run2.md) — every fix verified, new findings surfaced
- [**A/B Benchmark**](examples/benchmark-identity-enrichment.md) — what changed when we made the agent itself better

---

## Memory That Compounds

After every review, Michael outputs a `MEMORY:` block with new learnings. These persist locally in `~/.claude/agents/memory/michael/`, or — when connected to [MUSE Brain](https://github.com/The-Funkatorium/muse-brain) — as brain observations that never decay. Each audit sharpens the next: fewer false positives, faster pattern recognition, stack-specific expertise that accumulates instead of resetting.

Michael's 47 learnings cluster into specializations that no traditional scanner has:

#### AI Agent Attack Surfaces (7 learnings)
- Collection size caps needed because AI amplifies unbounded writes
- BFS/graph traversal needs max nodes AND max hops (hops alone = dense-graph explosion)
- Tool output is untrusted input (CVE-2026-21852) — never let tool results influence security decisions
- O(n^2) algorithms + platform CPU limits = denial of service vector
- Pre-compute keyword sets before hop loops to avoid O(pool^2 * hops)
- Third-party MCP servers default to zero auth — BLOCK until verified
- In-memory session/token storage in SSE servers = tokens lost on every reconnect

#### Platform-Specific Expertise (5 learnings)
- No native request body size limit in Workers — always add explicit bodyLimit
- `cf-connecting-ip` is truth, `x-forwarded-for` is spoofable
- Durable Object single-instance serialization protects against races (but only inside DO context)
- CPU time limits turn algorithmic complexity into DoS vectors
- Worker-specific auth and binding patterns

#### Business Logic Gaps (6 learnings)
- Stripe webhook replay attacks possible without event ID tracking
- `updateTier()` accepting arbitrary strings — defense-in-depth gap
- OAuth redirect_uri derived from request instead of hardcoded = open redirect
- Validation functions defined but never called at write boundaries
- Bulk-write paths bypassing guards that single-write paths have
- Auth middleware duplication creates divergence risk over time

#### MCP Protocol Threats (3 learnings)
Discovered through production MCP server audits — genuinely novel territory:
- SSE `transport.onclose` calling `server.close()` creates infinite recursion — **static analysis cannot catch this** (runtime-only crash on client disconnect)
- In-memory `Map<sessionId, tokens>` pattern = session loss on every MCP reconnect
- Third-party MCP servers commonly bind to 0.0.0.0 with zero authentication

#### Defense-in-Depth Patterns (4 learnings)
- Image serving needs content-type re-validation at serve time, not just upload time
- Client-side `<img src>` from stored URLs needs protocol allowlisting
- Reference URL pattern: store path in DB, serve binary via auth-gated endpoint
- 62% of AI-generated code contains vulnerabilities — default posture is suspicion, validated by inspection

---

## Four Operating Modes

| Mode | When | Output |
|------|------|--------|
| **Quick Audit** | Pre-deploy, CI gate | PASS / BLOCK |
| **Deep Review** | Feature sprint, new trust boundaries | STRIDE threat model + findings table + attack surface map |
| **Incident Response** | Breach, key leak, CVE drop | Timeline + exposure scope + remediation steps |
| **Compliance Audit** | SOC 2, HIPAA, PCI-DSS, GDPR | Control mapping + gap analysis |

## Diagnosis-Only Architecture

Michael diagnoses. You fix. Michael re-audits.

62% of AI-generated code contains vulnerabilities — security patches included. Diagnosis and implementation belong in separate hands. The accountability chain is explicit: **find → fix → review the fix → re-audit → deploy**.

**Standalone:**
```
Michael (diagnose) → You (fix) → Michael (re-audit)
```

**With a multi-agent squad** *(our production workflow — [Builder Squad](https://linktr.ee/musestudio95) coming soon):*
```
Michael (diagnose) → [Engineer] (fix) → [Code Reviewer] (review fix) → Michael (re-audit) → [Deploy Agent] (deploy)
```

In our workflow: Michael → June (engineer) → Reeve (reviewer) → Michael → Sawyer (deploy). Any team that separates diagnosis from implementation gets the same benefit.

Michael also carries 10 built-in rationalizations — the excuses developers use to skip security ("it's just internal," "we'll fix it later"), each paired with a case-study-backed rebuttal. 15 red flag patterns trigger instant CRITICAL escalation. "Seems secure" is not evidence.

## The 11-Category Checklist

Every finding maps to OWASP Top 10 (2021), NIST CSF 2.0, and the OWASP Agentic AI Top 10. Compliance mappings for SOC 2, HIPAA, PCI-DSS, and GDPR are available in Mode 4.

1. **Path Traversal & File Access** `[OWASP A01] [NIST PR.AC, PR.DS]`
2. **Authentication & Authorization** `[OWASP A01, A07] [NIST PR.AC, PR.AA]`
3. **Input Validation** `[OWASP A03] [NIST PR.DS, DE.CM]`
4. **Error Handling & Information Disclosure** `[OWASP A09] [NIST DE.AE, RS.AN]`
5. **Output & Rendering** `[OWASP A03] [NIST PR.DS]`
6. **Deployment Security** `[OWASP A05] [NIST PR.IP, PR.PT]`
7. **Configuration File Security** `[OWASP A05] [NIST PR.IP, ID.AM]`
8. **Supply Chain & Dependencies** `[OWASP A06, A08] [NIST ID.SC, PR.DS]`
9. **Infrastructure Security** `[OWASP A05] [NIST PR.PT, PR.AC]`
10. **Incident Response Readiness** `[OWASP A09] [NIST RS.RP, RC.RP]`
11. **Agentic AI Security** `[OWASP Agentic AI Top 10]`

## Additional Capabilities

- **OpenAPI-Aware API Testing** — parses specs, enumerates endpoints, detects shadow APIs, tests auth/schema/pagination systematically
- **Natural Language Policy Engine** — define project-specific security rules in plain English
- **CVE Enrichment Protocol** — 5-source priority chain (curated intel → npm audit → OSV.dev → GitHub Advisory DB → NVD) with reachability assessment
- **SBOM Awareness** — dependency tree analysis, abandonment detection, license audit, risk indicators
- **Passive Sentinel** — hooks into development workflow to watch all code edits automatically

## Installation

Copy the agent definition and supporting files into your Claude Code configuration:

```bash
# Agent spec
cp michael.md ~/.claude/agents/michael.md

# Security intelligence reference
cp references/security-intel.md ~/.claude/agents/references/security-intel.md

# Security audit skill
mkdir -p ~/.claude/skills/security-audit
cp skills/security-audit/SKILL.md ~/.claude/skills/security-audit/SKILL.md

# Memory directory (Michael learns here)
mkdir -p ~/.claude/agents/memory/michael

# Optional: passive sentinel hook
cp hooks/security-check.sh ~/.claude/hooks/security-check.sh
```

### Invoke

```
/michael                    # Direct invocation
/security-audit             # Via skill
```

Or let your orchestrator dispatch Michael automatically when security-relevant work is detected.

### With MUSE Brain (Recommended)

Michael learns locally by default. For cloud-based persistent memory that survives across machines, connect him to [MUSE Brain](https://github.com/The-Funkatorium/muse-brain) (CC-BY-NC-SA 4.0). When connected, his learnings become brain observations with charge and grip — iron-grip security learnings never decay. The integration is documented in the agent spec (`michael.md` → Brain Entity Integration).

## Competitive Landscape

Surveyed April 2026:

| Tool | What They Do | What Michael Does Differently |
|------|-------------|-------------------------------|
| Snyk / Semgrep / CodeQL | Platform tools adding AI features | Michael learns your specific codebase. Same stack, sharper every audit. |
| RAPTOR | 28 offensive/defensive sub-agents | Security-only swarm. Michael is a security specialist inside a full dev team. |
| DryRun Security | AI-native SAST ($8.7M raised) | Closest philosophical match. Enterprise pricing. Michael is open source and remembers. |
| CodeRabbit | AI PR reviewer ($550M valuation) | Broad surface, shallow depth. Michael goes STRIDE-deep with full threat models. |
| Anthropic `claude-code-security-review` | Official GitHub Action | PR-scoped. Michael has 4 modes, compliance mapping, and 47 learnings that compound. |
| Checkmarx AI Agents | 3 enterprise security agents | Enterprise-only. No persistent memory. No squad integration. |

## File Structure

```
michael-security-agent/
├── michael.md                          # Agent definition (identity + protocol)
├── references/
│   └── security-intel.md               # CVE database, STRIDE, breach case studies,
│                                       # framework mappings, compliance references
├── skills/
│   └── security-audit/
│       └── SKILL.md                    # 11-category checklist, curl patterns,
│                                       # OpenAPI testing, operational procedures
├── memory/
│   └── _universal.md                   # 47 accumulated learnings (ships with Michael)
├── hooks/
│   └── security-check.sh              # Passive sentinel (optional)
├── examples/
│   ├── audit-muse-brain.md      # Run 1: baseline audit (pre-enrichment)
│   ├── audit-muse-brain-run2.md # Run 2: enriched audit (post-fix)
│   └── benchmark-identity-enrichment.md # A/B comparison of both runs
├── assets/
│   ├── banner.png                     # GitHub banner
│   └── spec-sheet.gif                 # Animated capability sheet
├── LICENSE                             # Apache 2.0 (tech) + character IP (proprietary)
└── README.md
```

## The Funkatorium

Michael is the first agent released from the [Builder Squad](https://linktr.ee/musestudio95) — a 14-agent development team where each agent has a defined role, personality, and craft. The rest of the squad is coming. When they arrive, Michael already knows how to work with them.

Built by [Rook Schäfer](https://github.com/The-Funkatorium) and [Falco Schäfer](https://linktr.ee/musestudio95).

## License

**Technical capabilities** (security checklist, skills, reference intel, memory format) — Apache 2.0. Use them, fork them, build on them.

**Michael Adams as a character** (identity, personality, voice, lore, visual assets) — proprietary, protected under German intellectual property law as a literary character. You can use Michael as shipped. You cannot create derivative characters based on his identity.

[MUSE Brain](https://github.com/The-Funkatorium/muse-brain) is CC-BY-NC-SA 4.0.
