# Reusable defect classes - fleet audit 2026-07-21

Source: 6-round `fleet-audit-loop` run against 3 same-day-edited agents
(`blind-spot-auditor.md`, `plan-audit-loop.md`, `plan-auditor.md`). 26 findings
raised, 23 accepted and fixed, 3 rejected, 4 still open pending owner sign-off
(see bottom). Full detail: `.superpowers/sdd/audit/ledger.md` and the 6
per-round report files in this directory.

This file is written as **classes to check for**, not the specific instances
already fixed - hand it to any agent-auditor/blind-spot-auditor/conformance-auditor
dispatch auditing a *different* file and brief it with the relevant items below,
per `fleet-audit-loop`'s "brief with classes, not instances" rule.

## Structural / style

1. **Em-dash creep in freshly-added prose.** Every file in this run had zero
   em-dashes before its edit and 1-8 after, despite the checklist's explicit
   "never em-dash" rule. New content is where style rules get skipped most.
   Check: `grep "—"` on any file right after an edit, not just at review time.

2. **New list items drift into a different lead-in format than their
   siblings.** A `**Bold Label** - text` lead-in appearing mid-list where every
   other item uses a question-then-explanation voice (or vice versa) reads as
   two authors spliced together. Check new items against the *immediate*
   siblings' format, not just the checklist's abstract rule.

3. **Batch-appending N similar items into one category bloats it 2x+ relative
   to siblings.** 8 items added to one 9-item category made it 17 vs.
   sibling categories' 5-10. Distribute by what each item actually checks, not
   by convenience-taxonomy ("all of these are risks so they go under Risks").

4. **A merged/folded-in bullet (result of deleting one item and merging its
   content into another) ends up much longer and differently-registered than
   its new siblings.** Trim merged content to the surrounding list's voice;
   don't just relocate the original wording.

5. **A prose cross-reference ("see the Memory loop above") can point to a
   heading that doesn't actually exist in the document.** Grep the referenced
   name against the file's actual `#`/`##` headings before trusting the
   pointer.

## Content / methodology

6. **Dated "Confirmed <date>: <specific numbers>" citations get hardcoded into
   evergreen instruction text instead of routed to the agent's own memory
   system.** This happened independently, same day, in two unrelated files
   (`blind-spot-auditor.md` and `plan-audit-loop.md`) - it's an authoring
   habit, not a one-off. If a file has a `## Memory` section describing what
   belongs in memory, any dated/specific-instance citation in the *body* text
   is a candidate for this defect. Fix: keep the generalized methodology in
   the body, move the specific instance to memory.

7. **A freshly-appended step/paragraph can silently contradict a canonical
   rule stated elsewhere in the same document** - especially one that says
   "this is the only statement of the rule." Two CRITICAL findings in this run
   were exactly this: a new fallback path contradicting an existing
   auditor/fixer boundary, and a new step reopening a round cap the file
   declared closed. When adding new instructions to a file with an existing
   canonical-rule section, explicitly re-check that section for disagreement -
   don't just append and assume it slots in cleanly.

8. **A fix that reconciles two contradicting sections can leave a *third*,
   independently-edited section still holding the old framing.** Round 1 fixed
   a contradiction between 2 of 4 sections that referenced the same rule;
   round 5 (a dedicated coherence pass) found the other 2 sections still
   disagreed. After resolving any contradiction, grep for every other place
   that states or restates the same rule, not just the two sections you found
   conflicting in.

9. **A new capability/step ("dispatch to a different model via X") gets added
   without confirming X is actually reachable in the running harness** - no
   registered target, no `mcpServers` entry, no confirm-before-dispatch check
   matching what the rest of the file already does for its existing dispatches.
   This is the same "control that can fail" principle applied to *newly
   added* dispatch instructions, which get less scrutiny than the original
   ones. Fix: either wire the confirm-before-dispatch check up to the same
   standard as existing dispatches, or state plainly that the mechanism isn't
   wired up yet rather than presenting it as ready.

10. **A meta-auditor's coverage map can be missing a whole target archetype.**
    `blind-spot-auditor.md` had no category for iterative/loop-agent
    convergence failure (non-termination, fix-induced regression, premature
    clean, shared-blind-spot reinforcement across rounds) despite auditing a
    sibling agent (`plan-audit-loop.md`) that is exactly such a loop. It also
    had no category for auditor/evaluator *miscalibration* (false positives,
    severity inflation) - its whole frame was absence/false-negative only.
    If a blind-spot-style auditor's targets include other auditors or loop
    agents, check its own coverage map names those archetypes explicitly.

## Process note for orchestrators running this loop

11. **Read-only auditor agent types (`disallowedTools: Write, Edit`) cannot
    write report files to disk even when briefed to.** `blind-spot-auditor`,
    `token-usage-auditor`, and `conformance-auditor` are all correctly
    read-only per this fleet's own checklist (a `## Report file` section would
    be inert without Write+Edit) - but a brief that says "write your report to
    <path>" will get findings returned in the reply instead, with a note that
    the agent couldn't write the file. The orchestrator must recognize this
    from each auditor's `tools:` line before dispatching, and persist the
    report to disk itself rather than treating an unwritten report file as a
    dead run.

## Still open - needs owner sign-off, not yet actioned

These were deferred rather than fixed because they need a decision this run
wasn't authorized to make alone:

- **`agents/opus-variants/blind-spot-auditor-opus.md` and
  `agents/sonnet-variants/blind-spot-auditor-sonnet.md`** are independently-worded
  paraphrases of `blind-spot-auditor.md` and do not carry any of the 3 new
  step-4 bullets added to the primary file today (cross-model blind spots,
  iterative/loop-agent failure modes, auditor/evaluator miscalibration).
  Propagating them is a content-adaptation decision (matching each variant's
  own voice), not a mechanical sync. (`ledger.md:agent-auditor-3`)
- **Guiding Principle 9** ("prefer the native tool over a workaround") is
  absent from 53/56 agents in the fleet, including the checklist's own
  steward `agent-auditor.md` - reads as an incomplete rollout rather than a
  defect in any one file. Needs a coordinated fleet-wide pass, not a
  single-file edit. (`ledger.md:agent-auditor-4`)
- **`effort: high`** is a consistently-used frontmatter field (17/56 agents)
  that `AGENT_CHECKLIST.md` never documents - a checklist documentation gap.
  (`ledger.md:agent-auditor-6`)
- **`plan-auditor.md`'s "Risk blind spots" category** is still 16 items (was
  17, one item was deleted and folded elsewhere this run) vs. sibling
  categories' 5-10 - a taxonomy redistribution call (which of the remaining
  items belong under "False or unstated assumptions" instead) that this run
  left alone rather than deciding unilaterally. (`ledger.md:agent-auditor-18`)
