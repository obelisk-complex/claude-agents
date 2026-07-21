# plan-auditor structural conformance report (round 1)
**Target:** /media/owner/Workspace/claude-agents/agents/plan-auditor.md
**Checklist:** /media/owner/Workspace/claude-agents/AGENT_CHECKLIST.md
**Started:** 2026-07-21T19:03:44Z
**Status:** COMPLETE

**Scope:** Round 1 of rotating fleet audit - structural conformance to
AGENT_CHECKLIST.md only. Domain-coverage and token-waste judgments are
out of scope for this round; deferred sections are marked explicitly
below rather than silently passed.

## Findings
<!-- appended one at a time, as found -->

### [MEDIUM] Em-dashes in all 8 new bullets violate the file's own style rule
- **Situation:** `agents/plan-auditor.md` lines 105-112, the 8 bullets added
  2026-07-21 under **Risk blind spots** (stdout IPC fragility, schema version
  assertion missing, timezone/freshness semantics, dedup across system
  boundary, backpressure/volume controls, vite proxy production limitation,
  AGPL combined-work risk, variant registration contradiction).
- **Behaviour observed:** Every one of the 8 new bullets uses `**Label** —
  text` with an em-dash. `AGENT_CHECKLIST.md` Style rules state: "Use single
  hyphens for dashes in prose, never em-dashes or double hyphens." Confirmed
  via `grep "—" agents/plan-auditor.md`: all 8 hits are on these lines; there
  is no em-dash anywhere else in the file's other 220 lines (pre-edit body
  was clean).
- **Impact:** A checklist rule stated as a hard "never" is violated 8 times
  in a single edit. Low functional impact on the agent's output (this is
  prose in the definition, not agent-generated text) but it is a confirmed,
  mechanical violation of an explicit rule and the kind of thing that spreads
  if copied as a template for future bullets.
- **Fix:** Replace `—` with a comma, colon, or period in all 8 lines, e.g.
  `**stdout IPC fragility.** Plans that use stdout...`.

### [MEDIUM] New bullets use a bold-label format not used anywhere else in the file
- **Situation:** Same 8 lines (105-112), within the `**Risk blind spots:**`
  sub-list of `## Core Workflow` step 4.
- **Behaviour observed:** The file has 61 bullet items under `## Core
  Workflow`; the only bold text among them is 7 sub-category headers
  (`**Missing steps:**`, `**Dependency and ordering:**`, etc. — confirmed via
  `grep "^   \*\*"`). No individual list item anywhere else in the file leads
  with a bold label. The pre-existing items in this same `Risk blind spots`
  list use a "topic phrased as a question, then explanation, then optional
  `Flag ...` instruction" pattern (e.g. "Idempotent steps? Can the executor
  safely re-run..."; "Reversible or irreversible? Irreversible steps
  (...)... Flag any irreversible step whose only stated recovery is 'roll
  back'."). The 8 new items instead open `**Bold Label** — text. Flag ...`,
  introducing a new micro-pattern mid-list.
- **Impact:** The list now reads as two authorial voices spliced together.
  Not a functional defect for the agent (Claude reads bold text fine either
  way) but a structural voice inconsistency the checklist's underlying goal
  of consistent format/voice — implicitly asks a reviewer to catch.
- **Fix:** Reformat the 8 new bullets to match the surrounding
  question-or-topic-then-explanation pattern and drop the bold label, e.g.
  "Stdout used as IPC? Child process spawns and pipe parsing are vulnerable
  to any console.log... Flag plans that use per-call spawns instead of
  long-lived sidecars with framed protocols."

### [MEDIUM] Risk blind spots sub-list has grown to 17 items, roughly double every sibling category
- **Situation:** `## Core Workflow` step 4 "Audit for gaps" has 7 named
  sub-categories (Missing steps, Dependency and ordering, False or unstated
  assumptions, Inconsistencies, Efficiency problems, Risk blind spots,
  Estimate bias).
- **Behaviour observed:** `Risk blind spots` now holds 17 bullet items
  (confirmed by count); the other 6 categories range roughly 5-10 items
  each. The 8-item addition went entirely into this one category rather than
  being distributed by topic (e.g. schema-version-assertion and
  version-compatibility both concern the same axis as the existing
  "Version compatibility stated and verifiable?" bullet under **False or
  unstated assumptions**, line 76, but landed in Risk blind spots instead).
