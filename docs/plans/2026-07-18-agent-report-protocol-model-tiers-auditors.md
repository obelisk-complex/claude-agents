# Agent Fleet: Report Protocol, Model Tiers, and New Auditors

> **For agentic workers:** REQUIRED SUB-SKILL: use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Each task is written to be executable by someone who sees that task and the Global Constraints and nothing else.

**Date:** 2026-07-18
**Repository:** `/media/owner/Workspace/claude-agents`
**Companion plan:** `/media/owner/Workspace/claude-skills/docs/plans/2026-07-18-skill-packaging-checklist-and-audit-loop.md` (skill-side work). Read the split rule under "Which repo owns what" before assuming a task belongs here.

**Goal:** Give every agent in the fleet (a) a report file it appends to as it works, so a dead or idle agent still leaves its findings on disk; (b) a `model` matched to the difficulty of its actual job rather than a fleet-wide default; and (c) three new fleet members - a token-usage auditor, a fix-regression checker, and two skill-side auditors - that encode lessons from eleven audit rounds over one large plan.

## Which repo owns what

Split by artefact type, not by subject matter:

- **`claude-agents/` owns every `*.md` with agent frontmatter**, including agents whose *subject* is skills (`skill-auditor`, `skill-trigger-auditor`). An agent definition is an agent definition wherever it points.
- **`claude-skills/` owns every skill**, including skills whose *subject* is agents (`fleet-audit-loop`, which drives the agent-auditor fleet).
- **The report protocol is owned here**, in `REPORT_PROTOCOL.md`, because it governs agent runtime behaviour and this repo already hosts the cross-fleet contract (`AGENT_CHECKLIST.md`). The skill-side plan references that file by path and does not restate the rule. If you find yourself copying the rule text into `claude-skills/`, stop: two copies of one rule in two repositories is exactly the parallel-place defect this plan exists to prevent.

## Repository facts (verified 2026-07-18, before trusting these re-verify with the commands given)

**Layout.** 62 agent definitions: 55 in `agents/*.md`, 8 in `agents/opus-variants/`, 3 in `agents/sonnet-variants/`. Cross-fleet contract in `AGENT_CHECKLIST.md`. Catalogue in `README.md` (sections: Requirements and Planning, Code Quality and Review, Testing, Platform and Compatibility, Accessibility/SEO/Design, Red Team, Travel Research, Meta). No `docs/` directory existed before this plan; this file creates `docs/plans/`.

**Relationship to the installed copies at `~/.claude/agents` (54 top-level entries).** The installed agents are **plain-file copies, not symlinks** (`ls -l ~/.claude/agents/agent-auditor.md` shows a regular file; contrast `~/.claude/skills/code-quality.md`, which *is* a symlink into `claude-skills/`). `~/.claude/agents` is not a git repository. `README.md` documents installation as `cp agents/*.md ~/.claude/agents/`. **The repo is the source; the installed tree is a manual copy, and it has drifted.** As of 2026-07-18:

- 49 files byte-identical.
- 12 files differ, repo newer in every case (`conformance-auditor`, `qa-agent`, `security-auditor`, `plan-auditor`, `pre-release`, `pr-reviewer`, `code-auditor`, `blind-spot-auditor`, `requirements-auditor`, and the `opus-variants/` copies of `conformance-auditor`, `requirements-auditor`, `plan-auditor`).
- 1 repo file not installed at all: `agents/plan-audit-loop.md` (also untracked in git).
- Installed-only: `house-researcher.md`, and a 46-file `ollama/` tree of local-model variants that exists nowhere in the repo.

**Consequence for every task in this plan: "done" means the repo file is correct *and* copied to `~/.claude/agents/`.** A task that edits only the repo has changed nothing about how the agent actually runs. Task 2 reconciles the existing drift; every later task ends with a copy step and a verification that the copy matched.

Re-verify drift before starting:

```bash
cd /media/owner/Workspace/claude-agents/agents
for f in $(find . -name '*.md' | sed 's|^\./||'); do
  inst=~/.claude/agents/$f
  [ -f "$inst" ] || { echo "NOT-INSTALLED: $f"; continue; }
  cmp -s "$f" "$inst" || echo "DIFFERS: $f"
done
```

**Frontmatter schema** (from `AGENT_CHECKLIST.md`, confirmed against the files):

```yaml
---
name: kebab-case-name
description: >
  One to two sentences, folded scalar, saying when to use the agent.
tools: Read, Grep, Glob, Bash, WebSearch, WebFetch
permissionMode: plan          # plan = read-only, acceptEdits = writes
model: sonnet                 # sonnet | opus | haiku
effort: high                  # low | medium | high | max (optional)
maxTurns: 30
memory: project               # project | user | local
color: "#f59e0b"              # unique, no collisions
---
```

`isolation: worktree` is required for agents that mutate code. `mcpServers:` is banned fleet-wide (MCPs treated as threat vectors).

**Current model distribution:** 54 `sonnet`, 8 `opus`, 0 `haiku`. All 8 opus files are the `opus-variants/` copies. `README.md` states "All agents default to `sonnet`" and documents the variant directories as the mechanism for changing model. Task 4 changes that policy and must update the README to match, or the README becomes a false statement about the fleet.

## Global Constraints

Every task below implicitly includes this section.

