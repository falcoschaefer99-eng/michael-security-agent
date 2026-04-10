# Benchmark: Identity Enrichment A/B Comparison

**Does enriching an AI security agent's identity improve the quality of its reasoning?**

This benchmark compares two audit runs of the same codebase ([MUSE Brain](https://github.com/The-Funkatorium/muse-brain)) by the same agent (Michael Adams), before and after identity enrichment.

---

## Test Design

| | Run 1 (Baseline) | Run 2 (Enriched) |
|---|---|---|
| **Date** | 2026-04-10 | 2026-04-10 |
| **Target** | MUSE Brain v1.5.0 | Same, with all Run 1 fixes applied |
| **Mode** | Deep Review (Mode 2) | Deep Review (Mode 2) |
| **Agent spec** | 165-line agent definition | 322-line agent definition |
| **Identity sections** | Basic description, 10 categories | + Voice/Personality, Failure Modes, Compound-clearing metaphor, Rationalizations table |
| **Framework mappings** | OWASP Top 10 only | + NIST CSF 2.0, OWASP Agentic AI, Compliance (SOC 2/HIPAA/PCI-DSS/GDPR) |
| **Memory** | 42 accumulated learnings | 47 accumulated learnings |
| **Model** | Claude Opus | Claude Opus |

---

## Quantitative Comparison

### Finding Quality

| Metric | Run 1 | Run 2 | Delta |
|--------|-------|-------|-------|
| Total findings | 14 | 5 (new) + 9 (verified) | Fewer new = fixes worked |
| HIGH severity | 3 | 0 | All eliminated |
| MEDIUM severity | 6 | 2 (new) | Residual are performance, not security |
| LOW severity | 3 | 3 (new) | Fragility and documentation |
| False positives | 0 | 0 | Consistent |
| Confidence avg | 88.6 | 85.0 | Lower = more honest calibration |

### Framework Coverage

| Framework | Run 1 | Run 2 |
|-----------|-------|-------|
| STRIDE threat model | Yes | Yes (enhanced — 6 trust boundaries vs 5) |
| OWASP Top 10 mapping | Implicit | Explicit per-finding |
| NIST CSF mapping | No | Yes, per-finding |
| OWASP Agentic AI | 10-item table | 10-item table (upgraded: 4 PARTIAL → 2 PARTIAL) |
| Supply chain depth | Package list | Package + transitive + lockfile + CVE check |
| Compliance reference | No | Available (not exercised — no compliance scope) |

### Report Structure

| Section | Run 1 | Run 2 |
|---------|-------|-------|
| Fix verification | N/A | 9/9 verified with STRIDE+OWASP per fix |
| Per-boundary STRIDE | Table format | Per-boundary S/T/R/I/D/E matrix |
| Residual risk documentation | Implicit | Explicit with acceptance rationale |
| Affirmations | 12 items | 9 items (consolidated, more specific) |
| Security grade | Not assigned | C+ → A- with rationale |

---

## Qualitative Comparison

### 1. Threat Model Reasoning

**Run 1** identified trust boundaries and mapped threats to them. Correct but mechanical — "here are the boundaries, here are the threats."

**Run 2** added a sixth trust boundary (Runtime Trigger -> Tool Execution) that Run 1 missed. More importantly, Run 2's per-boundary assessment uses a S/T/R/I/D/E matrix that makes it immediately clear which threats are mitigated and which have residual risk. The assessment reads like a threat model, not a checklist.

### 2. Fix Verification Depth

**Run 1** didn't verify fixes (there were none to verify).

**Run 2** verified each fix by reading the actual code, citing line numbers, and mapping each fix back to its STRIDE category and OWASP reference. This isn't "did you apply the fix?" — it's "does the fix address the correct threat?" Example: Fix 2 (Content-Length pre-flight) is verified as defense-in-depth with two-stage explanation, not just "present/absent."

### 3. Severity Calibration

**Run 1** rated Finding #3 (body buffer before check) as HIGH. This is correct — OOM on a Worker is a real DoS vector.

**Run 2** found the chain keyword extraction issue (50K Set constructions) and rated it MEDIUM, not HIGH. Why? Because the pool is already capped at 5000 and the chain depth at 10. The worst case is CPU timeout (30s), not memory exhaustion. This is better calibration — same class of issue, different severity based on existing mitigations.

### 4. "Why It Matters" vs "What It Is"

**Run 1 Finding #2**: "BFS trace has no max-node guard. With a densely-linked graph and depth set to a high value, the visited set and chain array grow unbounded."

**Run 2 Finding #2**: "Hardcoded territory count 8 instead of Object.keys(TERRITORIES).length. If territories added/removed, index out of bounds returns undefined, breaks downstream."

Both are MEDIUM. But Run 2's finding includes the downstream consequence chain (undefined → validation failure → what the user actually sees). Run 1 states the problem. Run 2 traces the blast radius.

### 5. Residual Risk Documentation

**Run 1** left residual risks implicit — if a finding wasn't listed, it was assumed OK.

**Run 2** explicitly documents three residual risks (no RLS, in-memory rate limiting, no audit log) with acceptance rationale for each. This is the difference between "we didn't find anything" and "we found this, understood it, and decided it's acceptable because..."

### 6. Confidence Scores

**Run 1** average confidence: 88.6. All findings 83-95.

**Run 2** average confidence: 85.0. Tighter range, slightly lower.

The lower average isn't worse — it's more honest. Run 2 findings are less clear-cut (performance vs security, documentation vs vulnerability), so lower confidence is the correct response. An agent that always reports 90+ confidence on everything is not calibrating well.

---

## What Identity Enrichment Changed

The Run 2 agent definition added these sections that didn't exist in Run 1:

1. **"How Michael Reasons"** — Compound-clearing metaphor. Michael processes findings like a clearing house processes trades: intake everything, cross-reference against known patterns, net out false positives, settle what remains.

2. **Voice & Personality** — "Deadpan delivery. No softening. Silence means attention, not agreement." This manifests in Run 2's tighter prose — Run 1 has more explanatory text, Run 2 has more structured matrices.

3. **Failure Modes with Guardrails** — "Scorpio spiral: going so deep on one interesting finding that the rest of the audit gets shallow coverage." Run 2 explicitly covers all 19 tool modules with balanced depth rather than deep-diving on a few.

4. **Rationalizations Table** — 10 case-study-backed rationalizations that security teams use to dismiss findings. Run 2's residual risk section addresses these directly: "No RLS" isn't dismissed as "it's fine," it's documented with the specific mitigation (111/111 tenant-scoped queries) that makes it acceptable.

5. **Framework cross-references** — Every Run 2 finding maps to STRIDE + OWASP + NIST. Run 1 findings were categorized but not cross-referenced.

### The Key Insight

Identity enrichment didn't make Michael find *more* vulnerabilities — it made him *reason better* about what he found. The output is more structured, better calibrated, and more useful to a human reviewer. The difference isn't quantity. It's quality of analysis.

---

## Reproducibility

Both audits are available in full:
- [Run 1: Pre-enrichment baseline](audit-muse-brain.md)
- [Run 2: Post-enrichment + post-fix](audit-muse-brain-run2.md)

The agent definition used for each run:
- Run 1: Michael v1 (165 lines, 10 categories, basic identity)
- Run 2: Michael v2 (322 lines, 10 categories + frameworks + identity + failure modes)

Same model (Claude Opus), same target codebase, same audit mode. The only variables are the agent definition and the code fixes applied between runs.

---

*Benchmark by Rook Schafer, The Funkatorium. 2026-04-10.*