- **Impact:** One category is now structurally dominant, which works against
  scanability during an audit pass and signals the section absorbed a batch
  of findings by convenience (all were "risks") rather than by taxonomy fit.
  This is the kind of category-shape drift the checklist's "leave no trash /
  don't invent abstractions" spirit and this round's brief both flag as
  worth surfacing even though full domain-coverage judgment is out of scope
  this round.
- **Fix:** Consider splitting the new items across existing categories by
  what they actually check (e.g. schema-version-assertion and
  timezone/freshness under False-or-unstated-assumptions, AGPL/variant
  registration under Inconsistencies) rather than defaulting all 8 into
  Risk blind spots.

### [MEDIUM] File crossed the established 15KB threshold in this edit
- **Situation:** `agents/plan-auditor.md` as a whole.
- **Behaviour observed:** `git show HEAD:agents/plan-auditor.md | wc -c` =
  14709 bytes (pre-edit); current file = 16836 bytes. The 8-bullet addition
  (8 insertions per `git diff --stat`) is the entire size delta and pushed
  the file from just under to just over the 15KB mark. Per this auditor's
  own memory (`feedback_scoped_round_audits.md`, prior finding), a body over
  15KB is treated as a MEDIUM on its own; plan-auditor is now the 4th
  largest of the fleet's ~30 agent files, behind only
  video-script-copywriter, requirements-auditor, conformance-auditor,
  seo-auditor and copywriter (all of which are markedly larger, 17-51KB).
- **Impact:** Every added line raises per-invocation prompt cost and dilutes
  attention across a longer instruction set; crossing an established
  threshold in a single edit is a signal worth surfacing even though full
  token-waste judgment is explicitly out of scope for this round.
- **Fix:** No action required this round beyond flagging; a token-reduction
  round should look at whether the 8 new items (or older, more
  project-agnostic items) can be tightened.

### [LOW, UNCERTAIN] Several new bullets read as drawn from one specific project rather than generalised
- **Situation:** Lines 107-112, specifically the Timezone/freshness
  semantics (RSS feeds), Backpressure/volume controls (500+ feeds,
  thousands of items, LLM bills), Vite proxy production limitation, AGPL
  combined-work risk, and Variant registration contradiction bullets.
- **Behaviour observed:** None of the 8 hardcode a literal path or project
  name, so they do not literally break the checklist's "no hardcoded
  paths, frameworks, or project names" style rule. But taken together
  (RSS feeds + submodule + AGPL + variant/plugin system with no runtime
  registration API + vite dev proxy) they describe a coherent, specific
  system rather than generalised planning principles, in a way none of the
  file's other 53 bullets do.
- **Impact:** Uncertain. These could be genuinely generalisable failure
  modes (stdout-as-IPC and vite-dev-proxy-in-prod, for instance, apply
  broadly) captured via a specific incident, which is exactly how good
  checklist items are usually born. Or the AGPL/submodule/variant cluster
  specifically could be narrow enough that a plan-auditor run against an
  unrelated codebase gets no value from 3-4 of the 8 lines. This is a
  domain-coverage judgment call the brief scopes out of this round; noting
  it here as directed uncertainty rather than a verdict.
- **Fix:** Not proposing one this round; flag for the domain-coverage round
  to assess whether the AGPL/submodule/variant-registration trio
  generalises or should be trimmed/rephrased.

### [LOW, UNCERTAIN] Output Format template has no standalone 1-2 sentence Summary/assessment section
- **Situation:** `## Output Format` template, `agents/plan-auditor.md` lines
  172-207.
