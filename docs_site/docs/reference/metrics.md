---
title: Metrics Baseline
outline: deep
---

# Metrics Baseline

This baseline uses current project onboarding surfaces:

- `README.md`
- `agentic_executables_cli/README.md`
- `install.sh`
- `agentic_executables_cli/lib/src/cli.dart`

## North-star metrics

### Time to first success (TTFS)

- Definition: time from landing on docs to successful `ae definition`.
- Target: median under 5 minutes.

### Install success rate

- Definition: successful verification after install attempt.
- Slice by: OS, shell, install mode.
- Target: at least 95%.

### Quickstart completion

- Definition: user/agent completes one post-install workflow.
- Slice by: beginner, developer, agent.
- Target: at least 80%.

### Search-to-success

- Definition: search query leads to task completion without external support.
- Target: at least 70%.

## Current friction baseline (pre-docs-site)

1. No unified docs index for onboarding steps.
2. Install guidance is concise but not role-segmented.
3. No explicit expected-output blocks for each first-run command.
4. No machine-targeted docs index (`llms.txt`, `llms-full.txt`) in site output.
5. No documented onboarding telemetry loop.

## Event instrumentation spec

Track these events:

- `docs_role_selected`
- `install_command_copied`
- `install_completed`
- `verify_command_started`
- `verify_command_succeeded`
- `quickstart_step_completed`
- `search_performed`
- `search_result_clicked`
- `first_success_completed`

Keep telemetry privacy-safe:

- No command payload content.
- No secrets.
- Hash session IDs with short retention.
