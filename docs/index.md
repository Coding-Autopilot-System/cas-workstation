# CAS Workstation Developer Documentation

Welcome to the **CAS Workstation** documentation. CAS Workstation is the opinionated, Windows-first bootstrap bundle for the **Coding-Autopilot-System (CAS)** ecosystem. It provides a single, unified installation surface for a fully configured, AI-native coding workstation.

## Overview

At its core, CAS Workstation replaces manual tool discovery and configuration with a declarative manifest (`stack.manifest.json`) and a deterministic execution engine. It ensures all AI developers share a consistent environment with the right versions of developer tools, repositories, agent skills, and Model Context Protocol (MCP) clients.

### Key Capabilities

- **Declarative Profiles:** Define explicit tools, repositories, services, and MCP clients for your environment (e.g., `core` vs `full` profiles).
- **Idempotent Operations:** Run `setup.ps1` safely at any time. Unrelated user configurations are preserved, and destructive operations require explicit intent and path-boundary validation.
- **Diagnostics and Validation:** Robust quality gates and schema validation ensure the state of the workstation remains predictable and healthy (`doctor.ps1`).
- **Safe Management:** Operations record explicit ownership under `.cas\managed-state.json`. Uninstalls remove only CAS-managed resources.

## Quick Start

Getting started with CAS Workstation locally is driven by intuitive PowerShell scripts:

```powershell
# Setup the workstation using the default profile
.\setup.ps1 -NonInteractive

# Validate the workstation's health and installed components
.\doctor.ps1

# Start any background services needed for your profile
.\start.ps1
```

## Directory Structure

Here are the key files and directories you'll interact with:

- `stack.manifest.json` - The versioned contract defining the desired workstation state, tools, clients, and repositories.
- `schemas/` - JSON schemas for validation (e.g., machine-readable readiness reports).
- `scripts/Cas.Workstation.psm1` - The shared implementation module powering the operations.
- `docs/` - Project documentation, including the [Architecture Details](./architecture.md) and support matrix.
- `Invoke-Quality.ps1` - The local and CI quality gate verifying Pester tests, static analysis, and contract fixtures.

## Getting Involved

If you're contributing to CAS Workstation, please start by reviewing the [Architecture Document](./architecture.md) to understand the declarative engine and operation flows. Ensure your code satisfies the contributor quality gate (`.\Invoke-Quality.ps1`) before submitting changes.
