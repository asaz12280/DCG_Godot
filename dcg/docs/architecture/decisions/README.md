# Architecture Decision Records

Use this folder for short records of architecture decisions that are hard to reverse or that change project structure.

Create a new file named `YYYYMMDD-short-title.md` when a task introduces:

- A new autoload or project-wide service.
- A new persistence schema or migration.
- A new cross-domain ownership contract.
- A replacement for an established folder, scene, UI, save, or domain-service pattern.
- A choice between two credible architecture approaches where future work needs to know why one was selected.

Keep records short and practical. Routine feature work does not need an ADR.

## Template

```markdown
# ADR YYYYMMDD: Title

## Status

Accepted

## Context

What problem or constraint forced this decision?

## Decision

What did we choose?

## Options Considered

- Option A:
- Option B:

## Consequences

- Positive:
- Negative or tradeoff:

## Validation

What validator, scene startup check, or manual check proves this decision is safe?

## Links

- Related task:
- Related files:
```
