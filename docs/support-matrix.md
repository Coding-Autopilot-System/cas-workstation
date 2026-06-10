# Support Matrix

## Platform

| Target | Status | Notes |
|---|---|---|
| Windows 11 + PowerShell 5.1+ | Supported | Primary platform for v1 |
| Windows 11 + WSL2 Ubuntu | Supported | Recommended for Linux-style workflows |
| Windows Server | Limited | Use only for controlled automation hosts |
| macOS | Planned | Not a first-class target yet |
| Linux | Planned | Not a first-class target yet |

## Toolchain

| Component | Requirement | Status |
|---|---|---|
| Git | 2.53.0+ | Required |
| GitHub CLI | 2.86.0+ | Required |
| Node.js | 22.x | Required |
| Python | 3.12+ | Required |
| uv | 0.4+ | Required |
| .NET SDK | 10.x | Required |
| Docker Desktop | 29.x | Required for container workflows |
| Azure CLI | 2.80+ | Required for Azure-enabled workflows |
| WSL2 | Ubuntu default distro | Required |
| Codex CLI | 0.125+ | Required |
| Claude Code | 2.0+ | Required |
| Gemini CLI | 0.45+ | Required |

## CAS Components

| Repo | Purpose | Profile |
|---|---|---|
| Promptimprover | Prompt middleware and MCP server | core, full |
| autogen | Local multi-agent runtime | core, full |
| gsd-orchestrator | Autonomous GitHub issue-to-PR engine | core, full |
| autopilot-core | Org-level issue intake and repair automation | full |
| ci-autopilot | CI repair control plane | full |
