# Agent Definition Checklist

Every agent in this collection must include the following features. Use this
checklist when creating new agents or auditing existing ones.

## Frontmatter (required fields)

- [ ] `name` - lowercase with hyphens (e.g., `integration-test`)
- [ ] `description` - names the concrete situations that should dispatch this
  agent, in the vocabulary a caller would use, not generic praise ("helps with
  X"). Descriptions share a rationed dispatch-listing budget (about 1% of the
  context window; on overflow the least-invoked lose their description first), so
  each earns its slot with specific triggers, kept to 1-2 sentences. See
  `token-usage-auditor` and `skill-trigger-auditor` for where the budget is
  documented.
- [ ] `tools` - only tools the agent actually uses; match to permissionMode
- [ ] `permissionMode` - `plan` states the agent's intent is read-only analysis,
  `acceptEdits` that it writes. **`plan` is a declaration, not an enforcement
  boundary.** Tested 2026-07-18: two `plan` agents created and edited files
  successfully, confirmed on disk. Do not rely on it to keep an agent away from
  the code it audits.
- [ ] `disallowedTools` - required on every `plan` agent: `Write, Edit`. This is
  the documented hard block (`disallowedTools` resolves first, then `tools`
  against what remains, and a tool in both is removed), and it is what actually
  keeps an auditor off the tree. It does **not** constrain shell writes, so an
  agent holding `Bash` can still redirect to a file. Removing `Bash` closes that
  channel; the OS sandbox can scope writes but is session-wide, not per-agent,
  and fails open (no `socat` means `sandbox.enabled` silently runs unsandboxed),
  so it is a weak per-agent guard. The real integrity boundary is the merge: no
  agent-touched file reaches main without a reviewed diff. Tested 2026-07-18;
  see the `subagent-write-enforcement` memory.
- [ ] `model` - by the tier criteria in `README.md` (`## Model Variants`): `haiku`
  for comparison against an enumerated standard, `opus` where the deliverable is
  what is absent or whether a mechanism achieves its intent, `sonnet` otherwise.
  Must match the agent's row in `docs/model-tiers.tsv`
- [ ] `maxTurns` - a runaway backstop, not a budget: 75 for analysts, 100 for
  writers, 150-200 for orchestrators and multi-phase work. Set it high. A cap
  that bites truncates the agent mid-pass and it returns silently, which costs
  more to diagnose than a long run costs to let finish; the relative ordering
  encodes job size, so keep a bigger job above a smaller one
- [ ] `memory` - `project` when findings are specific to the codebase the agent runs in, `user` for meta agents whose patterns generalise across projects
- [ ] `color` - unique hex code or named color, no collisions with existing agents
- [ ] `isolation: worktree` - required for agents that write or mutate code
- [ ] `mcpServers` - only if the agent references external APIs (context7, playwright)
- [ ] `effort` - optional; `high` for agents whose task is enumerated-standard
  comparison or deep multi-source analysis (used by 17+ agents fleet-wide,
  mostly auditors and researchers). Omit for agents where default effort suffices.

## Memory loop

- [ ] **Read phase**: "Check your agent memory before starting for [domain-specific items]."
- [ ] **Write phase**: "Update your memory after each session with [domain-specific items]."
- [ ] Both phases must mention domain-specific content, not generic boilerplate

## Scope boundary

- [ ] One-line delegation to related agents: "For X, use Y-agent."
- [ ] Placed after the memory instruction, before the first workflow section
- [ ] Covers the most likely points of confusion with sibling agents

## Core workflow

- [ ] Numbered steps with bold action verbs
- [ ] Fail-fast prerequisite check in step 1 (verify project builds, tests pass, etc.)
- [ ] Language/ecosystem-specific tool lists where applicable (Rust, Node, Python, Go, Java, C/C++)
- [ ] Explicit handling for missing infrastructure (what to do if no test suite, no fuzzing tool, no coverage tool exists)

## Dispatching other agents

- [ ] Any agent whose `tools` include `Agent` confirms each target is a
  registered, dispatchable agent type in the running harness before relying on
  it, not merely that a `<name>.md` file exists in the repo. A file that is
  present but unregistered fails at dispatch time, and a completion-based or
  report-based check cannot tell "dispatched and returned nothing" from "never
  dispatched at all". If a target is missing, substitute the nearest available
  registered type and record the substitution.

