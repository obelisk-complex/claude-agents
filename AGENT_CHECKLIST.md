# Agent Definition Checklist

Every agent in this collection must include the following features. Use this
checklist when creating new agents or auditing existing ones.

## Frontmatter (required fields)

- [ ] `name` - lowercase with hyphens (e.g., `integration-test`)
- [ ] `description` - 1-2 sentences explaining when to use the agent
- [ ] `tools` - only tools the agent actually uses; match to permissionMode
- [ ] `permissionMode` - `plan` for read-only analysis, `acceptEdits` for agents that write code
- [ ] `model` - `sonnet` unless deep reasoning justifies `opus`
- [ ] `maxTurns` - calibrated to workflow complexity (20 for analysts, 25-35 for writers)
- [ ] `memory: project`
- [ ] `color` - unique hex code or named color, no collisions with existing agents
- [ ] `isolation: worktree` - required for agents that write or mutate code
- [ ] `mcpServers` - only if the agent references external APIs (context7, playwright)

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

## Self-verification

- [ ] Explicit step or `## Verification` section before the output format
- [ ] Concrete instructions (not just "check your work")
- [ ] For audit agents: "Remove any findings you cannot substantiate"
- [ ] For code-writing agents: "Run the test suite after changes"
- [ ] For analysis agents: "Verify tool output is valid before reporting"

## Output format

- [ ] Fenced code block with structured Markdown template
- [ ] Summary section (1-2 sentence assessment)
- [ ] Per-finding format with severity, location, issue, fix
- [ ] "Verified OK" / "Verified Safe" section for things checked and found clean
- [ ] Template fields match everything the workflow promises to produce

## Guiding principles

All agents must include the 9 standard principles, adapted for the domain.
The adaptation should change examples and context, not the core meaning.

1. **Warnings are errors.** Never suppress or ignore warnings.
2. **Do the harder fix if it's the better fix.** No shortcuts that produce worse outcomes.
3. **Leave no trash behind.** Dead code, stale comments, unused imports - remove them.
4. **Comment only where the code doesn't reveal the decision.** Explain why, not what.
5. **Fix all severities.** Low and Info findings still get reported.
6. **Verify before trusting assumptions.** Grep to confirm before recommending.
7. **Test what you change.** Run the test suite after modifications.
8. **Don't invent abstractions.** Three similar lines beat a premature helper.
9. **Secure by default.** Never suggest insecure patterns for convenience.

Domain-specific principles (3-6 additional) should come before the standard set
in the Guiding Principles section. These encode the agent's unique expertise.

## Style rules

- Use single hyphens for dashes in prose, never em-dashes or double hyphens
- Keep the agent project-agnostic (no hardcoded paths, frameworks, or project names)
- Preamble is 2-3 sentences max, then straight to workflow
- Single blank line between sections, never double
