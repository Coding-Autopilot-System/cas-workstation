# PowerShell Automation Context

## Technology Stack
- **Host automation**: PowerShell 5.1-compatible modules and advanced scripts. Native Windows reach, supports interactive and unattended execution.
- **Package sources**: WinGet and Scoop adapters behind a common interface.

## Guidelines
- **Idempotency**: Changes must be safe, idempotent, testable, and suitable for execution on a developer's primary workstation.
- **Security**: Never embed credentials, access tokens, or machine-specific secrets. Default destructive operations to dry-run or explicit confirmation.
- **State**: Keep installation state and generated configuration under the configured CAS root and profile paths. Versioned JSON operation journal with atomic replacement.
- **Avoid**: Embedding package-manager commands throughout orchestration logic. Treating command presence as proof that an installation is healthy.
