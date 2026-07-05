---
name: brainstorming
description: Use this before creative work — features, icons, components, or behavior changes. Explores intent, constraints, and design before implementation.
metadata:
  project: arvia
---

# Brainstorming

## When to Activate (MANDATORY)

Invoke this skill before ANY creative decision:
- Choosing icons, naming things, or designing new UI
- Adding features, components, or modifying behavior
- Making UX decisions where multiple options exist

## Process

1. **Clarify intent** — what problem does this solve? What's the user's real need?
2. **Explore alternatives** — present 3-5 distinct options, not variations of the same idea
3. **Evaluate against constraints** — check each option against:
   - Design tokens (AppColors, AppTypography, AppSpacing)
   - Apple HIG compliance
   - Accessibility (Dynamic Type, VoiceOver, 44pt targets)
   - Dark mode (always-on in this app)
   - Visual consistency with existing patterns
4. **Recommend** — pick a winner with rationale, let the user decide

## Anti-patterns

- Jumping to implementation without exploring alternatives
- Presenting variations of the same idea as "options"
- Ignoring project constraints (AI-slop ban, token-only, dark-only)
- Recommending without evaluating against Apple HIG