- **Prompt authoring is governed by `/media/owner/Workspace/HUMANE_PROMPTING.md`.** Read it before writing or editing any agent body. Its eleven principles are guidance; its ten-test torment-nexus checklist is a hard gate - any "yes" means revise. The most common failure in this fleet is adversarial role assignment aimed at a person ("hostile reviewer", "aggressive critic"); adversarial framing aimed at an artefact or a claim is correct in audit agents.
- **`AGENT_CHECKLIST.md` is the structural contract.** Any new or edited agent satisfies it: frontmatter fields, memory read/write phases with domain-specific content, one-line scope boundary, numbered workflow with a fail-fast step 1, a `## Verification` section, a fenced output template, and the guiding-principles split (domain principles first, then the ten standard ones).
- **British English. No em-dashes.** Use `-`, commas, semicolons, colons, or parentheses. Single hyphens in prose. Single blank line between sections, never double. Preamble 2-3 sentences, then straight to the workflow.
- **Agents stay project-agnostic.** No hardcoded paths, framework names, or project names in an agent body. Paths in *this plan* are for the implementer, not for the agent text.
- **No `mcpServers:` in any fleet agent.**
- **Every task ends installed.** `cp` the file to `~/.claude/agents/` (preserving the `opus-variants/` or `sonnet-variants/` subdirectory where applicable) and `cmp` to confirm. An agent that is correct in the repo and stale on disk is not done.
- **Colour uniqueness.** New agents need a `color` that no existing agent uses. Check with:
  `grep -rh '^color:' agents/ | sort | uniq -d` (should print nothing) and `grep -rh '^color:' agents/ | sort` to see what is taken.
- **Gates over prose where a gate is possible.** Where this plan asks for an invariant across many files, it also asks for a script under `scripts/` that fails when the invariant is violated. A rule stated in a document far from where it is needed gets missed; a script that exits non-zero does not. Where an invariant genuinely cannot be mechanised, say so in the task rather than writing a check that cannot fail - a gate that always passes is worse than no gate, because it is read as coverage.

## Evidence behind this plan

These findings come from eleven audit rounds over one large implementation plan, plus one orchestration session. They are the reason for the task list, and several tasks encode them directly. Stated once here; individual tasks reference them by name rather than restating them.

1. **Audits sample, they do not exhaust.** Findings tracked wherever each round was pointed and did not decay with repetition; rounds aimed at new dimensions were still producing CRITICALs and HIGHs after eight rounds. A falling finding count from re-running the same sweep is not convergence.
2. **Class-level context transfers; instance-level context anchors.** Briefing an auditor with recurring defect *patterns* produced findings in new locations. Briefing it with the specific defects already found and fixed biased it toward confirming rather than checking.
3. **Disproved-candidate lists are the high-value half.** Carrying forward "these were investigated, are not defects, here is the proof" stopped repeated re-litigation. One numerical convention was independently re-settled five times before this was adopted.
4. **A regression checker must verify intent, not text.** The proof case: a fix was present and correct in form but useless - a `ctest` invocation that exits 0 when its regex matches nothing, so the gate passed having run no tests. A string-presence check passes that; only reasoning about the mechanism catches it.
5. **Fixes survive later editing when anchored by inline justification** naming the failure mode with a file and line. A regression pass over 57 fixes found none had decayed; roughly three quarters carried an argument an editor would have to delete deliberately rather than a bare assertion that could be tidied away.
6. **Parallel-place omission is the most recurrent defect** - an action taken in one place and omitted in its parallel place, eleven occurrences across eleven rounds, including one in a task written by an agent that had been explicitly briefed about that exact pattern. Not all instances are mechanisable (one was a briefing error, one was domain knowledge).
7. **Coherence degrades at the document edge.** Every defect a coherence audit found was in the most recently written material, because each new section was written against a snapshot its predecessors had since modified.
8. **Idle is not done.** In one orchestration session subagents went idle without sending a final report at least six times. Two cases lost work silently: a follow-up message arrived after the agent had finished its pass and the agent idled without ever reading it. The orchestrator caught it only by inspecting the working tree.
9. **Do not dispatch against work that is merely idle.** Dispatching a second agent onto a file another agent still held caused a near-collision caught only by luck.

---

## Task 1: `token-usage-auditor` agent

**Effort:** ~2h expected; worst case ~3h if the rubric needs a second pass after the fleet is run over it.

**Why first:** the owner wants this built and then the whole auditor fleet run over it, itself included. Nothing else in this plan blocks it - it creates a new file, so the drift in Task 2 does not interfere.

**Verify it does not already exist before building it.** As of 2026-07-18 no such agent exists; confirm with:

```bash
cd /media/owner/Workspace/claude-agents
grep -rliE 'token.?(usage|budget|waste|econom)|context.?(bloat|waste)' agents/   # expect: no output
ls agents/ | grep -iE 'token|cost|econom'                                        # expect: no output
```

The nearest neighbours are `claude-skills/context-engineering.md` (a skill about managing context in general, not an auditor of prompt files) and the "Token economy" section of `HUMANE_PROMPTING.md` (a theory table plus a 2026-05-04 empirical correction). Neither audits definitions. If either command prints something, read the hit and report before proceeding.

**Files:**
- `agents/token-usage-auditor.md` (new)
- `~/.claude/agents/token-usage-auditor.md` (install target)
- `README.md` (add a row to the `### Meta` table)
- `scripts/check-agent-frontmatter.sh` (new; created here, extended by Tasks 3 and 4)

**Interfaces:**

```yaml
---
name: token-usage-auditor
description: >
  Use when agent or skill definitions may be spending context without
  buying signal - verbose preambles, restated rules, oversized tool
  lists, unnecessary file reads, or output formats that bloat without
  informing.
tools: Read, Grep, Glob, Bash, Write, Edit
permissionMode: plan
model: sonnet
effort: medium
maxTurns: 30
memory: user
color: <pick an unused hex>
---
```