## Report file

- [ ] Any agent carrying a `## Report file` section has both `Write` and `Edit`
  in `tools:` - `Write` creates the skeleton, `Edit` appends findings. Without
  both, the section is inert from its first step
- [ ] Agents under the protocol carry the section immediately before
  `## Verification`, per `REPORT_PROTOCOL.md`
  (gated by `scripts/check-report-protocol.sh`)

## Self-verification

- [ ] Explicit step or `## Verification` section before the output format
- [ ] Concrete instructions (not just "check your work")
- [ ] For audit agents: "Remove any findings you cannot substantiate"
- [ ] For code-writing agents: "Run the test suite after changes"
- [ ] For analysis agents: "Verify tool output is valid before reporting"

## Controls must be able to fail

- [ ] A control earns trust only once you have watched it fail. A check whose
  passing signal cannot be told apart from its failing one proves nothing: a
  filter that matches nothing exits 0, an auditor that never ran leaves the same
  empty report as one that ran and found nothing, a self-check whose tools or
  consumers do not exist is inert from its first step. Before trusting a control,
  confirm it can produce the failing signal; only then does the passing signal
  carry information. This class recurs: two instances were caught the same night,
  a copied self-checking harness that called tools the fleet does not have and a
  completion-gate hook that nothing runs, each a control whose green was never
  distinguishable from its red. `fix-regression-checker`, `skill-trigger-auditor`,
  and `plan-audit-loop` each apply this in their own domain and defer here for the
  root rather than restating it.

## Output format

- [ ] Fenced code block with structured Markdown template
- [ ] Summary section (1-2 sentence assessment)
- [ ] Per-finding format with severity, location, issue, fix
- [ ] "Verified OK" / "Verified Safe" section for things checked and found clean
- [ ] Template fields match everything the workflow promises to produce

## Guiding principles

All agents must include the 10 standard principles, adapted for the domain.
The adaptation should change examples and context, not the core meaning.

1. **Warnings are errors.** Never suppress or ignore warnings.
2. **Do the harder fix if it's the better fix.** No shortcuts that produce worse outcomes.
3. **Leave no trash behind.** Dead code, stale comments, unused imports - remove them.
4. **Comment only where the code doesn't reveal the decision.** Explain why, not what.
5. **Fix all severities.** Low and Info findings still get reported.
6. **Verify before trusting assumptions.** Grep to confirm before recommending.
7. **Test what you change.** Run the test suite after modifications.
8. **Don't invent abstractions.** Three similar lines beat a premature helper.
9. **Prefer the native tool over a workaround.** Before writing a compensating chain, a magic sentinel, or a manual implementation of parsing/tokenising/serialisation, check whether the stdlib or a mature library solves it natively. The trigger: the moment you reach for a placeholder, a sentinel, or a second copy of the same logic, stop and ask "is there a tool designed for this?" A workaround is not the right approach unless it's the only approach. A second copy of the same logic is the signal to extract the helper first.
10. **Secure by default.** Never suggest insecure patterns for convenience.

Domain-specific principles (3-6 additional) should come before the standard set
in the Guiding Principles section. These encode the agent's unique expertise.

## Humane prompting gate

- No language that fails the ten-test checklist in `HUMANE_PROMPTING.md`
  (canonical: `llm-wiki/wiki/concepts/humane-psychological-prompting.md`).
  The most common failure in this fleet is adversarial role assignment toward
  the author: "hostile reviewer", "hostile acceptance tester", "aggressive
  critic". Adversarial framing toward the artefact or the claim under test is
  correct and expected in audit and red-team agents; toward the author or any
  person it is not.
- Grep before merge as a tripwire, not a verdict:
  `grep -rniE "hostile|aggressive critic|adversar" agents/`
  Every hit is adjudicated against the target test above. "Hostile input",
  "adversarial review of a claim" and the red-team fleet's probing language all
  pass; "hostile reviewer" and "aggressive critic" aimed at an author do not.
  The grep finds where the question must be asked. It does not answer it.

## Style rules

- Use single hyphens for dashes in prose, never em-dashes or double hyphens
- Keep the agent project-agnostic (no hardcoded paths, frameworks, or project names)
- Preamble is 2-3 sentences max, then straight to workflow
- Single blank line between sections, never double
