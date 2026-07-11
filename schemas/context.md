# Schema & Validation Context

## Technology Stack
- **Contracts**: JSON Schema Draft 2020-12. Existing doctor schema uses this version; extend to manifest, state, plan, and support bundle.

## Guidelines
- **Validation**: Validate manifest and doctor output against their JSON schemas.
- **Declarative Strategy**: Prefer declarative manifest data over hard-coded tool or repository lists. Tool, repository, service, client, workspace, and skill lists must not be hard-coded.
- **Reference**: JSON Schema 2020-12: https://json-schema.org/draft/2020-12