`permissionMode: plan` - it reports, it does not rewrite other agents. `agent-auditor` holds the write role; keeping the auditor read-only means its findings can be disagreed with rather than silently applied. `memory: user` matches the other meta agents (`agent-auditor`, `blind-spot-auditor`), because waste patterns generalise across projects.

The six audit dimensions the body must cover, each with a stated test that distinguishes waste from load-bearing text:

| Dimension | Waste | Load-bearing (do not flag) |
|---|---|---|
| Preamble | Project history, philosophy, why-we-care before the task | 2-3 sentences of domain framing (`AGENT_CHECKLIST.md` allows this explicitly) |
| Restated rules | The same constraint stated in three sections | The same constraint restated at the point of use, when the first statement is more than ~40 lines away (P4a serial position: the middle of a prompt is low-attention real estate) |
| Tool list | A tool the body never invokes and the workflow never needs | A tool used on one branch of an "if X then Y" contingency |
| File reads | "Read the whole file" where a `grep` answers the question | A full read where the agent must reason about ordering or structure |
| Output template | Fields the workflow never populates; decorative sections | A "Verified OK" section (`AGENT_CHECKLIST.md` requires it; absence of findings is itself a finding) |
| Principle boilerplate | The ten standard principles copied with no domain adaptation | The ten standard principles *with* domain-specific examples - the checklist mandates the set, adaptation is what makes it earn its tokens |

The right-hand column is the point of this agent. A token auditor that flags every repetition will delete the serial-position restatements and the abstention clauses that `HUMANE_PROMPTING.md` deliberately adds, and the fleet will get cheaper and worse. The body must say this in the Verification section: **a finding is only valid if the auditor can name what signal is lost by keeping the text, and answer "none".**

Findings carry: file, line range, dimension, estimated tokens saved (state the counting method - words times 1.3 is fine if declared), and a confidence rating 1-5 with the anchors from `HUMANE_PROMPTING.md` P8a (1 = guess, 3 = supported by one reading, 5 = independently verified against how the agent actually behaves). Per P8b, an uncertain finding is marked `UNCERTAIN` in the structured output, not merely hedged in prose.

**Steps:**

- [ ] 1. Write `scripts/check-agent-frontmatter.sh`: for every `agents/**/*.md`, assert the presence of `name`, `description`, `tools`, `permissionMode`, `model`, `maxTurns`, `memory`, `color`; assert `model` is one of `haiku|sonnet|opus`; assert no duplicate `color`; assert no `mcpServers:`. Exit 1 with the offending file and field on any violation. Make it fail loudly if `agents/` is empty or unreadable, so a mis-invocation cannot look like a pass (evidence item 4: a check that cannot fail is not a check).
- [ ] 2. Run `./scripts/check-agent-frontmatter.sh`. **Expected failure:** it exits 0 over the existing 62 files but `agents/token-usage-auditor.md` does not exist, so `ls agents/token-usage-auditor.md` fails with "No such file or directory". If instead the script reports frontmatter violations in existing agents, record them - `stitch-designer.md` is known to be missing `maxTurns` - and fix them in Task 4, not here.
- [ ] 3. Write `agents/token-usage-auditor.md` against the interface above and `AGENT_CHECKLIST.md`: memory read/write phases naming waste patterns specifically, a scope boundary line ("For structural conformance to the checklist, use `agent-auditor`. For missing domain coverage, use `blind-spot-auditor`."), numbered workflow with a fail-fast step 1 (confirm the target files exist and are agent or skill definitions), a `## Verification` section carrying the "name what signal is lost" test and abstention reward, and a fenced output template leading with what the definition does economically before the findings (P9 SBI).
- [ ] 4. Run `./scripts/check-agent-frontmatter.sh` (expect exit 0) and the humane-prompting tripwire `grep -rniE "hostile|aggressive critic|adversar" agents/token-usage-auditor.md` (adjudicate any hit against Test 4 - a hit is a question, not a verdict). Run the ten-test checklist by hand against the body. Then run the agent against two real targets of known character: `agents/dependency-auditor.md` (904 words, the leanest in the fleet) and `agents/copywriter.md` (7546 words, the largest). If it returns a comparable finding count for both, the rubric is not discriminating and needs another pass.
- [ ] 5. `cp agents/token-usage-auditor.md ~/.claude/agents/` and `cmp` to confirm. Add a `### Meta` row to `README.md`. Commit.

---

## Task 2: Reconcile repo-to-installed drift

**Effort:** ~1h expected; worst case ~2h if `plan-audit-loop.md`'s dangling references need real repair.

**Why here:** every later task edits files that currently differ from their installed copies. Doing this after Task 4 means a bulk `cp` would silently overwrite whichever side happens to be newer.

**Files:**
- The 12 drifted files listed in "Repository facts"
- `agents/plan-audit-loop.md` (untracked, uninstalled)
- `~/.claude/agents/**`
- `AGENT_CHECKLIST.md` (currently modified in the working tree)
- `scripts/install-agents.sh` (new)

**Interfaces:** `scripts/install-agents.sh` copies `agents/**/*.md` to `~/.claude/agents/` preserving subdirectory structure, then `cmp`s every file and exits 1 on any mismatch. It must **not** delete installed-only files: `house-researcher.md` and the 46-file `ollama/` tree exist only on disk, and their provenance is unknown. Deleting them is out of scope for this plan; report them instead.

**Steps:**

