---
title: Beginner Track
outline: deep
---

# Beginner Track

Use this path if you want a minimal, low-friction understanding of AE and a verified install.

## Prerequisites

- macOS or Linux terminal access
- `curl` available

## Step 1: Install

```bash
curl -fsSL https://raw.githubusercontent.com/fluent-meaning-symbiotic/agentic_executables/main/install.sh | bash
```

## Step 2: Verify

```bash
ae definition
```

Expected result:

- Command succeeds with structured output.
- You see AE definition metadata.

## Step 3: Understand one real action

```bash
ae instructions --context library --action bootstrap
```

This command shows how AE turns documentation into executable runbooks.

<div class="success-box">
  You are done when both commands complete and you can explain AE in one sentence:
  "AE turns domain knowledge into deterministic instructions that humans and agents execute the same way — for any project type."
</div>

## If something fails

- Go to [Install and verify](/install/).
- Then check [Troubleshooting](/troubleshooting/).
