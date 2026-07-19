# Agent Report Protocol

Subagents go idle without sending a final report: at least six times in one
orchestration session, and in two of those cases a follow-up message arrived
after the agent had finished its pass, so the instructions were lost with no
signal at all. An agent that appends to a file as it works leaves its findings
behind even when it dies, and the orchestrator reads the file instead of
re-prompting.

## Location and naming

The dispatching orchestrator supplies an absolute report path in the brief. If
it does not, the agent creates
`.agent-reports/<agent-name>-<UTC yyyymmddThhmmss>-<4 hex chars>.md` relative to
the working directory, and states the absolute path in its first output line so
an orchestrator that later goes looking can find it without guessing.

The timestamp plus random suffix is what stops two parallel instances of the
same agent colliding; the agent name alone does not, because the fleet is
routinely run with several instances of one auditor pointed at different files.

`.agent-reports/` is gitignored in this repo. Recommend the same downstream.

## Structure

The report is written in two phases. The skeleton goes down *before any
investigation*:

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

Each finding is appended with `Edit` the moment it is confirmed, not batched at
the end. Batching at the end recreates the exact failure this protocol exists to
prevent.

The `## Completion` block is written last and carries `**Status:** COMPLETE`, a
finding tally by severity, and anything the agent could not check and why.
`Status: IN PROGRESS` on a file whose agent has gone quiet is the signal that
the run died mid-pass, which is the one thing an idle agent could not otherwise
tell anyone.

## Zero findings

The agent still writes the skeleton and still writes `## Completion`, with
`## Findings` reading `_None._`. This is not ceremony: it makes absence of the
file mean "did not run" and an empty findings list mean "found nothing". Those
two states are indistinguishable if a clean run writes nothing, and telling them
apart is most of the value.

## Mandatory or advisory, keyed on capability

The entry condition is capability, not run length. An agent carrying a
`## Report file` section must have `Write` and `Edit` in its `tools:` line:
`Write` to create the skeleton, `Edit` to append findings to it. Without both,
the section is inert from its first step, and an agent that cannot create the
file will not report that it failed to.

An agent that has `Write` and `Edit` is under the protocol when any of:

- it is dispatched as one of several in parallel;
- the brief names a report path;
- it has `permissionMode: acceptEdits`, so a partial run leaves half-finished
  edits that someone has to reconstruct.

Advisory otherwise, and an agent may state in its own body that it opts out with
a reason.

The old threshold was `maxTurns >= 30`, used as a proxy for run length. That
proxy is dead: the fleet's floor is now 75, so every agent clears 30 and the
condition selects everything. The cost argument behind it has not vanished,
though, so here is what is still true. The skeleton is roughly 60 tokens. The
real cost is one `Edit` call per finding, and a tool call plus its result costs
far more than the finding's text; the cost still scales with finding count, not
with run length. What changed is the other side: a higher cap does not make a
run long, it only stops a long run being cut short, so a raised `maxTurns` is
not evidence that any particular agent now runs long enough to be worth the
overhead. A genuinely short pass still rarely dies mid-pass, and for one
producing two findings the protocol is still a net loss.

The parallel-dispatch and named-path conditions are what carry the rule now, and
they are better signals than turn count ever was: both describe a run whose
findings someone else is waiting on, which is exactly when a silent death is
expensive. An agent that produces many small findings in a short solo pass
(`visual-hygiene`, `pre-release`) remains the worst case, and remains the reason
the advisory tier exists. Do not make it universal to make it tidy.

## The block that goes into an agent body

This is the only text duplicated into agent files, and it is a pointer rather
than the rule. Insert it immediately before the `## Verification` section:

```markdown
## Report file

Before investigating, write the report skeleton (see `REPORT_PROTOCOL.md`) to
the path given in your brief, or to
`.agent-reports/<agent-name>-<UTC>-<4hex>.md` if none was given, and state that
path. Append each finding with `Edit` as you confirm it. Write the `## Completion`
block last. If you finish with no findings, still write both - an absent file
means the run died, an empty findings list means the target was clean.
```

`scripts/check-report-protocol.sh` gates this. It still selects its qualifying
set by `maxTurns >= 30` or `permissionMode: acceptEdits`, which now matches the
whole fleet, and it checks for the section's text rather than for `Write` and
`Edit`. Both need reconciling against the capability rule above; the gate is
owned separately from this document.
