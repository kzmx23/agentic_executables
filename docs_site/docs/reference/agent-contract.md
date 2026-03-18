---
title: Agent Page Contract
outline: deep
---

# Agent Page Contract

To keep docs reliably consumable by agents, every task page should follow this schema.

## Required sections

1. `Prerequisites`
2. `Inputs`
3. `Command/API`
4. `Expected Result`
5. `Failure Modes`
6. `Retry Policy`
7. `Next Step`

## URL and heading rules

- One task per page.
- Stable, descriptive slugs.
- No duplicate headings in the same page.
- Avoid vague titles like `Tips` or `More`.

## Command block rules

- Use fenced `bash` blocks for shell commands.
- Put one primary command per block.
- Provide deterministic expected output statements.
- Include recovery command when possible.

## Error handling rules

- Refer to stable error code identifiers.
- Include retryability (`yes/no/maybe`).
- Include one concrete recovery action.

## Machine-readable outputs

- `/llms.txt`: concise index of docs routes.
- `/llms-full.txt`: expanded corpus for retrieval and offline indexing.
