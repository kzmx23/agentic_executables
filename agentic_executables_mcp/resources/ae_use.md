# AE Use
## Objective
- Execute `install`, `uninstall`, `update`, and `use` actions deterministically from registry AE files with mandatory validation and concise reporting.

## Inputs
- `context_type`: Must be `project`.
- `action`: One of `install|uninstall|update|use`.
- `library_id`: Registry key in `<language>_<library_name>` format.
- `project_root`: Working path for file and command execution.
- `constraints`: Optional policy limits for versioning, security, or runtime.
- `user_overrides`: Optional explicit deviations approved by the user.

## Action Mapping
| Action | Registry call | Primary file | Lifecycle focus |
| --- | --- | --- | --- |
| install | `get_from_registry(..., action="install")` | `ae_install.md` | Installation, Configuration, Integration |
| uninstall | `get_from_registry(..., action="uninstall")` | `ae_uninstall.md` | Uninstallation |
| update | `get_from_registry(..., action="update")` | `ae_update.md` | Migration, rollback, compatibility |
| use | `get_from_registry(..., action="use")` | `ae_use.md` | Frequent operation patterns |

## Execution Algorithm
1. Parse request into `{action, library_id, project_root, constraints}`.
2. Validate required inputs and reject invalid action-context pairs.
3. Fetch AE file via `manage_ae_registry(operation="get_from_registry", library_id, action)`.
4. Parse required sections from the fetched file and fail fast if structure is incomplete.
5. Build an execution plan that preserves instruction order and validation checkpoints.
6. Apply minimal adaptations only when project structure or tooling requires equivalent mapping.
7. Execute each step sequentially and log command output or file diffs per step.
8. Run all mandatory validation checkpoints for the action before marking success.
9. If any step fails, enter Error Protocol, then retry only the failed scope when safe.
10. Emit Completion Report Format with executed scope, adaptations, validations, and residual risks.

## Adaptation Rules
- Allowed: remap paths to existing project layout while preserving instruction intent.
- Allowed: translate naming conventions (`snake_case` vs `camelCase`) without changing behavior.
- Allowed: swap equivalent package-manager commands (`npm|pnpm|yarn`, `pip|uv`) when semantically identical.
- Allowed: inject project-required wrappers (workspace scripts, task runners) when outputs are unchanged.
- Allowed: parameterize templates with project values (`<path>`, `<module>`, `<version>`).
- Forbidden: skip required steps or validations.
- Forbidden: weaken security controls, remove permission checks, or bypass secrets handling.
- Forbidden: change dependency constraints or migration order without explicit user approval.
- Forbidden: replace documented algorithms with alternative logic.
- Forbidden: invent undocumented cleanup behavior that risks destructive side effects.
- Rule: record every adaptation in the completion report with reason and equivalence statement.

## Validation Protocol
- Preflight checkpoint: verify toolchain, permissions, and required files before execution.
- Step checkpoint: after each major step, confirm expected artifact exists or expected output appears.
- Action checkpoint (`install`): verify dependency presence, integration path, and runtime smoke test.
- Action checkpoint (`uninstall`): verify integration removal, dependency removal, and clean build/test.
- Action checkpoint (`update`): verify target version, migration success, rollback path, and regression smoke test.
- Action checkpoint (`use`): verify usage rule artifacts and at least one successful reference execution.
- Final checkpoint: confirm no mandatory validation was skipped.
- Failure rule: any failed mandatory checkpoint blocks success status.

## Error Protocol
1. Capture error tuple `{step, command_or_edit, message, exit_code, context}`.
2. Classify failure as `precondition`, `execution`, `validation`, or `environment`.
3. Run minimal triage: verify prerequisites, path assumptions, permissions, and version constraints.
4. Apply documented fix if present in AE file; otherwise apply reversible equivalent fix.
5. Re-run only the failed step and directly dependent validations.
6. Escalate to user when failure persists, requires risky changes, or conflicts with constraints.
7. On escalation, include attempted fixes, blocked reason, and exact next decision needed.

## Completion Report Format
- `[ ] Action`: `<install|uninstall|update|use>` on `<library_id>` at `<project_root>`.
- `[ ] Inputs`: constraints and user overrides applied.
- `[ ] Retrieved file`: source identifier and section integrity status.
- `[ ] Executed steps`: ordered list of commands/edits with status.
- `[ ] Adaptations`: each adaptation with equivalence justification.
- `[ ] Validation`: each mandatory checkpoint with pass/fail evidence.
- `[ ] Failures`: unresolved issues or `none`.
- `[ ] Final status`: `success|partial|blocked` with one-line rationale.

## Stop Conditions
- Stop when required inputs are missing and cannot be inferred safely.
- Stop when registry document retrieval fails after retry.
- Stop when mandatory section structure is invalid or incomplete.
- Stop when a step requires destructive or security-sensitive change without approval.
- Stop when repeated retries fail and no reversible mitigation remains.
- Stop when user constraints conflict with AE-required behavior.
