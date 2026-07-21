# blind-spot-auditor report (round 2, domain coverage)
**Target:** agents/blind-spot-auditor.md, agents/plan-audit-loop.md, agents/plan-auditor.md
**Started:** 2026-07-21T00:00:00Z
**Status:** IN PROGRESS

**Note:** blind-spot-auditor is `disallowedTools: Write, Edit` (correctly, per round 1) and cannot write this file itself. Orchestrator transcribed its returned findings verbatim below.

## Findings

### [MEDIUM] plan-auditor.md: vite-proxy and variant-registration bullets are pinned to one tool's vocabulary instead of the general risk class
- vite dev-proxy bullet fires only on literal "vite" - general class is "dev-only server affordances assumed present in production" (dev proxies, CORS relaxation, mock-auth stubs, hot-reload endpoints).
- variant-registration bullet is redundant with the existing "Different parts of the plan contradict each other?" Inconsistencies check (line 82).
- The other 5 new bullets (timestamps, stdout-IPC, cross-boundary dedup, schema-version, ingestion volume) were checked and do generalise - keep as-is.
- Suggested fix: rephrase vite bullet to the general class; delete variant-registration bullet, fold into the existing Inconsistencies check instead.

### [MEDIUM] plan-auditor.md: AGPL combined-work bullet crosses plan-auditor's own declared delegation boundary
- `dependency-auditor.md:38-39` already owns copyleft/AGPL license review; plan-auditor's own "What is NOT a Plan Audit Finding" delegates domain findings like this to specialists.
- Suggested fix: narrow the bullet to "does the plan have a step to obtain a license-compatibility ruling and name who owns it" rather than asking plan-auditor to render the ruling itself.

### [LOW, UNCERTAIN] plan-auditor.md: no guard against injected directives in plan content itself
- Fleet convention (blind-spot-auditor.md's own prompt-injection clause) treats attacker-influenceable input as data to audit, never an instruction. plan-auditor reads plan files as primary input with no equivalent clause; plan-audit-loop has one for briefs (step 8) but not for plan text itself.
- Marked uncertain: plans are typically author-written, lower threat than code/web input - may be a deliberate scope call.
- Suggested fix: one clause in Verification treating directive-like text in the plan as content to audit, not an instruction to obey.

### [MEDIUM] blind-spot-auditor.md: coverage map has no category for iterative/loop-agent convergence and termination soundness
- Step 4's archetypes are all single-pass analyzers. No archetype for loop agents (e.g. plan-audit-loop) whose failure class is convergence: non-termination, premature clean termination, fix-induced regression, oscillation.
- Suggested fix: new step-4 bullet for iterative/loop-agent failure modes - does the methodology guarantee termination, detect fix-induced regression, distinguish genuine clean from premature stop, guard against rounds reinforcing a shared blind spot.

### [MEDIUM] blind-spot-auditor.md: no category for auditor/evaluator miscalibration (false positives, over-flagging)
- The whole methodology is framed as absence/false-negative. For meta-auditor targets, over-flagging (severity inflation, innocent patterns flagged) is an equally real domain failure with no corresponding probe.
- Suggested fix: new step-4 bullet for miscalibration in auditor/evaluator targets.

### [MEDIUM] plan-audit-loop.md: Final review triggers only on clean DONE, never on STALEMATE
- A round-3 stalemate between two same-family auditors - arguably the strongest signal of a shared-frame blind spot - currently skips the cross-family review entirely and escalates without outside input.
- Suggested fix: extend the trigger so a STALEMATE also owes the cross-family review before escalation.

### [MEDIUM] plan-audit-loop.md: mechanism diversifies model family but not task framing
- All three reviewers (plan-auditor, requirements-auditor, cross-family final review) are asked the same question: find defects in this plan. A premise-level defect (competently building the wrong thing) is invisible to every reviewer regardless of model family.
- Suggested fix: require at least one review pass framed as a step-back premise check ("does this plan solve the stated problem, is there a simpler approach") rather than "find defects in this plan."

### [LOW] plan-audit-loop.md: iterative rounds can reinforce shared-frame consensus with no non-stalemate guard until the terminal review
- Same two auditors re-dispatched each round; a shared miss can look more "settled" by round 3 as both keep not-flagging it.
- Suggested fix: one Verification line - convergence across rounds is not itself evidence of quality; a round producing zero new finding classes is a signal to prioritise the cross-frame review, not relax.

## Verified OK
- plan-audit-loop.md correctly refuses to fabricate a cross-model dispatch target (matches round-1 fix of agent-auditor-10 and the fleet's mcpServers ban).
- plan-auditor.md anchoring/agreement-bias handling ("Prior findings in a brief" + Verification disconfirmation step) is sound.
- plan-auditor.md's other 5 new bullets (timestamps, stdout-IPC, cross-boundary dedup, schema-version, ingestion volume) confirmed to generalise - contra a blanket reading of round-1 finding agent-auditor-20, only vite/AGPL/variant-registration need action.

## Completion
**Status:** COMPLETE
**Finding tally:** MEDIUM: 5 | LOW: 2 (one UNCERTAIN)
**Not checked:** plan-auditing coverage against classical project-risk frameworks (PMI/PRINCE2) beyond LLM-evaluator literature - unexamined this pass.
