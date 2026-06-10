# CAS Workstation Product Brief

## Vision

Provide one trustworthy installation surface that turns a clean Windows
workstation into a complete AI-native development environment for the
Coding-Autopilot-System ecosystem.

## Target User

An AI developer who wants to install, validate, operate, upgrade, and safely
remove a complete coding workstation without manually discovering tools,
repositories, agent skills, MCP configuration, or runtime prerequisites.

## Required Outcomes

- A single documented setup command supports interactive and non-interactive use.
- Setup and upgrade are idempotent and recover safely from partial failure.
- Doctor produces human-readable and schema-valid machine-readable reports.
- Profiles define explicit tools, repositories, services, skills, and clients.
- Generated client configuration never overwrites unrelated user configuration.
- Uninstall removes only CAS-managed resources and supports preview mode.
- Tests cover manifest validation, path safety, configuration generation,
  installation decisions, diagnostics, and destructive-operation guards.
- CI validates PowerShell quality, Pester tests, schemas, and documentation.
- Architecture, threat model, support policy, contribution guide, and release
  process are documented.

## Enterprise Constraints

- Windows-first with concrete support boundaries; WSL may be managed as a
  dependency but is not the primary execution environment.
- No embedded secrets. Authentication remains user-controlled or uses managed
  identity where Azure services are introduced.
- Installation tools and repositories must be allowlisted in the manifest.
- Network downloads and package execution must be observable and auditable.
- Destructive actions require explicit intent and path-boundary validation.

## Initial Delivery Phases

1. Establish project governance, GSD planning, CI, and Pester test foundation.
2. Harden manifest validation, installation idempotency, and path safety.
3. Implement safe client configuration merging and skills/workspace profiles.
4. Add diagnostics, structured logs, recovery, and support bundle generation.
5. Publish release automation, signed artifacts, and end-to-end clean-machine
   verification.