- **Behaviour observed:** `AGENT_CHECKLIST.md` under Output format requires
  "Summary section (1-2 sentence assessment)". plan-auditor's template opens
  with a `**Findings:** CRITICAL: N | HIGH: N | ...` tally line followed by
  `### Plan Intent` (2-3 sentences describing the plan, not an assessment of
  the audit's verdict). `code-auditor.md`'s template (the closest sibling
  audit agent) has an explicit `## Summary\n[1-2 sentence overall
  assessment]` line that plan-auditor's does not.
- **Impact:** Uncertain whether this is a real gap or an accepted
  house-style divergence: `blind-spot-auditor.md`'s template has the same
  shape (an "Agent Intent" restatement, no separate assessment line), so
  this may be an established pattern for audit agents whose subject is a
  document rather than code, not a plan-auditor-specific defect. Flagging
  per the brief's instruction to report uncertain findings explicitly
  rather than omit them.
- **Fix:** If confirmed as a genuine gap (not house style), add a one-line
  `**Assessment:**` under the findings tally, e.g. "Plan is broadly sound
  but has N Critical gaps in rollback coverage."

### [LOW, UNCERTAIN] Guiding Principles cross-fleet list omits 2 of the checklist's standard principles
- **Situation:** `## Guiding Principles` → `Cross-fleet:` block, lines
  218-227.
- **Behaviour observed:** `AGENT_CHECKLIST.md`'s Guiding Principles section
  lists 10 numbered items (text says "9 standard principles" — a
  discrepancy in the checklist document itself, out of scope to fix here).
  plan-auditor's cross-fleet block carries 8 of the 10: Warnings are errors,
  Do the harder analysis, Leave no trash, Fix all severities, Verify before
  trusting assumptions, Test what you change, Don't invent abstractions,
  Secure by default. Missing: #4 "Comment only where the code doesn't
  reveal the decision" and #9 "Prefer the native tool over a workaround."
- **Impact:** Uncertain whether this is plan-auditor-specific or fleet-wide:
  `code-auditor.md` (a code-writing agent, where #4 applies most directly)
  also omits #9 "Prefer the native tool over a workaround" from its own
  Guiding Principles, suggesting #9 postdates most of the fleet's principle
  lists. #4 is plausibly not adapted for plan-auditor because it doesn't
  write code — `blind-spot-auditor.md` (another non-code-writing audit
  agent) also has no adapted equivalent of #4. This looks like an
  established omission pattern for non-code-writing audit agents rather
  than a plan-auditor defect, but the checklist's literal text says "all
  agents must include the 9 [sic] standard principles, adapted for the
  domain" with no carve-out, so flagging rather than silently passing it.
- **Fix:** If confirmed as a real gap, adapt #9 for plan-auditor as
  something like "Prefer the plan's own stated tooling over inventing a new
  verification method" and #4 as "Note only what the plan doesn't already
  justify, not restate obvious intent."

## Verified OK
<!-- appended as checked -->

- **Frontmatter parses and all required fields present:** `name`,
  `description` (folded scalar, 1 sentence, concrete trigger), `tools`,
  `disallowedTools`, `permissionMode`, `model`, `maxTurns`, `memory`,
  `color`. Both `---` fences present, no broken indentation or unclosed
  quotes.
- **`disallowedTools: Write, Edit`** present, as required on every `plan`
  agent, and matches `permissionMode: plan`.
- **`tools:` matches usage:** Grep, WebSearch, WebFetch are each explicitly
  invoked in the body (step 5). Read/Glob are implicit-but-standard for a
  file-reading auditor; no unused or foreign tool listed.
- **`model: opus`** matches `docs/model-tiers.tsv` row `plan-auditor  opus`,
  and fits the checklist's opus criterion ("deliverable is what is absent")
  — plan-auditor's job is finding gaps.
- **`color: "#0ea5e9"`** has no collision with any other agent file in
  `agents/*.md`.
- **`effort: high`** is not an AGENT_CHECKLIST.md-documented field but is
  used consistently by 17 other agent files fleet-wide; not a
  plan-auditor-specific issue.
- **`isolation: worktree` correctly absent** — plan-auditor is read-only
  (disallowedTools blocks Write/Edit), so the write-capable-agent
  requirement doesn't apply.
- **`mcpServers` correctly absent** — body does not reference context7,
  playwright, or any other external API needing an MCP server.
- **No `## Report file` section, correctly absent** — plan-auditor's
  `tools:` has neither `Write` nor `Edit`, so per
  `REPORT_PROTOCOL.md`'s capability gate the section would be inert if
  present. Consistent with sibling audit agents `code-auditor.md` and
  `blind-spot-auditor.md`, which are also plan-mode/read-only and also
  carry no `## Report file` section.
- **Memory loop present and domain-specific**, both read phase ("prior
  audit findings, recurring failure patterns... external-dependency lead
  times, project constraints that invalidated past plans") and write phase
  ("new failure patterns, verified/falsified assumptions, rollback
  outcomes, estimate accuracy") — not generic boilerplate.
- **Scope boundary present and correctly placed:** the `Delegate:` line
  sits after the memory instruction and before the first workflow section
  (`## Core Workflow`), per checklist. All 4 delegate targets exist as
  registered agent files: `migration-planner.md`, `code-auditor.md`,
  `ci-auditor.md`, `dependency-auditor.md` (confirmed via `ls agents/`).
- **"Prior findings in a brief" section** present, positioned consistent
  with the same section in `blind-spot-auditor.md` and `plan-audit-loop.md`
  (also edited 2026-07-21 per `git status`), indicating a coherent
  fleet-wide convention rather than a one-off.
- **Core Workflow: numbered steps with bold action verbs**, 7 steps,
  fail-fast prerequisite check present in step 1 ("Confirm a plan exists...
  If nothing is provided or the input is too vague, stop and say so").
  Language/ecosystem-specific tool lists and missing-infrastructure
  handling are not applicable to plan-auditing (no code language, and step
  1's "stop and say so" is the missing-infrastructure analogue) — not a
  gap.
- **`## Verification` section present**, immediately before `## Output
  Format`, with concrete 4-point instructions (genuinely absent, in scope,
  substantiated, actionable) and an explicit "remove findings that are
  speculative, redundant... or outside scope" instruction, satisfying the
  audit-agent self-verification requirement.
- **Output format is a fenced code block**; per-finding fields (severity,
  affected step, issue, impact, evidence, suggested fix) meet and exceed
  the checklist's minimum (severity/location/issue/fix); `Assumptions
  Verified` / `Assumptions Unverifiable` / `Plan Strengths` sections are a
  reasonable domain adaptation of the checklist's "Verified OK" and
  "acknowledge strengths" requirements; template fields match what step 3
  (Map the structure) and step 6 (severity table) produce.
- **Humane prompting gate: clean.** `grep -rniE
  "hostile|aggressive critic|adversar" agents/plan-auditor.md` returns no
  hits.
- **No pre-existing em-dashes.** Confirmed the em-dash violation (see
  Findings) is isolated to the 8 new lines; the rest of the file was
  already clean.
- **No exact duplicate among the 8 new bullets**, against each other or
  against any of the file's other 53 pre-existing bullets. One moderate
  thematic overlap noted (Findings: bloat item) between the new "Schema
  version assertion missing" and the existing "Version compatibility
  stated and verifiable?" (line 76), but they check different things
  (design-time claim vs runtime assertion mechanism) and are not
  duplicates.

## Completion

**Status:** COMPLETE
**Finding tally:** MEDIUM: 4 | LOW (UNCERTAIN): 3 | CRITICAL: 0 | HIGH: 0

No files were edited by this audit. This is a read-only structural
conformance pass; `agents/plan-auditor.md` was not modified. The 4 MEDIUM
findings concern the 8 bullets added 2026-07-21: em-dash style-rule
violation (confirmed, mechanical), bold-label format diverging from the
file's own established voice (confirmed by grep against the other 61
bullets), the Risk-blind-spots sub-list growing to roughly double every
sibling category, and the file crossing the 15KB size threshold this
auditor's own memory previously established as MEDIUM-worthy. The 3 LOW
findings are explicitly marked UNCERTAIN per the brief's instruction: the
project-specificity of several new bullets, the missing standalone
Summary/assessment line in the Output Format template, and the omission of
2 of the checklist's 9-10 standard Guiding Principles are all judgment
calls where a plausible innocent explanation (established fleet pattern,
or genuine generalisable value from a real incident) competes with the
literal checklist text.

Not checked (explicitly out of scope this round per the brief): full
domain-coverage adequacy of the plan-auditor's checklist items, and
token-waste/cost judgments beyond the single 15KB-threshold data point
already established in prior-round memory. Both are named as belonging to
future rounds within the relevant findings above rather than silently
passed.
