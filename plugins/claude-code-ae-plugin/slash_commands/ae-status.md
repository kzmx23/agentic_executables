---
name: ae-status
description: Run AE 3.0 project-wide status report (tier-classified gap report).
---

Run `ae status` in the current project and present the tier-classified gap report:

- **Tier 1 — invariant violations** (canonical asserts an invariant; no test verifies it)
- **Tier 2 — upstream blockers** (downstream-required features missing/partial in upstream artifacts)
- **Tier 3 — partial features** (referenced canonical features at status `partial`)
- **Tier 4 — unreferenced canonicals** (available in hub but not linked from any artifact)

Format the output as a compact tiered list. For Tier 1+2 entries, prioritize by downstream-count where available.

If the project has no `.ae_hub` directory, suggest `ae hub init --project` and stop.
