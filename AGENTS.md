# CAS Workstation Agent Instructions

## Product Standard

CAS Workstation is a public, Windows-first enterprise bootstrap product for AI-native developers. Changes must be safe, idempotent, testable, and suitable for execution on a developer's primary workstation.

**Core Value:** An AI developer can run one safe, repeatable workflow and receive a complete, working workstation without manually discovering or reconciling prerequisites.

### Modular Context Directory

To save token limits, context rules are localized. Read the nearest `context.md` file before making changes:

- **`scripts/context.md`**: Read for PowerShell automation rules, idempotency constraints, and safety guidelines.
- **`tests/context.md`**: Read for Pester testing framework, static quality, and verification requirements.
- **`schemas/context.md`**: Read for JSON schema contracts and declarative configuration rules.

## Engineering Rules (Global Workstation Constraints)

- Never embed credentials, access tokens, or machine-specific secrets.
- Default destructive operations to dry-run or explicit confirmation.
- Validation: Schemas, Pester tests, static analysis, and clean-machine journeys are release gates.

## Project Skills

Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