- [ ] 1. `git -C /media/owner/Workspace/claude-agents diff` over the 12 modified files. For each, decide direction: repo-newer (expected in all 12 - the installed copies are shorter and predate the humane-prompting and file:line-verification passes) or installed-newer (unexpected; if any installed copy contains text the repo lacks, stop and report rather than overwriting).
- [ ] 2. Write `scripts/install-agents.sh`, then run it in a check-only mode (`--check`) before copying anything. **Expected failure:** it reports 13 mismatches (12 differing + 1 missing) and exits 1.
- [ ] 3. Read `agents/plan-audit-loop.md`. Two references in it do not resolve against this fleet and must be fixed or removed: step 4 instructs subagents to use a **`patch` tool ONLY** (no such tool exists in the fleet's tool vocabulary - `AGENT_CHECKLIST.md` and every other agent use `Read, Write, Edit, Grep, Glob, Bash, WebSearch, WebFetch, Agent`), and it requires a **"Mandatory Subagent Context Block (5-gate protocol, retrieval chain, patch-only append, verify-before-acting)"** that is defined nowhere in this repo. Replace the `patch` reference with `Edit` appending to the report file, and replace the context-block reference with a pointer to `REPORT_PROTOCOL.md` once Task 3 creates it - so sequence this step after Task 3 if you are running tasks in parallel, or leave a `TODO(REPORT_PROTOCOL)` marker and close it in Task 3 step 5.
- [ ] 4. Run `scripts/install-agents.sh` for real. Re-run with `--check`; expect exit 0 and no mismatches. Confirm `house-researcher.md` and `ollama/` still exist untouched.
- [ ] 5. Commit the 12 files, `plan-audit-loop.md`, the modified `AGENT_CHECKLIST.md`, and `scripts/install-agents.sh`. In the commit body, record the installed-only files as known unreconciled state.

---

## Task 3: `REPORT_PROTOCOL.md` - the skeleton-report convention

**Effort:** ~2h expected; worst case ~3h.

**Problem it solves (evidence item 8):** subagents went idle without sending a final report at least six times in one session. Each cost a re-prompt round trip. In two cases work was silently not done: a follow-up message arrived after the agent had finished its pass, and the agent idled without ever reading it, so the instructions were lost with no signal at all. The orchestrator found out by inspecting the working tree. An agent that appends to a file as it works leaves its findings behind even when it dies, and the orchestrator reads the file instead of re-prompting.

**Files:**
- `REPORT_PROTOCOL.md` (new, repo root, alongside `AGENT_CHECKLIST.md`)
- `AGENT_CHECKLIST.md` (add a "Report file" section pointing at it)
- `README.md` (one line under "Agent Design Principles")

**Interfaces.** The protocol specifies:

**Location and naming.** The dispatching orchestrator supplies an absolute report path in the brief. If it does not, the agent creates `.agent-reports/<agent-name>-<UTC yyyymmddThhmmss>-<4 hex chars>.md` relative to the working directory, and states the absolute path in its first output line so an orchestrator that later goes looking can find it without guessing. The timestamp plus random suffix is what stops two parallel instances of the same agent colliding; the agent name alone does not, because the fleet is routinely run with several instances of one auditor pointed at different files. Add `.agent-reports/` to `.gitignore` in this repo and recommend it downstream.

**Structure.** Written in two phases. The skeleton goes down *before any investigation*:

```markdown
# <agent-name> report
**Target:** <what was audited>
**Started:** <UTC timestamp>
**Status:** IN PROGRESS

## Findings
<!-- appended one at a time, as found -->

## Verified OK
<!-- appended as checked -->

## Completion
<!-- written last -->
```

Each finding is appended with `Edit` the moment it is confirmed, not batched at the end. Batching at the end recreates the exact failure this protocol exists to prevent. The `## Completion` block is written last and carries `**Status:** COMPLETE`, a finding tally by severity, and anything the agent could not check and why. **`Status: IN PROGRESS` on a file whose agent has gone quiet is the signal that the run died mid-pass** - which is the one thing an idle agent could not otherwise tell anyone.

**Zero-findings case.** The agent still writes the skeleton and still writes `## Completion`, with `## Findings` reading `_None._`. This is not ceremony: it makes absence of the file mean "did not run" and an empty findings list mean "found nothing". Those two states are indistinguishable if a clean run writes nothing, and telling them apart is most of the value.

**Mandatory or advisory - keyed on run length, not agent type.** Mandatory when any of: the agent is dispatched as one of several in parallel; its `maxTurns` is 30 or more; it has `permissionMode: acceptEdits` (so a partial run leaves half-finished edits that someone has to reconstruct); or the brief names a report path. Advisory otherwise, and an agent may state in its own body that it opts out with a reason.

**Honest cost note - this should not apply universally.** The skeleton is roughly 60 tokens. The real cost is one `Edit` call per finding, and a tool call plus its result costs far more than the finding's text. For a short agent producing two findings in a five-turn run, the protocol is a net token loss and buys almost nothing, because a five-turn run rarely dies mid-pass. The benefit scales with run length; the cost scales with finding count. Hence the `maxTurns >= 30` threshold rather than a blanket rule. Agents below the threshold that produce many small findings (`visual-hygiene`, `pre-release`) are the worst case for this protocol and are the ones the advisory tier exists for. Do not make it universal to make it tidy.

**The block that goes into an agent body** (this is the only text that gets duplicated into agent files, and it is a pointer, not the rule):

```markdown
## Report file

Before investigating, write the report skeleton (see `REPORT_PROTOCOL.md`) to
the path given in your brief, or to
`.agent-reports/<agent-name>-<UTC>-<4hex>.md` if none was given, and state that
path. Append each finding with `Edit` as you confirm it. Write the `## Completion`
block last. If you finish with no findings, still write both - an absent file
means the run died, an empty findings list means the target was clean.
```

**Steps:**

- [ ] 1. Read `AGENT_CHECKLIST.md` in full and `agents/agent-auditor.md` as a representative agent, to place the new section where it will be read rather than where it is tidy.
- [ ] 2. Write `scripts/check-report-protocol.sh`: for every agent with `maxTurns >= 30` or `permissionMode: acceptEdits`, assert the body contains a `## Report file` section. Run it. **Expected failure:** it reports roughly 40 agents missing the section and exits 1. (The exact count depends on Task 4's `maxTurns` decisions if that task runs first; record the number you actually get rather than asserting 40.)
- [ ] 3. Write `REPORT_PROTOCOL.md` covering: the problem in two sentences with the concrete failure, location and naming, the two-phase structure, the zero-findings rule, the mandatory/advisory threshold with the cost argument stated honestly, and the agent-body block above. Anchor the mandatory threshold with its reasoning inline - per evidence item 5, a rule carrying an argument survives later editing, a bare assertion gets tidied away by the next person who thinks it looks redundant.
- [ ] 4. Add a "Report file" section to `AGENT_CHECKLIST.md` (one checkbox, pointing at `REPORT_PROTOCOL.md`, not restating it) and one line to `README.md`.
- [ ] 5. Close the `TODO(REPORT_PROTOCOL)` marker in `agents/plan-audit-loop.md` from Task 2 step 3: its step 2 already says "Create skeleton report", so it becomes a reference rather than a rewrite. Note that the protocol does not yet apply to any agent - that is Task 5 - so `scripts/check-report-protocol.sh` still exits 1 at the end of this task. That is expected and must be stated in the commit message so the next implementer does not read it as a broken build.

---

## Task 4: Capability-appropriate `model` per agent

**Effort:** ~3h expected; worst case ~5h if the README's variant policy needs rewriting rather than amending.

**Files:**
- All 62 files under `agents/**`
- `README.md` (the `## Model Variants` section, which currently asserts something this task makes false)
- `AGENT_CHECKLIST.md` (the `model` line, currently "`sonnet` unless deep reasoning justifies `opus`")
- `scripts/check-agent-frontmatter.sh` (extend with the tier table)

**The conflict this task creates, and how to resolve it.** `README.md` currently states "All agents default to `sonnet`" and presents `agents/opus-variants/` as the mechanism for getting a different model, with instructions to copy the variant over the default. That is a *deployment-time* choice by the user. This task makes model a *design-time* property of each agent. The two can coexist: the base file carries the model the agent's job actually needs, and the variant directories remain as user-selectable overrides for when someone wants more or less depth than the default on a given run. Rewrite the `## Model Variants` section to say that, and delete the sentence claiming all agents default to sonnet. Do not delete the variant directories.

**Criteria (state these in the README so the next person tiers consistently):**

- **Haiku** - the agent compares an artefact against an explicit, enumerated standard, and every finding is a mismatch someone could point at. No absence-detection, no reasoning about whether a mechanism achieves an intent.
- **Sonnet** - domain reasoning over code or prose against a stated target, where the target exists but mapping it onto the artefact needs judgement. The default; anything you cannot confidently place in the other two tiers belongs here.
- **Opus** - the deliverable is what is *not* there, or requires reasoning about whether a mechanism achieves its intent rather than whether text matches, or synthesises across several artefacts.

**Proposed tiers.** Everything not named below stays `sonnet`.

*To haiku (4, confident):*

| Agent | Justification |
|---|---|
| `itinerary-compiler` | Assembles a schedule from research it is handed; no external lookup, no judgement about truth. |
| `mainstream-attractions-researcher` | Gathers well-documented tourist sites; recall over judgement, and its own description says findings are labelled tourist-friendly rather than assessed. |
| `pre-release` | Runs a fixed release checklist and reports pass or fail per item. |
| `visual-hygiene` | Compares spacing, colour, and type values against declared tokens. A diff, not a design judgement - `visual-flair` holds the judgement role. |

*To opus (3, confident):*

| Agent | Justification |
|---|---|
| `blind-spot-auditor` | Its entire deliverable is naming what is absent, which no checklist can bound. |
| `plan-auditor` | Evidence item 1: rounds aimed at new dimensions were still finding CRITICALs after eight passes. Depth is the product here. |
| `rt-business-logic` | Race conditions and multi-step workflow bypass are the hardest reasoning in the red-team set; the others test for a known class of flaw, this one infers the flaw class from the workflow. |

*Uncertain - do not change without evidence.* Per the brief's own instruction, a wrong downgrade is worse than an unchanged default:

- `dependency-auditor` - looks mechanical (run the audit tool, report CVEs) but transitive and version-range reasoning is where the real findings are. Leave `sonnet`; if you want haiku here, A/B it against a repo with a known transitive vulnerability first.
- `rt-recon` - enumeration is mechanical; deciding what is in scope is not, and getting that wrong on a red-team engagement is the expensive kind of wrong. Leave `sonnet`.
- `requirements-auditor` - absence-detection like `blind-spot-auditor`, which argues for opus, but it has an opus variant already and the base is used routinely. Leave `sonnet` base, keep the variant. Flag for review after the fleet has been run a few times.
- `culinary-researcher`, `local-insights-researcher` - "authentic local" judgement is exactly the thing a cheaper model flattens into a listicle. Leave `sonnet`.
- `travel-guide-designer` - it writes ReportLab code. Code generation is not checklist work. Leave `sonnet`.
- `conformance-auditor` - traceability is largely mechanical once the source of truth is identified, which argues against its existing opus variant, but identifying the source of truth is not. Leave as is.

*New agents from this plan:* `token-usage-auditor` sonnet (rubric-driven), `fix-regression-checker` **opus** (evidence item 4 - the `ctest`-exits-0-on-no-match case is precisely what a cheaper model misses, because the text is present and correct), `skill-auditor` sonnet, `skill-trigger-auditor` sonnet, `plan-audit-loop` sonnet (orchestration, not analysis).

**Steps:**

- [ ] 1. Regenerate the current inventory so you are tiering against the tree rather than against this table:
      `for f in $(find agents -name '*.md'); do echo "$f|$(grep -m1 '^model:' $f)|$(grep -m1 '^maxTurns:' $f)"; done`
- [ ] 2. Extend `scripts/check-agent-frontmatter.sh` with an assertion that each agent's `model` matches a checked-in tier table (`docs/model-tiers.tsv`, two columns: agent name, tier). Write the table with the tiers above. Run the script. **Expected failure:** it reports 7 mismatches - the 4 haiku promotions and 3 opus promotions still read `model: sonnet` on disk - and exits 1. It should also report `stitch-designer.md` missing `maxTurns` from Task 1 step 2 if that was not fixed.
- [ ] 3. Apply the 7 `model:` changes. Fix `stitch-designer.md`'s missing `maxTurns` (30, matching its siblings). Do not touch any agent in the uncertain list.
- [ ] 4. Run the script; expect exit 0. Then, for each of the 7 changed agents, run it once against a real target and compare the output against the same target under the previous model. A haiku demotion that loses findings is a bad trade and must be reverted; record the comparison in the commit message rather than asserting the change was safe. If you cannot run a comparison for a given agent, say so and leave that agent unchanged - an untested downgrade is the failure mode this task is most likely to produce.
- [ ] 5. Rewrite `README.md`'s `## Model Variants` section per the conflict resolution above, including the three criteria. Update the `model` line in `AGENT_CHECKLIST.md`. Install all changed files and `cmp`. Commit.

---

## Task 5: Apply the report protocol to the fleet

**Effort:** ~2h expected; worst case ~3h, mostly the per-file edits.

**Depends on:** Task 3 (`REPORT_PROTOCOL.md` must exist) and Task 4 (the `maxTurns` fix changes which agents qualify).

**Files:** every agent meeting the mandatory threshold, plus `scripts/check-report-protocol.sh`.

**Interfaces:** insert the `## Report file` block from `REPORT_PROTOCOL.md` verbatim, placed immediately before the `## Verification` section in each agent - not at the end. Serial position (P4a): the end of the body is where the output template lives and is read; the middle is low-attention. Immediately before Verification puts it adjacent to the step that triggers it.

**This task is itself the parallel-place defect risk (evidence item 6):** an action taken in one place and omitted in its parallel place was the single most recurrent defect across eleven rounds, and it recurred once in work by an agent that had been briefed about that exact pattern. Briefing is not sufficient. That is why step 2 builds the gate before the edits and step 4 re-runs it, rather than relying on the implementer to remember all ~40 files.

**Steps:**

- [ ] 1. Run `scripts/check-report-protocol.sh` and capture the exact list of qualifying agents. Do not work from a list you assembled by reading; work from the script's output, since the script is what will judge the result.
- [ ] 2. Confirm the gate can fail: temporarily add the `## Report file` heading to one qualifying agent and re-run. **Expected:** the reported count drops by exactly one. If it does not change, the check is matching on something other than what you think and must be fixed before it is trusted. Revert the temporary edit.
- [ ] 3. Insert the block into every agent on the list, at the position specified. For each of the three `opus-variants/` and `sonnet-variants/` files that qualify, insert it there too - variants are the parallel place most likely to be missed, because they live in a subdirectory and do not appear in a flat `ls`.
- [ ] 4. Run `scripts/check-report-protocol.sh`; expect exit 0. Run `scripts/check-agent-frontmatter.sh`; expect exit 0.
- [ ] 5. Install all changed files, `cmp`, commit.

---

## Task 6: `fix-regression-checker` agent

**Effort:** ~2h expected; worst case ~3h.

**Problem it solves (evidence items 3, 4, 5).** Across eleven audit rounds, two things repeatedly wasted rounds: settled questions being re-litigated (one numerical convention was independently re-settled five times), and fixes that were present in the text but did not work. The proof case for the second: a `ctest` invocation that exits 0 when its regex matches nothing, so the gate passed having run no tests. The fix was there. The fix was correct in form. The fix did nothing. A string-presence check passes that; only reasoning about the mechanism catches it.

**Files:**
- `agents/fix-regression-checker.md` (new)
- `README.md` (`### Meta` row)
- `~/.claude/agents/fix-regression-checker.md`

**Interfaces:**

```yaml
---
name: fix-regression-checker
description: >
  Use when a set of previously applied fixes needs re-checking before
  work is called done - verifies each fix still achieves what it was
  meant to achieve, not merely that its text is still present.
tools: Read, Grep, Glob, Bash
permissionMode: plan
model: opus
effort: high
maxTurns: 35
memory: project
color: <pick an unused hex>
---
```

`model: opus` per Task 4's criteria: the deliverable is a judgement about whether a mechanism achieves an intent, which is the tier-3 case exactly.

The body must carry, as its core method:

1. **This agent holds the instance list.** It is the one place in the fleet where specific previously-found defects belong. Everywhere else, briefing an auditor with the specific instances already found biases it toward confirming rather than checking (evidence item 2). Here that bias is the point: the job is confirmation of a known list, not discovery. State this distinction in the body, because it is the reason this agent exists separately from `plan-auditor` rather than being a mode of it.
2. **Per fix, answer three questions in order:** (a) is the fix still present; (b) does the mechanism it uses actually produce the effect it was meant to produce - run it, or trace what it does on the input that originally failed; (c) would it still fire if the failing condition recurred. A "yes" to (a) alone is not a pass and must be reported as `UNVERIFIED`, not as a pass.
3. **The no-op family to check for by name**, since these are what (a)-only checking misses: a command whose filter matches nothing and exits 0; a test that asserts nothing; a guard whose condition can never be true; an assertion behind a flag that is off; a regex anchored so it matches the old form only.
4. **Report inline-justification decay.** Evidence item 5: a regression pass over 57 fixes found none had decayed, and the reason was that roughly three quarters carried an argument naming the failure mode with a file and line - something an editor would have to delete deliberately rather than tidy away. So the agent flags any fix carrying a bare assertion where a justification would survive better, as a `LOW` finding with the suggested comment text.
5. **Carry the disproved-candidate list forward.** For each item investigated and found not to be a defect, record it with its proof so the next round does not re-litigate it. The format and the gate for this live in the `disposition-ledger` skill; the skill-side plan (Task 3 there) extends that skill with cross-round carry-forward. Reference it; do not define a second ledger format here.

**Steps:**

- [ ] 1. Read `agents/plan-auditor.md` and `agents/regression-test.md` to place this agent's scope boundary against its two nearest neighbours (`plan-auditor` finds new defects in a plan; `regression-test` checks that code behaviour is preserved; this agent checks that a specific list of applied fixes still does its job).
- [ ] 2. Run `ls agents/fix-regression-checker.md`. **Expected failure:** "No such file or directory". Then run `scripts/check-agent-frontmatter.sh` and confirm it currently exits 0 - so that when it fails after step 3, the failure is about the new file and not pre-existing state.
- [ ] 3. Write the agent against the interface and `AGENT_CHECKLIST.md`, including a worked example of the no-op family in the body. Use the `ctest`-exits-0 case: it is real, it is concrete, and it shows the difference between (a) and (b) in one example. Keep it to four or five lines; a worked example that runs to a page is the preamble bloat `token-usage-auditor` exists to flag.
- [ ] 4. Run `scripts/check-agent-frontmatter.sh` and `scripts/check-report-protocol.sh`; both exit 0. Apply the ten-test checklist by hand. Then run `token-usage-auditor` over the new file, since that is the fleet's own standard now.
- [ ] 5. Install, `cmp`, add the `### Meta` README row, commit.

---

## Task 7: `skill-auditor` and `skill-trigger-auditor` agents

**Effort:** ~3h expected; worst case ~4h.

**Depends on:** the skill-side plan's Task 2, which creates `claude-skills/SKILL_CHECKLIST.md`. `skill-auditor` audits against that checklist, so it cannot be finished before the checklist exists. If you are running these plans in parallel, write the body last and stub the reference.

**Why two agents and not a mirror of the whole agent fleet.** The existing meta fleet is `agent-auditor` (structural conformance, read-write) plus `blind-spot-auditor` (domain gaps, read-only), with opus and sonnet variants of each. A direct mirror would produce four new agents. Three arguments against mirroring wholesale:

- `blind-spot-auditor` is already artefact-agnostic - its description is about domain coverage gaps, not about agents specifically. A `skill-blind-spot-auditor` would be a copy with the noun changed, which is a duplicate to maintain and a parallel place to forget. **Reuse it; do not mirror it.**
- `token-usage-auditor` (Task 1) applies to skills more urgently than to agents, because a skill's content loads into the *caller's* context rather than an isolated subagent context, so its tokens are charged to the conversation that triggered it. **Reuse it; do not mirror it.**
- Skills have a failure mode with no agent equivalent of comparable weight: **the skill never fires.** A skill whose `description` does not match the situation is never loaded, and nothing anywhere reports this. Agents are usually dispatched by name; skills are matched by description. This is what `skill-trigger-auditor` is for, and it is the strongest argument that the skill fleet is not a mirror.

**Files:**
- `agents/skill-auditor.md`, `agents/skill-trigger-auditor.md` (new)
- `README.md` (`### Meta` rows)

**Interfaces:**

`skill-auditor`: `tools: Read, Edit, Write, Grep, Glob, Bash`, `permissionMode: acceptEdits` (matching `agent-auditor`, which holds the write role for its artefact type), `model: sonnet`, `maxTurns: 35`, `memory: user`. Audits a skill against `SKILL_CHECKLIST.md`: frontmatter (`name`, `description`), packaging (see below), structure, and overlap with sibling skills. Overlap is a dimension inside this agent rather than a third agent - two skills that contradict each other is a conformance finding, not a separate discipline.

`skill-trigger-auditor`: `tools: Read, Grep, Glob`, `permissionMode: plan`, `model: sonnet`, `maxTurns: 25`, `memory: user`. Method: from the skill body, derive the concrete situations it should fire on; write each as a one-line user request; check whether the `description` field would plausibly match it; and separately construct two or three adjacent situations it should *not* fire on. Report both misses and over-triggers. Findings carry a confidence rating, because this is prediction about a matcher the agent cannot execute - per P8a and P8b, an unverifiable prediction is marked `UNCERTAIN` in the structured output.

**A load-bearing fact both agents need in their bodies.** Claude Code loads a user-scope skill from `~/.claude/skills/<name>/SKILL.md` - a directory containing `SKILL.md`. A bare `~/.claude/skills/<name>.md` is **not** loaded. Verified 2026-07-18: of the 15 entries in `~/.claude/skills`, only `songwriting/` is a directory with a `SKILL.md`, and only `songwriting` appears in the session's available-skills list; the 14 flat `.md` files (`code-quality.md`, `frontend-design.md`, `interview.md`, and others, most of them symlinks into `claude-skills/`) do not appear and are inert. **A skill audit that checks content but not packaging will pass a skill that can never load.** Both agents check packaging first and report it as CRITICAL, because every content finding is moot if the file is not loaded. The skill-side plan's Task 1 fixes the existing instances; these agents stop it recurring.

**Steps:**

- [ ] 1. Read `agents/agent-auditor.md` in full - it is the structural model for `skill-auditor` - and `claude-skills/SKILL_CHECKLIST.md` if the skill-side plan's Task 2 has landed. If it has not, read `claude-skills/README.md` and two skill bodies (`claude-skills/code-quality.md`, `claude-skills/fleet-qa-loop.md`) to derive the structure the checklist will encode, and note the dependency in your report.
- [ ] 2. Verify the packaging fact yourself rather than taking it from this plan: `ls -l ~/.claude/skills/` and `find ~/.claude/skills -name SKILL.md`. **Expected:** exactly one `SKILL.md`, under `songwriting/`, and 14 flat `.md` files. If you find more `SKILL.md` files than that, the packaging situation has changed since 2026-07-18 and the CRITICAL framing in step 3 needs revisiting before you write it.
- [ ] 3. Write both agents. Keep `skill-trigger-auditor` short - its method is three steps and its output is a table; the temptation to pad it with prompt-engineering theory is exactly what `token-usage-auditor` will flag.
- [ ] 4. Run `scripts/check-agent-frontmatter.sh` and `scripts/check-report-protocol.sh`; both exit 0. Run `skill-trigger-auditor` against `claude-skills/doubt-driven-development.md` (a long skill with an abstract name, the hardest trigger case in the set) and `claude-skills/github-actions.md` (a short skill with an obvious one). Different finding profiles mean the method discriminates; identical ones mean it does not.
- [ ] 5. Install both, `cmp`, add `### Meta` README rows, commit.

---

## Task 8: Fold the class-level briefing rule into the auditor fleet

**Effort:** ~2h expected; worst case ~3h.

**Files:** `agents/agent-auditor.md`, `agents/blind-spot-auditor.md`, `agents/plan-auditor.md`, `agents/requirements-auditor.md`, `agents/conformance-auditor.md`, and the corresponding `opus-variants/` and `sonnet-variants/` copies of each. **The variants are the parallel place** (evidence item 6): eight opus variants and three sonnet variants exist, and a change applied only to `agents/*.md` leaves them stale. Step 4 gates on this.

**What goes in (evidence items 2, 7):**

**Class-level, not instance-level.** Each of these agents gains a short section stating: when briefed with prior findings, treat recurring defect *patterns* as directions to search in, and treat specific already-fixed defects as out of scope for this pass. Briefing with patterns produced findings in new locations; briefing with instances produced confirmation of the instances. One auditor described the mechanism precisely: knowledge recalled from its own memory arrives as "here is what was true, verify it", which invites checking, whereas the same content arriving in a brief arrives as instruction. So the agent's *memory* may hold instances; its *brief* should carry classes. `fix-regression-checker` (Task 6) is the deliberate exception and holds the instance list.

**Coherence degrades at the document edge.** Each of these agents gains one line: when auditing a long-lived artefact, weight scrutiny toward the most recently written material. A coherence audit found every one of its defects concentrated there, because each new section was written against a snapshot its predecessors had since modified. This is a one-line heuristic; do not expand it into a section.

**Steps:**

- [ ] 1. List the exact file set: `grep -rl '^name: \(agent-auditor\|blind-spot-auditor\|plan-auditor\|requirements-auditor\|conformance-auditor\)' agents/` - this catches the variants by name and is the list to work from, rather than one assembled by hand.
- [ ] 2. Write `scripts/check-audit-briefing-rule.sh`, asserting that every file in that set contains the marker heading `## Prior findings in a brief`. Run it. **Expected failure:** it reports all files in the set (roughly 12 including variants) and exits 1. Confirm the count matches step 1's list exactly; a mismatch means one of the two is wrong, and finding out which is cheaper now than after the edits.
- [ ] 3. Add the section to each file. Adapt the wording to the agent's domain rather than pasting identical text - `AGENT_CHECKLIST.md` requires adaptation of shared content, and `token-usage-auditor` flags unadapted boilerplate as waste.
- [ ] 4. Run `scripts/check-audit-briefing-rule.sh`; expect exit 0. Then diff each variant against its base to confirm the variant got the adapted text and not a stale copy: `diff <(sed -n '/## Prior findings in a brief/,/^## /p' agents/plan-auditor.md) <(sed -n '/## Prior findings in a brief/,/^## /p' agents/opus-variants/plan-auditor-opus.md)` and equivalents.
- [ ] 5. Install all changed files, `cmp`, commit.

---

## Deliberately not done

- **A separate disproved-candidate ledger.** The installed skill `~/.claude/skills/disposition-ledger.md` already defines a finding-lifecycle ledger whose `rejected` disposition requires "the specific code, test, or fact that makes the finding wrong" - which is a disproved-candidate entry under another name. Building a second one would duplicate a format across two artefacts. The skill-side plan extends that skill with cross-round carry-forward instead. (Note: `disposition-ledger.md` exists only in `~/.claude/skills`, not in the `claude-skills` repo; the skill-side plan's Task 1 imports it.)
- **A `skill-blind-spot-auditor`.** `blind-spot-auditor` is already artefact-agnostic. See Task 7.
- **Deleting the installed-only `ollama/` tree and `house-researcher.md`.** Provenance unknown; deletion is irreversible and outside what this plan was asked to do. Task 2 reports them.
- **Haiku for `dependency-auditor`, `rt-recon`, and the two local-knowledge travel researchers.** Plausible, unverified, and a wrong downgrade is worse than an unchanged default. Task 4 records them as uncertain with the test that would settle each.
- **Making the report protocol universal.** See the cost argument in Task 3. For short runs it costs more than it buys.
