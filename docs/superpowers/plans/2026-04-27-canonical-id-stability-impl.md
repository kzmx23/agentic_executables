# Canonical Id Stability — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make distill incapable of inventing feature ids; introduce proposal-then-accept for cross-cutting concept features; pin cross-run vocabulary via per-concept `DESIGN_FAQ.md`. Closes Iter 1 dogfood §8 items 1, 3, 9, 10.

**Architecture:** Three independently-shippable phases. **Phase A** (validator + prompt + envelope plumbing) is the urgent one — closes the Q1 drift root cause. **Phase B** (sync-symbols + accept-concept commands) makes the workflow operational end-to-end. **Phase C** (FAQ-as-context, reuse-class derivation, migration) is additive polish. Each phase merges to `v2`, ships, and is validated separately. Iter 2 dogfood (separate plan, after C) is the empirical validation gate.

**Design reference:** [`specs/2026-04-27-canonical-id-stability-design.md`](../specs/2026-04-27-canonical-id-stability-design.md). Read its Q&A before starting — every "why" lives there, this plan only carries "how."

**Tech Stack:** Dart 3.11, `package:test`, three-package monorepo (`agentic_executables_core`, `agentic_executables_cli`, `agentic_executables_mcp`), VitePress for docs.

**Constraints:**
- All work happens on a feature branch off `v2`. Each phase merges back to `v2` as one or two commits, no PR required (this repo's pattern). Branch name: `id-stability-phase-{a,b,c}`.
- No CHANGELOG edits inside tasks — accumulate the entry mentally, write it as the last commit of each phase.
- Backward-compatibility constraint: existing canonicals produced before this work must continue to merge cleanly through `mergeDistillationDetailed`. The validator only rejects rows whose id is not in the *pre-distill matrix*; if an old canonical has weird ids, those ids are still in the pre-distill matrix, so distilling against it works. The migration helper (Phase C) is the path to clean those up.

---

## Phase A — Validator + prompt + envelope (id-invention impossible)

**Branch:** `id-stability-phase-a` off `v2`.

**Files touched:**
- `agentic_executables_core/lib/src/models/distillation_task.dart` — extend `DistillationOutput` with `proposedConcepts: List<ProposedConcept>`.
- `agentic_executables_core/lib/src/services/canonical_service.dart` — extend `CanonicalMergeResult` with `proposedConcepts` passthrough.
- `agentic_executables_core/lib/src/services/default_canonical_service.dart` — add the `id_not_in_matrix` validator inside `mergeDistillationDetailed`.
- `agentic_executables_core/lib/src/adapters/claude_code_subagent_executor.dart` — update `_buildPrompt` to include the constraint sentence and document the `proposed_concepts` response field.
- `agentic_executables_core/lib/src/adapters/byok_llm_executor.dart` — same prompt change.
- `agentic_executables_cli/lib/src/cli.dart` — pass `proposed_concepts` through the distill envelope at `_handleCanonicalDistill`.
- `agentic_executables_mcp/lib/src/adapter.dart` — same passthrough at the canonical-distill operation handler.
- `agentic_executables_core/test/default_canonical_service_test.dart` — three new tests (validator pass; validator reject; proposals passthrough).
- `agentic_executables_core/test/distillation_output_test.dart` — new test file; round-trip serialization for proposedConcepts.
- `docs_site/docs/ae-3/cli-reference.md` and `mcp-reference.md` — document the new envelope keys.

### Task A1: Extend `DistillationOutput` with `proposedConcepts`

**Files:**
- Modify: `agentic_executables_core/lib/src/models/distillation_task.dart` (extend `DistillationOutput` near line 105)
- Create: `agentic_executables_core/test/distillation_output_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `agentic_executables_core/test/distillation_output_test.dart`:

```dart
import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:test/test.dart';

void main() {
  group('DistillationOutput.proposedConcepts', () {
    test('defaults to empty list when not provided', () {
      final out = DistillationOutput(
        conceptId: 'x',
        conceptVersion: 1,
        indexMd: '',
        matrix: CanonicalMatrix(
          concept: 'x',
          version: 1,
          columnSchema: const [],
          features: const [],
        ),
      );
      expect(out.proposedConcepts, isEmpty);
    });

    test('round-trips through toJson / fromMap when populated', () {
      final out = DistillationOutput(
        conceptId: 'x',
        conceptVersion: 1,
        indexMd: '',
        matrix: CanonicalMatrix(
          concept: 'x',
          version: 1,
          columnSchema: const [],
          features: const [],
        ),
        proposedConcepts: const [
          ProposedConcept(
            name: 'json-envelope',
            spec: 'every command writes JSON',
            invariant: 'success is bool',
            rationale: 'cross-cutting, no symbol',
          ),
        ],
      );
      final json = out.toJson();
      expect(json['proposed_concepts'], isA<List<dynamic>>());
      expect((json['proposed_concepts'] as List).single['name'], 'json-envelope');

      final round = DistillationOutput.fromMap(json);
      expect(round.proposedConcepts, hasLength(1));
      expect(round.proposedConcepts.single.name, 'json-envelope');
      expect(round.proposedConcepts.single.rationale, 'cross-cutting, no symbol');
    });

    test('fromMap accepts payloads without proposed_concepts (back-compat)', () {
      final json = {
        'schema': 'ae.canonical.draft.v1',
        'concept_id': 'x',
        'concept_version': 1,
        'index_md': '',
        'matrix': {
          'schema': 'ae.canonical_matrix.v1',
          'concept': 'x',
          'version': 1,
          'column_schema': [],
          'features': [],
        },
      };
      final out = DistillationOutput.fromMap(json);
      expect(out.proposedConcepts, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run tests, verify they fail**

```bash
cd agentic_executables_core && dart test test/distillation_output_test.dart
```

Expected: compile failure ("Undefined name `ProposedConcept`", "no parameter `proposedConcepts`"). That's the goal.

- [ ] **Step 3: Add the `ProposedConcept` model**

In `agentic_executables_core/lib/src/models/distillation_task.dart`, just above `class DistillationOutput`:

```dart
/// A cross-cutting concept feature proposed by distill but not yet committed
/// to the matrix. Promoted via `ae canonical accept-concept` (Phase B).
class ProposedConcept {
  const ProposedConcept({
    required this.name,
    required this.spec,
    required this.invariant,
    this.rationale = '',
  });

  /// Human-readable proposal name. NOT a feature id; the operator chooses
  /// the id at acceptance time.
  final String name;
  final String spec;
  final String invariant;

  /// Why this is a concept (cross-cutting) rather than a symbol-derived row.
  final String rationale;

  Map<String, dynamic> toJson() => {
        'name': name,
        'spec': spec,
        'invariant': invariant,
        if (rationale.isNotEmpty) 'rationale': rationale,
      };

  factory ProposedConcept.fromMap(final Map<dynamic, dynamic> map) =>
      ProposedConcept(
        name: map['name']?.toString() ?? '',
        spec: map['spec']?.toString() ?? '',
        invariant: map['invariant']?.toString() ?? '',
        rationale: map['rationale']?.toString() ?? '',
      );
}
```

Then modify `DistillationOutput` to add the field. Replace the existing class definition with:

```dart
class DistillationOutput {
  const DistillationOutput({
    required this.conceptId,
    required this.conceptVersion,
    required this.indexMd,
    required this.matrix,
    this.patternsMd,
    this.proposedConcepts = const [],
  });

  final String conceptId;
  final int conceptVersion;
  final String indexMd;
  final CanonicalMatrix matrix;
  final String? patternsMd;
  final List<ProposedConcept> proposedConcepts;

  Map<String, dynamic> toJson() => {
        'schema': DistillationTask.schemaOut,
        'concept_id': conceptId,
        'concept_version': conceptVersion,
        'index_md': indexMd,
        'matrix': matrix.toJson(),
        if (patternsMd != null) 'patterns_md': patternsMd,
        if (proposedConcepts.isNotEmpty)
          'proposed_concepts': proposedConcepts.map((c) => c.toJson()).toList(),
      };

  factory DistillationOutput.fromMap(final Map<dynamic, dynamic> map) {
    final schema = map['schema']?.toString();
    if (schema != DistillationTask.schemaOut) {
      throw ArgumentError(
        'Expected schema ${DistillationTask.schemaOut}, got $schema',
      );
    }
    final matrixRaw = map['matrix'];
    final matrix = matrixRaw is Map
        ? CanonicalMatrix.fromMap(matrixRaw)
        : throw ArgumentError('DistillationOutput requires "matrix"');
    final proposedRaw = map['proposed_concepts'];
    final proposed = proposedRaw is List
        ? proposedRaw
            .whereType<Map>()
            .map(ProposedConcept.fromMap)
            .toList(growable: false)
        : const <ProposedConcept>[];
    return DistillationOutput(
      conceptId: map['concept_id']?.toString() ?? '',
      conceptVersion: (map['concept_version'] as int?) ?? 1,
      indexMd: map['index_md']?.toString() ?? '',
      matrix: matrix,
      patternsMd: map['patterns_md']?.toString(),
      proposedConcepts: proposed,
    );
  }
}
```

- [ ] **Step 4: Export `ProposedConcept` from the public API**

Open `agentic_executables_core/lib/agentic_executables_core.dart`. Find the line that exports `distillation_task.dart` (or the model barrel that re-exports it). Confirm `ProposedConcept` is reachable from outside the library. If the barrel uses `export 'src/models/distillation_task.dart';` no edit is needed; otherwise add:

```dart
export 'src/models/distillation_task.dart' show DistillationOutput, DistillationTask, ProposedConcept;
```

Run:
```bash
cd agentic_executables_core && dart analyze 2>&1 | tail -10
```

Expected: no analyzer errors. If `ProposedConcept` is "not exported," fix the barrel.

- [ ] **Step 5: Run tests, verify they pass**

```bash
cd agentic_executables_core && dart test test/distillation_output_test.dart
```

Expected: 3 tests passing.

- [ ] **Step 6: Commit**

```bash
git checkout -b id-stability-phase-a
git add agentic_executables_core/lib/src/models/distillation_task.dart \
        agentic_executables_core/lib/agentic_executables_core.dart \
        agentic_executables_core/test/distillation_output_test.dart
git commit -m "feat(core): add ProposedConcept and DistillationOutput.proposedConcepts"
```

### Task A2: Extend `CanonicalMergeResult` with `proposedConcepts` passthrough

**Files:**
- Modify: `agentic_executables_core/lib/src/services/canonical_service.dart` (around line 9-41 — `CanonicalMergeResult` class)
- Modify: `agentic_executables_core/lib/src/services/default_canonical_service.dart` (around line 316-321 and 351-356 — both `CanonicalMergeResult(...)` constructions)
- Modify: `agentic_executables_core/test/default_canonical_service_test.dart` — add proposals-passthrough test

- [ ] **Step 1: Write the failing test**

In `agentic_executables_core/test/default_canonical_service_test.dart`, append a new test inside the existing `group(...)` (file already imports the right symbols; locate the group and add):

```dart
test('mergeDistillationDetailed passes proposedConcepts through verbatim', () async {
  final tmp = await Directory.systemTemp.createTemp('id_stability_a2');
  addTearDown(() async { await tmp.delete(recursive: true); });
  final store = FileCanonicalStore(rootDir: tmp.path);
  final service = DefaultCanonicalService(store: store);

  await service.scaffold('demo', title: 'Demo');

  final output = DistillationOutput(
    conceptId: 'demo',
    conceptVersion: 1,
    indexMd: '# demo',
    matrix: CanonicalMatrix(
      concept: 'demo',
      version: 1,
      columnSchema: const [],
      features: const [],
    ),
    proposedConcepts: const [
      ProposedConcept(
        name: 'envelope-shape',
        spec: 'every command writes JSON',
        invariant: 'success is bool',
        rationale: 'cross-cutting',
      ),
    ],
  );

  final result = await service.mergeDistillationDetailed('demo', output);
  expect(result.proposedConcepts, hasLength(1));
  expect(result.proposedConcepts.single.name, 'envelope-shape');
});
```

- [ ] **Step 2: Run, verify it fails**

```bash
cd agentic_executables_core && dart test test/default_canonical_service_test.dart --name 'proposedConcepts through'
```

Expected: compile failure ("`CanonicalMergeResult` has no parameter `proposedConcepts`").

- [ ] **Step 3: Extend `CanonicalMergeResult`**

In `agentic_executables_core/lib/src/services/canonical_service.dart`, modify the class:

```dart
class CanonicalMergeResult {
  const CanonicalMergeResult({
    required this.pack,
    required this.featureCountReceived,
    required this.featureCountAfterMerge,
    this.duplicateIds = const [],
    this.proposedConcepts = const [],
  });

  final CanonicalPack pack;
  final int featureCountReceived;
  final int featureCountAfterMerge;
  final List<String> duplicateIds;

  /// Cross-cutting concepts proposed by distill but not committed to the
  /// matrix. Promoted via `ae canonical accept-concept` (Phase B). Empty
  /// when distill output had no `proposed_concepts` field.
  final List<ProposedConcept> proposedConcepts;

  bool get hasDuplicates => duplicateIds.isNotEmpty;

  List<String> get warnings => duplicateIds.isEmpty
      ? const []
      : [
          'distill output contained ${duplicateIds.length} duplicate '
              'feature id(s); collapsed by last-write-wins: '
              '${duplicateIds.join(', ')}',
        ];
}
```

Add the `ProposedConcept` import at the top of the file:

```dart
import '../models/distillation_task.dart' show DistillationOutput, ProposedConcept;
```

(If the existing import already pulls `DistillationOutput`, just add `ProposedConcept` to the show clause.)

- [ ] **Step 4: Pass through in both merge branches**

In `agentic_executables_core/lib/src/services/default_canonical_service.dart`, both `CanonicalMergeResult(...)` constructions (around lines 316-321 and 351-356) must add `proposedConcepts: output.proposedConcepts`:

```dart
return CanonicalMergeResult(
  pack: pack,
  featureCountReceived: output.matrix.features.length,
  featureCountAfterMerge: dedupedMatrix.features.length,
  duplicateIds: duplicateIds,
  proposedConcepts: output.proposedConcepts,
);
```

And the second one similarly. Use `Edit` with enough context to disambiguate the two sites (or `replace_all` is unsafe here — disambiguate by the surrounding lines).

- [ ] **Step 5: Run tests, verify they pass**

```bash
cd agentic_executables_core && dart test test/default_canonical_service_test.dart
```

Expected: all tests pass, including the new `proposedConcepts through` test.

- [ ] **Step 6: Commit**

```bash
git add agentic_executables_core/lib/src/services/canonical_service.dart \
        agentic_executables_core/lib/src/services/default_canonical_service.dart \
        agentic_executables_core/test/default_canonical_service_test.dart
git commit -m "feat(core): pass proposedConcepts through CanonicalMergeResult"
```

### Task A3: Add the `id_not_in_matrix` validator

**Files:**
- Modify: `agentic_executables_core/lib/src/services/canonical_service.dart` — add `IdNotInMatrixException`.
- Modify: `agentic_executables_core/lib/src/services/default_canonical_service.dart` — guard inside `mergeDistillationDetailed` *before* the merge branch.
- Modify: `agentic_executables_core/test/default_canonical_service_test.dart` — two new tests (rejects unknown ids; accepts known ids).

- [ ] **Step 1: Write the failing tests**

Append to the existing test group in `default_canonical_service_test.dart`:

```dart
test('mergeDistillationDetailed rejects feature rows with ids not in pre-distill matrix', () async {
  final tmp = await Directory.systemTemp.createTemp('id_stability_a3_reject');
  addTearDown(() async { await tmp.delete(recursive: true); });
  final store = FileCanonicalStore(rootDir: tmp.path);
  final service = DefaultCanonicalService(store: store);

  // Seed an existing canonical with a single known id.
  await service.scaffold('demo', title: 'Demo');
  final seeded = _samplePack('demo', features: [
    CanonicalFeature(id: FeatureId('demo.known'), cells: const {
      'spec': 'spec', 'invariant': 'inv',
    }),
  ]);
  await service.upsert('demo', seeded);

  // Distill output emits a row whose id is NOT in matrix.
  final output = DistillationOutput(
    conceptId: 'demo',
    conceptVersion: 1,
    indexMd: '',
    matrix: CanonicalMatrix(
      concept: 'demo',
      version: 1,
      columnSchema: const [],
      features: [
        CanonicalFeature(id: FeatureId('demo.invented'), cells: const {
          'spec': 'spec', 'invariant': 'inv',
        }),
      ],
    ),
  );

  expect(
    () => service.mergeDistillationDetailed('demo', output),
    throwsA(isA<IdNotInMatrixException>()
      .having((e) => e.unknownIds, 'unknownIds', contains('demo.invented'))),
  );
});

test('mergeDistillationDetailed accepts feature rows with ids that ARE in pre-distill matrix', () async {
  final tmp = await Directory.systemTemp.createTemp('id_stability_a3_accept');
  addTearDown(() async { await tmp.delete(recursive: true); });
  final store = FileCanonicalStore(rootDir: tmp.path);
  final service = DefaultCanonicalService(store: store);

  await service.scaffold('demo', title: 'Demo');
  final seeded = _samplePack('demo', features: [
    CanonicalFeature(id: FeatureId('demo.known'), cells: const {
      'spec': 'old', 'invariant': 'old',
    }),
  ]);
  await service.upsert('demo', seeded);

  final output = DistillationOutput(
    conceptId: 'demo',
    conceptVersion: 1,
    indexMd: '',
    matrix: CanonicalMatrix(
      concept: 'demo',
      version: 1,
      columnSchema: const [],
      features: [
        CanonicalFeature(id: FeatureId('demo.known'), cells: const {
          'spec': 'enriched', 'invariant': 'enriched',
        }),
      ],
    ),
  );

  final result = await service.mergeDistillationDetailed('demo', output);
  expect(result.featureCountAfterMerge, 1);
  expect(result.pack.matrix.features.single.cells['spec'], 'enriched');
});

test('mergeDistillationDetailed accepts an empty matrix when proposedConcepts is non-empty', () async {
  final tmp = await Directory.systemTemp.createTemp('id_stability_a3_empty');
  addTearDown(() async { await tmp.delete(recursive: true); });
  final store = FileCanonicalStore(rootDir: tmp.path);
  final service = DefaultCanonicalService(store: store);

  await service.scaffold('demo', title: 'Demo');

  final output = DistillationOutput(
    conceptId: 'demo',
    conceptVersion: 1,
    indexMd: '',
    matrix: CanonicalMatrix(
      concept: 'demo',
      version: 1,
      columnSchema: const [],
      features: const [],
    ),
    proposedConcepts: const [
      ProposedConcept(
        name: 'envelope',
        spec: 'JSON', invariant: 'bool', rationale: 'cross-cutting',
      ),
    ],
  );

  final result = await service.mergeDistillationDetailed('demo', output);
  expect(result.featureCountAfterMerge, 0);
  expect(result.proposedConcepts, hasLength(1));
});
```

(Note: `_samplePack` is the helper at the top of the existing test file; reuse it. `FeatureId` is the existing model; if its constructor is `FeatureId.parse('demo.known')` instead of `FeatureId('demo.known')`, adjust to match the codebase's pattern — confirm with one `grep -rn 'FeatureId(' agentic_executables_core/test` before writing.)

- [ ] **Step 2: Run, verify they fail**

```bash
cd agentic_executables_core && dart test test/default_canonical_service_test.dart
```

Expected: compile failure ("Undefined name `IdNotInMatrixException`") plus failing assertions.

- [ ] **Step 3: Define the exception**

In `agentic_executables_core/lib/src/services/canonical_service.dart`, append (above the `abstract interface class CanonicalService` declaration):

```dart
/// Thrown by [CanonicalService.mergeDistillationDetailed] when the distill
/// output contains feature rows whose `id` is not in the pre-distill
/// matrix. This enforces the id-stability contract: distill enriches; it
/// does not invent. New cross-cutting features must arrive as
/// [ProposedConcept] entries instead.
class IdNotInMatrixException implements Exception {
  const IdNotInMatrixException({
    required this.conceptId,
    required this.unknownIds,
    required this.knownIdCount,
  });

  final String conceptId;
  final List<String> unknownIds;
  final int knownIdCount;

  @override
  String toString() =>
      'IdNotInMatrixException(concept: $conceptId, unknown: $unknownIds, known: $knownIdCount)';
}
```

- [ ] **Step 4: Add the validator inside `mergeDistillationDetailed`**

In `agentic_executables_core/lib/src/services/default_canonical_service.dart`, locate `mergeDistillationDetailed`. **Before** the existing `final existing = await store.load(conceptId);` line (or right after, whichever happens first — find the variable that holds the pre-distill matrix), insert:

```dart
// Id-stability guard: every feature row in the distill output must have an
// id that is already present in the pre-distill matrix. New cross-cutting
// features arrive via output.proposedConcepts instead. See
// docs/superpowers/specs/2026-04-27-canonical-id-stability-design.md Q7.
final existing = await store.load(conceptId);
if (existing != null) {
  final knownIds = <String>{
    for (final f in existing.matrix.features) f.id.toString(),
  };
  final unknownIds = <String>[
    for (final f in output.matrix.features)
      if (!knownIds.contains(f.id.toString())) f.id.toString(),
  ];
  if (unknownIds.isNotEmpty) {
    throw IdNotInMatrixException(
      conceptId: conceptId,
      unknownIds: unknownIds,
      knownIdCount: knownIds.length,
    );
  }
}
// (existing merge logic continues with the same `existing` variable below)
```

Important: the existing code may already load `existing` further down. If it does, **move** that load up to where the validator runs and remove the duplicate load — there's no behavior difference, just don't load twice.

- [ ] **Step 5: Run tests, verify they pass**

```bash
cd agentic_executables_core && dart test test/default_canonical_service_test.dart
```

Expected: all tests pass, including the three new ones.

- [ ] **Step 6: Run the full core test suite to catch regressions**

```bash
cd agentic_executables_core && dart test
```

Expected: all tests pass. If any pre-existing distillation test broke, it likely relied on the old "distill can write any id" behavior — fix the test to seed a matching matrix first, don't relax the validator.

- [ ] **Step 7: Commit**

```bash
git add agentic_executables_core/lib/src/services/canonical_service.dart \
        agentic_executables_core/lib/src/services/default_canonical_service.dart \
        agentic_executables_core/test/default_canonical_service_test.dart
git commit -m "feat(core): id-stability validator on mergeDistillationDetailed"
```

### Task A4: Update the distill prompt template

**Files:**
- Modify: `agentic_executables_core/lib/src/adapters/claude_code_subagent_executor.dart` (around line 71-80, `_buildPrompt`).
- Modify: `agentic_executables_core/lib/src/adapters/byok_llm_executor.dart` (analogous prompt builder — confirm via `grep -n "Return ONLY" agentic_executables_core/lib/src/adapters/byok_llm_executor.dart`).

The prompt change is small but load-bearing. Both executors get the same constraint sentence to keep behavior consistent across dispatch targets.

- [ ] **Step 1: Update `claude_code_subagent_executor._buildPrompt`**

Replace the existing return statement in `_buildPrompt` (line ~73 onward) with:

```dart
  String _buildPrompt(final DistillationTask task) {
    final taskJson = const JsonEncoder.withIndent('  ').convert(task.toJson());
    return '''
You are running an AE distillation task. Return ONLY a JSON object that matches schema_out (`ae.canonical.draft.v1`). Do not wrap in prose; if you must, place the JSON in a single ```json fenced code block. No commentary outside the JSON.

ID STABILITY RULES (mandatory):
1. Every feature row you emit MUST have an `id` that already appears in the input task's `matrix_seed_rows`. You are enriching existing rows, not inventing new ones.
2. If you encounter a cross-cutting invariant that does not correspond to any seeded id (e.g. "all commands write a JSON envelope"), DO NOT create a feature row for it. Instead, append it to a top-level `proposed_concepts` array on your response, with shape:
   `{ "name": "<short-kebab-name>", "spec": "...", "invariant": "...", "rationale": "why this is cross-cutting, not a symbol" }`
3. If a seeded row is missing in the input but you believe a new symbol exists in the source artifact, DO NOT invent its id. Surface it as `proposed_concepts` with rationale "missing-from-scaffold; rerun ae canonical scaffold --update".

Schema reminder: the response object has top-level keys `schema`, `concept_id`, `concept_version`, `index_md`, `matrix`, optional `patterns_md`, optional `proposed_concepts`.

```json
$taskJson
```
''';
  }
```

- [ ] **Step 2: Apply the same change in `byok_llm_executor.dart`**

```bash
grep -n "Return ONLY" agentic_executables_core/lib/src/adapters/byok_llm_executor.dart
```

Locate the existing prompt builder (likely a similar `_buildPrompt` or inline string). Replace its prompt string with the same constraint block. If the byok variant doesn't have an exact match for the structure, mirror the three numbered rules and the "schema reminder" verbatim.

- [ ] **Step 3: Run executor tests to confirm prompt changes don't break parsing**

```bash
cd agentic_executables_core && dart test test/claude_code_subagent_executor_test.dart test/byok_llm_executor_test.dart
```

Expected: all existing tests pass. The prompt is a string the executor builds and sends; existing tests usually mock the dispatch and assert on the parsed output, so they should be insensitive to prompt content. If a test asserts the literal prompt string, update it to assert on the new substring (`'ID STABILITY RULES'`).

- [ ] **Step 4: Commit**

```bash
git add agentic_executables_core/lib/src/adapters/claude_code_subagent_executor.dart \
        agentic_executables_core/lib/src/adapters/byok_llm_executor.dart
git commit -m "feat(core): pin distill prompt — never invent ids; use proposed_concepts"
```

### Task A5: Pass `proposed_concepts` through the CLI envelope

**Files:**
- Modify: `agentic_executables_cli/lib/src/cli.dart` (`_handleCanonicalDistill`, around lines 2364-2381 in the current tree).
- Modify: `agentic_executables_cli/test/cli_test.dart` (or whichever test file covers `_handleCanonicalDistill` — find via `grep -rln '_handleCanonicalDistill\|canonical distill' agentic_executables_cli/test`).

- [ ] **Step 1: Write the failing test**

Add to the relevant CLI test file (likely `agentic_executables_cli/test/canonical_distill_test.dart` if it exists, otherwise `cli_test.dart`):

```dart
test('canonical distill envelope includes proposed_concepts when set', () async {
  // Build a fake DistillationService that returns a result with one proposal.
  final fake = _FakeDistillationService(output: DistillationOutput(
    conceptId: 'demo',
    conceptVersion: 1,
    indexMd: '',
    matrix: CanonicalMatrix(
      concept: 'demo', version: 1, columnSchema: const [], features: const [],
    ),
    proposedConcepts: const [
      ProposedConcept(name: 'envelope', spec: 's', invariant: 'i', rationale: 'r'),
    ],
  ));
  // Invoke the CLI's canonical-distill handler with `fake` injected
  // (the existing test fixtures should already inject services; mirror their
  // pattern). Assert:
  // - envelope.success == true
  // - envelope.data['proposed_concepts'] is a List of length 1
  // - envelope.data['proposed_concepts'][0]['name'] == 'envelope'
});
```

(Use the existing test's fake-service injection pattern verbatim — don't invent a new pattern. Find the closest existing test that hits `_handleCanonicalDistill` and copy its scaffolding.)

- [ ] **Step 2: Run, verify it fails**

```bash
cd agentic_executables_cli && dart test --name 'proposed_concepts'
```

Expected: assertion failure on `envelope.data['proposed_concepts']` being absent.

- [ ] **Step 3: Modify `_handleCanonicalDistill`**

In `agentic_executables_cli/lib/src/cli.dart`, locate the success-path return inside `_handleCanonicalDistill` (around line 2370):

```dart
return AeResult.ok(
  {
    'concept': concept,
    'version': merged.meta.version,
    'feature_count': mergeReport.featureCountAfterMerge,
    'feature_count_received': mergeReport.featureCountReceived,
    'feature_count_after_merge': mergeReport.featureCountAfterMerge,
    'mode': mode,
    'executor_used': result.executorId,
    if (mergeReport.proposedConcepts.isNotEmpty)
      'proposed_concepts': mergeReport.proposedConcepts
          .map((c) => c.toJson())
          .toList(),
  },
  warnings: mergeReport.warnings,
);
```

The only change is the conditional `if (mergeReport.proposedConcepts.isNotEmpty)` block. Keep all existing keys intact — they're now-load-bearing (per [cli-reference.md L132+](../../../docs_site/docs/ae-3/cli-reference.md)).

- [ ] **Step 4: Run tests, verify they pass**

```bash
cd agentic_executables_cli && dart test
```

Expected: all tests pass including the new one.

- [ ] **Step 5: Commit**

```bash
git add agentic_executables_cli/lib/src/cli.dart agentic_executables_cli/test/
git commit -m "feat(cli): expose proposed_concepts in ae canonical distill envelope"
```

### Task A6: Pass `proposed_concepts` through the MCP envelope

**Files:**
- Modify: `agentic_executables_mcp/lib/src/adapter.dart` (around lines 898-907, the `_handleCanonicalDistill` analogue or whatever the canonical-distill operation handler is named — find via `grep -n 'feature_count_after_merge' agentic_executables_mcp/lib/src/adapter.dart`).
- Modify: `agentic_executables_mcp/test/adapter_test.dart` (or analogous).

- [ ] **Step 1: Write the failing MCP test**

Mirror the CLI test structure in the MCP adapter test. Inject the same fake service; assert `data['proposed_concepts']` is present in the response.

- [ ] **Step 2: Modify the adapter**

In `agentic_executables_mcp/lib/src/adapter.dart`, the canonical-distill operation handler returns a `data` map nearly identical to the CLI's. Add the same conditional block:

```dart
if (mergeReport.proposedConcepts.isNotEmpty)
  'proposed_concepts': mergeReport.proposedConcepts.map((c) => c.toJson()).toList(),
```

- [ ] **Step 3: Run tests**

```bash
cd agentic_executables_mcp && dart test
```

Expected: pass.

- [ ] **Step 4: Commit**

```bash
git add agentic_executables_mcp/lib/src/adapter.dart agentic_executables_mcp/test/
git commit -m "feat(mcp): expose proposed_concepts in ae_canonical distill envelope"
```

### Task A7: Document the new envelope keys

**Files:**
- Modify: `docs_site/docs/ae-3/cli-reference.md` (`### ae canonical distill` section, around line 132).
- Modify: `docs_site/docs/ae-3/mcp-reference.md` (`ae_canonical` distill operation, around line 85).

- [ ] **Step 1: Update CLI reference**

In `docs_site/docs/ae-3/cli-reference.md`, locate the existing envelope description we landed earlier. Replace the relevant paragraph with:

```markdown
Envelope `data` keys: `concept`, `version`, `feature_count` (alias for `feature_count_after_merge`, retained for back-compat), `feature_count_received`, `feature_count_after_merge`, `mode`, `executor_used`, and `proposed_concepts` (only present when non-empty). Each entry in `proposed_concepts` has `name`, `spec`, `invariant`, and optional `rationale`; promote one to a matrix row via `ae canonical accept-concept` (Phase B; see [id-stability design](../../../docs/superpowers/specs/2026-04-27-canonical-id-stability-design.md) Q5).

Distill never invents feature ids — every row it emits must already be in the matrix. New symbol-derived features arrive via `ae canonical scaffold` / `--update`; new cross-cutting concepts arrive via `proposed_concepts` and an explicit `accept-concept`. Rejected ids surface as a non-zero envelope with `error.code = "id_not_in_matrix"`.

When the received and post-merge counts diverge, duplicate-id collisions are reported in the envelope's `warnings` array (3.0.2).
```

- [ ] **Step 2: Update MCP reference**

In `docs_site/docs/ae-3/mcp-reference.md`, find the paragraph that documents the `distill` operation's `data` keys and add `proposed_concepts` to the list with the same description.

- [ ] **Step 3: Verify the docs site builds**

```bash
cd docs_site && npm run build 2>&1 | tail -5
```

Expected: `build complete in N.NNs.` No broken links.

- [ ] **Step 4: Commit**

```bash
git add docs_site/docs/ae-3/cli-reference.md docs_site/docs/ae-3/mcp-reference.md
git commit -m "docs(site): document proposed_concepts and id-stability validator in distill envelope"
```

### Task A8: Smoke test on the dogfood-iter-1 hub

This is **manual verification** — proves the new contract end-to-end on the same artifacts Iter 1 used.

- [ ] **Step 1: Compile the post-Phase-A binary**

```bash
cd agentic_executables_cli && dart pub get && cd ..
dart compile exe agentic_executables_cli/bin/ae.dart -o /tmp/ae-phase-a
/tmp/ae-phase-a --help | head -5
```

Expected: compile in ~2-3s. `--help` runs.

- [ ] **Step 2: Force the validator: distill against an empty matrix**

```bash
mv .ae_hub .ae_hub.preserve.phase-a 2>/dev/null || true
/tmp/ae-phase-a hub init --project
/tmp/ae-phase-a init --root .
/tmp/ae-phase-a canonical init --concept ae_cli_test --title "AE CLI" --root .
/tmp/ae-phase-a canonical distill --pack agentic_executables_cli --concept ae_cli_test --root . | tee /tmp/phase-a-empty.json
```

Expected: under the new prompt, the LLM cannot emit feature rows (because the matrix is empty, so no row id is "in matrix"). The envelope should either:
- Succeed with `feature_count: 0` and a populated `proposed_concepts` array (LLM correctly routed everything to proposals); OR
- Fail with `error.code: id_not_in_matrix` (LLM ignored the rule and the validator caught it).

Both are acceptable Phase A outcomes — the first is "LLM follows new rule," the second is "validator stops drift even when LLM ignores rule." Record which.

- [ ] **Step 3: Scaffold first, then distill — the new happy path**

```bash
rm -rf .ae_hub/canonical/ae_cli_test
/tmp/ae-phase-a canonical scaffold --concept ae_cli_test --title "AE CLI" --from-artifact agentic_executables_cli --root .
SCAFFOLD_COUNT=$(grep -c '^  - id:' .ae_hub/canonical/ae_cli_test/matrix.yaml)
echo "scaffold_count: $SCAFFOLD_COUNT"
/tmp/ae-phase-a canonical distill --pack agentic_executables_cli --concept ae_cli_test --root . | tee /tmp/phase-a-scaffolded.json
DISTILL_COUNT=$(grep -c '^  - id:' .ae_hub/canonical/ae_cli_test/matrix.yaml)
echo "distill_count: $DISTILL_COUNT"
```

Expected: `scaffold_count == distill_count` (or `distill_count >= scaffold_count` if we accept new symbols mid-run, which Phase A does not). Both numbers should be > 0.

- [ ] **Step 4: Determinism re-check (mini-Q1)**

```bash
rm -rf .ae_hub/canonical/ae_cli_test
/tmp/ae-phase-a canonical scaffold --concept ae_cli_test --title "AE CLI" --from-artifact agentic_executables_cli --root .
/tmp/ae-phase-a canonical distill --pack agentic_executables_cli --concept ae_cli_test --root . > /tmp/phase-a-run-x.json
cp .ae_hub/canonical/ae_cli_test/matrix.yaml /tmp/phase-a-matrix-x.yaml
rm -rf .ae_hub/canonical/ae_cli_test
/tmp/ae-phase-a canonical scaffold --concept ae_cli_test --title "AE CLI" --from-artifact agentic_executables_cli --root .
/tmp/ae-phase-a canonical distill --pack agentic_executables_cli --concept ae_cli_test --root . > /tmp/phase-a-run-y.json
cp .ae_hub/canonical/ae_cli_test/matrix.yaml /tmp/phase-a-matrix-y.yaml

awk '/^  - id:/ {print $3}' /tmp/phase-a-matrix-x.yaml | sort -u > /tmp/ids-x
awk '/^  - id:/ {print $3}' /tmp/phase-a-matrix-y.yaml | sort -u > /tmp/ids-y
echo "x_ids: $(wc -l < /tmp/ids-x)"
echo "y_ids: $(wc -l < /tmp/ids-y)"
echo "common: $(comm -12 /tmp/ids-x /tmp/ids-y | wc -l)"
echo "only_in_x: $(comm -23 /tmp/ids-x /tmp/ids-y | wc -l)"
echo "only_in_y: $(comm -13 /tmp/ids-x /tmp/ids-y | wc -l)"
```

Expected: `common == x_ids == y_ids`, `only_in_x == 0`, `only_in_y == 0`. **This is the gate** — if the id sets aren't identical, Phase A's prompt + validator combo isn't tight enough and we revisit.

- [ ] **Step 5: Restore the v2 hub backup**

```bash
rm -rf .ae_hub
[ -d .ae_hub.preserve.phase-a ] && mv .ae_hub.preserve.phase-a .ae_hub
git status --short
```

Expected: working tree clean modulo `.DS_Store`.

- [ ] **Step 6: Commit the smoke-test results as a side note**

```bash
mkdir -p docs/superpowers/notes/phase-a-smoke
cp /tmp/phase-a-empty.json /tmp/phase-a-scaffolded.json /tmp/phase-a-run-x.json /tmp/phase-a-run-y.json /tmp/phase-a-matrix-x.yaml /tmp/phase-a-matrix-y.yaml docs/superpowers/notes/phase-a-smoke/
cat > docs/superpowers/notes/phase-a-smoke/SUMMARY.md <<EOF
# Phase A smoke

- Empty-matrix outcome: <fill-in: clean ok / id_not_in_matrix>
- Scaffold count: <fill-in>
- Distill count: <fill-in>
- Determinism mini-Q1: x=<n>, y=<n>, common=<n>, only_in_{x,y}=<n,n>
- Verdict: <pass / fail>
EOF
# Hand-edit SUMMARY.md to fill in the actual numbers from steps 2-4
git add docs/superpowers/notes/phase-a-smoke/
git commit -m "test(phase-a): smoke validation on dogfood-iter-1 artifacts"
```

- [ ] **Step 7: Merge Phase A back to v2**

```bash
git checkout v2
git merge --no-ff id-stability-phase-a -m "feat: id-stability phase A — distill cannot invent ids"
git log --oneline | head -10
```

Expected: a merge commit landing the seven Phase A commits on `v2`.

---

## Phase B — sync-symbols + accept-concept (operator workflow)

**Branch:** committed directly to `v2` (operator override of the per-phase feature-branch pattern).

**Goal:** Make the operator workflow end-to-end. After Phase A, `distill` cannot invent ids — but the operator has no way to (a) reconcile the matrix with source-symbol changes, (b) promote distill's proposed concepts to stable rows, or (c) close the empty-matrix bypass left over from Phase A. Phase B closes those gaps in seven tasks.

**Files touched (summary):**
- `agentic_executables_core/lib/src/services/canonical_service.dart` — new types: `ScaffoldUpdateReport`, `ProposalNotFoundException`, `IdCollisionException`. Extend interface with `scaffoldUpdate`, `acceptConcept`, `writeProposalsFile` methods.
- `agentic_executables_core/lib/src/services/default_canonical_service.dart` — implementations of the new methods; unify the validator inside `mergeDistillationDetailed` (B0).
- `agentic_executables_core/lib/src/models/canonical_pack.dart` — extend `CanonicalFeature` with optional `removed` and `renamedTo` fields (additive, defaults preserve back-compat).
- `agentic_executables_cli/lib/src/cli.dart` — `--update`, repeatable `--rename`, new `accept-concept` subcommand, `.last_proposals.json` write at distill end.
- `agentic_executables_mcp/lib/src/adapter.dart` — same surface as CLI on the `ae_canonical` tool.
- Three test files (one per package) gain ~12, ~4, ~3 tests respectively.
- `docs_site/docs/ae-3/cli-reference.md`, `mcp-reference.md`, `docs/error_code_playbook.md`.
- New smoke artifacts at `docs/superpowers/notes/phase-b-smoke/`.

**Task ordering rationale:** B0 first (independent, closes the residual Phase A loophole). B1 (scaffold update) then B2 (rename, extends B1's API). B3 (persist proposals at distill end) before B4 (accept-concept reads the file B3 writes). B5 documents what B0–B4 added. B6 is the empirical gate. Each task is one commit (plus follow-up reviewer fixes if needed).

### Task B0: Close empty-matrix validator bypass (M2 strict)

**Why:** Phase A's validator runs only when `existing != null`. After `canonical init` (which calls `scaffold` and creates a pack with empty features), `existing` is non-null and the validator catches drift correctly — but if the operator skips `init` entirely and runs `distill` first, `store.load()` returns null and the validator is bypassed. Phase A's smoke note flagged this as M2/deferred. Strict fix: run the validator unconditionally so distill cannot create a pack from scratch.

**Files:**
- Modify: `agentic_executables_core/lib/src/services/default_canonical_service.dart` — lines 281-302 (validator block).
- Modify: `agentic_executables_core/test/default_canonical_service_test.dart` — append two new tests.
- Modify: `docs/superpowers/specs/2026-04-27-canonical-id-stability-design.md` — Q12 (migration path) note.

- [ ] **Step 1: Write the failing tests**

Append to the existing `group('DefaultCanonicalService', ...)` in `agentic_executables_core/test/default_canonical_service_test.dart`:

```dart
test('mergeDistillationDetailed rejects features when no canonical exists yet', () async {
  // Empty-matrix bypass closure (M2). Pre-Phase B, distill against a missing
  // concept silently created a pack from the LLM output. Now: validator runs
  // unconditionally; the operator must scaffold or init first.
  final tmp = await Directory.systemTemp.createTemp('id_stability_b0_no_pack');
  addTearDown(() async {
    await tmp.delete(recursive: true);
  });
  final store = FileCanonicalStore(tmp.path);
  final service = DefaultCanonicalService(store: store);

  // Note: NO scaffold/init. `existing` will be null inside the merge.
  final output = DistillationOutput(
    conceptId: 'demo',
    conceptVersion: 1,
    indexMd: '',
    matrix: CanonicalMatrix(
      concept: 'demo',
      version: 1,
      columnSchema: const [],
      features: [
        CanonicalFeature(
          id: FeatureId.parse('demo.invented'),
          cells: const {'spec': 's', 'invariant': 'i'},
        ),
      ],
    ),
  );

  expect(
    () => service.mergeDistillationDetailed('demo', output),
    throwsA(isA<IdNotInMatrixException>()
        .having((final e) => e.knownIdCount, 'knownIdCount', 0)
        .having((final e) => e.unknownIds, 'unknownIds', ['demo.invented'])),
  );
});

test('mergeDistillationDetailed accepts empty-features output even with no canonical', () async {
  // Counterpart to the rejection test: when the LLM correctly produces zero
  // features (e.g. all signal routed to proposed_concepts), the validator
  // does NOT trip. This is the "init alone, then distill rejects all" path
  // closing cleanly when distill respects the contract.
  final tmp = await Directory.systemTemp.createTemp('id_stability_b0_empty_ok');
  addTearDown(() async {
    await tmp.delete(recursive: true);
  });
  final store = FileCanonicalStore(tmp.path);
  final service = DefaultCanonicalService(store: store);

  final output = DistillationOutput(
    conceptId: 'demo',
    conceptVersion: 1,
    indexMd: '',
    matrix: CanonicalMatrix(
      concept: 'demo',
      version: 1,
      columnSchema: const [],
      features: const [],
    ),
    proposedConcepts: const [
      ProposedConcept(
        name: 'envelope',
        spec: 's', invariant: 'i', rationale: 'cross-cutting',
      ),
    ],
  );

  // No canonical exists. Output has zero features. Should succeed and create
  // the pack from the (empty) output, carrying the proposals through.
  final result = await service.mergeDistillationDetailed('demo', output);
  expect(result.featureCountAfterMerge, 0);
  expect(result.proposedConcepts, hasLength(1));
});
```

- [ ] **Step 2: Run, verify the rejection test fails (and the second passes incidentally)**

```bash
cd agentic_executables_core && dart test test/default_canonical_service_test.dart --name 'no canonical exists yet'
```

Expected: failure ("Expected throw" — the current code creates the pack instead of throwing).

- [ ] **Step 3: Unify the validator block**

In `agentic_executables_core/lib/src/services/default_canonical_service.dart`, replace the existing validator block (around lines 283-302) with one that runs unconditionally:

```dart
    final existing = await store.load(conceptId);

    // Id-stability guard: every feature row in the distill output must have
    // an id that is already present in the pre-distill matrix. New cross-
    // cutting features arrive via output.proposedConcepts instead. Runs
    // unconditionally — when no canonical exists yet, knownIds is empty and
    // any non-empty output.matrix.features is rejected (forces scaffold-or-
    // init first). See specs/2026-04-27-canonical-id-stability-design.md Q7
    // and Q12 for the empty-matrix-bypass closure (M2).
    final knownIds = <String>{
      if (existing != null)
        for (final f in existing.matrix.features) f.id.toString(),
    };
    final unknownIds = <String>[
      for (final f in output.matrix.features)
        if (!knownIds.contains(f.id.toString())) f.id.toString(),
    ];
    if (unknownIds.isNotEmpty) {
      throw IdNotInMatrixException(
        conceptId: conceptId,
        unknownIds: unknownIds,
        knownIdCount: knownIds.length,
      );
    }
```

- [ ] **Step 4: Run all core tests, verify they pass**

```bash
cd agentic_executables_core && dart test
```

Expected: 225 tests pass (Phase A baseline 223 + 2 new). If any pre-existing test breaks, it relies on the old "distill creates from scratch" path — the fix is to seed (`scaffold` or `upsert`) a matching matrix in that test, not to relax the validator.

- [ ] **Step 5: Run CLI + MCP suites for regressions**

```bash
cd agentic_executables_cli && dart test 2>&1 | tail -3
cd ../agentic_executables_mcp && dart test 2>&1 | tail -3
```

Expected: CLI 63 passing, MCP 47 passing (Phase A baseline; B0 adds no CLI/MCP tests yet).

- [ ] **Step 6: Update Q12 in the design doc**

Open `docs/superpowers/specs/2026-04-27-canonical-id-stability-design.md`. The Q12 section ("What about the existing canonicals — do they break?") describes the migration path. Append a paragraph after the existing migration steps:

```markdown
**Phase B addendum (M2 closure):** Phase B's validator runs unconditionally — when `store.load(conceptId)` returns null, `knownIds` is empty and any non-empty distill output is rejected. The operator must `ae canonical init` (creates an empty pack — distill against it routes everything to `proposed_concepts`) or `ae canonical scaffold --from-artifact` first. This closes the loophole noted in [phase-a-smoke/SUMMARY.md](../notes/phase-a-smoke/SUMMARY.md) where `canonical distill` against a missing concept silently created a pack from the LLM output.
```

- [ ] **Step 7: Commit (directly on `v2`)**

```bash
git add agentic_executables_core/lib/src/services/default_canonical_service.dart \
        agentic_executables_core/test/default_canonical_service_test.dart \
        docs/superpowers/specs/2026-04-27-canonical-id-stability-design.md
git commit -m "fix(core): id-stability validator runs unconditionally — close empty-matrix bypass"
```

### Task B1: `ae canonical scaffold --update` mode

**Why:** Once a canonical exists, source code keeps moving. New public symbols appear; old ones are deleted. Without a sync command, the matrix drifts away from source — and Phase A's validator means distill can no longer absorb new symbols silently. `--update` is the deterministic, no-LLM reconciliation step: diff source symbols against the matrix, append rows for new symbols (stub spec/invariant), mark vanished symbols `removed: true` (preserve text). Idempotent.

**Files:**
- Modify: `agentic_executables_core/lib/src/models/canonical_pack.dart` — extend `CanonicalFeature` with `removed: bool` (default false). Wire through serialization.
- Modify: `agentic_executables_core/lib/src/services/canonical_service.dart` — add `ScaffoldUpdateReport` class; add `scaffoldUpdate` interface method.
- Modify: `agentic_executables_core/lib/src/services/default_canonical_service.dart` — implement `scaffoldUpdate`.
- Modify: `agentic_executables_core/test/default_canonical_service_test.dart` — three new tests.
- Modify: `agentic_executables_cli/lib/src/cli.dart` — add `--update` flag to scaffold; wire handler.
- Modify: `agentic_executables_cli/test/...` — one CLI integration test.
- Modify: `agentic_executables_mcp/lib/src/adapter.dart` — `update: true` parameter on `scaffold` operation.
- Modify: `agentic_executables_mcp/test/...` — one MCP test.

- [ ] **Step 1: Locate the existing CanonicalFeature model**

```bash
grep -n "class CanonicalFeature\|CanonicalFeature(" agentic_executables_core/lib/src/models/canonical_pack.dart agentic_executables_core/lib/src/models/canonical_matrix.dart 2>&1 | head -10
```

Confirms whether `CanonicalFeature` lives in `canonical_pack.dart` or `canonical_matrix.dart`. Adjust the file path in subsequent steps.

- [ ] **Step 2: Write the failing model test**

Append to `agentic_executables_core/test/default_canonical_service_test.dart` (or create `test/canonical_feature_test.dart` if a per-model file already exists at `test/canonical_pack_test.dart`):

```dart
test('CanonicalFeature carries removed flag through round-trip serialization', () {
  final feature = CanonicalFeature(
    id: FeatureId.parse('demo.gone'),
    cells: const {'spec': 'old', 'invariant': 'old'},
    removed: true,
  );
  final json = feature.toJson();
  expect(json['removed'], isTrue);
  final round = CanonicalFeature.fromMap(json);
  expect(round.removed, isTrue);
  expect(round.id.toString(), 'demo.gone');
  expect(round.cells['spec'], 'old');
});

test('CanonicalFeature.removed defaults to false on legacy payloads', () {
  final json = {
    'id': 'demo.kept',
    'cells': {'spec': 's'},
  };
  final feature = CanonicalFeature.fromMap(json);
  expect(feature.removed, isFalse);
  expect(feature.toJson().containsKey('removed'), isFalse,
      reason: 'omit `removed: false` from JSON to keep yaml stable');
});
```

- [ ] **Step 3: Run, verify they fail**

```bash
cd agentic_executables_core && dart test test/default_canonical_service_test.dart --name 'removed flag'
```

Expected: compile failure (`CanonicalFeature` has no `removed` parameter).

- [ ] **Step 4: Extend `CanonicalFeature`**

Open `agentic_executables_core/lib/src/models/canonical_pack.dart` (or wherever `CanonicalFeature` lives). Find the constructor and add an optional `removed` parameter:

```dart
class CanonicalFeature {
  const CanonicalFeature({
    required this.id,
    required this.cells,
    this.removed = false,
  });

  final FeatureId id;
  final Map<String, String> cells;

  /// Marks this row as removed from the source artifact while preserving its
  /// spec/invariant text. Set by `ae canonical scaffold --update` when a
  /// previously-scaffolded symbol is no longer in the source. Distill MUST
  /// continue to enrich removed rows (their id is in the pre-distill matrix).
  /// See specs/2026-04-27-canonical-id-stability-design.md Q3.
  final bool removed;

  Map<String, dynamic> toJson() => {
        'id': id.toString(),
        'cells': cells,
        if (removed) 'removed': true,
      };

  factory CanonicalFeature.fromMap(final Map<dynamic, dynamic> map) {
    final rawCells = map['cells'];
    final cells = <String, String>{};
    if (rawCells is Map) {
      for (final entry in rawCells.entries) {
        cells[entry.key.toString()] = entry.value?.toString() ?? '';
      }
    }
    return CanonicalFeature(
      id: FeatureId.parse(map['id']?.toString() ?? ''),
      cells: cells,
      removed: map['removed'] == true,
    );
  }
}
```

If the file already has `fromMap` and `toJson` written differently, mirror the existing patterns; only add the two `removed`-aware lines (`if (removed) 'removed': true,` in `toJson`, `removed: map['removed'] == true` in `fromMap`).

- [ ] **Step 5: Confirm yaml serialization preserves `removed`**

The `FileCanonicalStore` writes matrix.yaml via `package:yaml`. Find the matrix-write code and confirm it serializes `feature.toJson()`:

```bash
grep -n "toJson\|encode\|writeAsString" agentic_executables_core/lib/src/adapters/file_canonical_store.dart | head -10
```

If the store uses a custom yaml emitter (not `feature.toJson()`), add `if (feature.removed) sink.writeln('    removed: true');` (or equivalent) after the `cells:` block. If it uses `toJson()`, no further code change needed.

- [ ] **Step 6: Run model tests, verify they pass**

```bash
cd agentic_executables_core && dart test test/default_canonical_service_test.dart --name 'removed flag'
```

Expected: 2 passing.

- [ ] **Step 7: Write the failing service-level tests**

Append to the same group:

```dart
test('scaffoldUpdate adds rows for new symbols and marks vanished as removed', () async {
  final tmp = await Directory.systemTemp.createTemp('id_stability_b1_diff');
  addTearDown(() async {
    await tmp.delete(recursive: true);
  });
  final store = FileCanonicalStore(tmp.path);
  final service = DefaultCanonicalService(store: store);

  // Stage 1: scaffold against an artifact with two symbols (kept, gone).
  final initialArtStore = _FakeArtifactStore({
    'demo': '## Public API\n- `kept` (function)\n- `gone` (function)\n',
  });
  await service.scaffoldFromArtifact(
    'demo',
    title: 'Demo',
    artifactNames: const ['demo'],
    artifactStore: initialArtStore,
  );

  // Hand-edit: enrich kept's spec so we can check preservation.
  final pre = (await service.load('demo'))!;
  final enriched = CanonicalPack(
    meta: pre.meta,
    indexContent: pre.indexContent,
    matrix: CanonicalMatrix(
      concept: pre.matrix.concept,
      version: pre.matrix.version,
      columnSchema: pre.matrix.columnSchema,
      features: [
        for (final f in pre.matrix.features)
          if (f.id.toString() == 'demo.kept')
            CanonicalFeature(
              id: f.id,
              cells: const {'spec': 'enriched-by-hand', 'invariant': 'inv'},
            )
          else
            f,
      ],
    ),
  );
  await service.upsert('demo', enriched);

  // Stage 2: source artifact gains `added`, loses `gone`.
  final updatedArtStore = _FakeArtifactStore({
    'demo': '## Public API\n- `kept` (function)\n- `added` (function)\n',
  });

  final report = await service.scaffoldUpdate(
    'demo',
    artifactNames: const ['demo'],
    artifactStore: updatedArtStore,
  );

  expect(report.added, ['demo.added']);
  expect(report.removed, ['demo.gone']);
  expect(report.unchanged, 1);
  expect(report.renamed, isEmpty);

  final after = (await service.load('demo'))!;
  final byId = {for (final f in after.matrix.features) f.id.toString(): f};
  expect(byId.keys, containsAll(['demo.kept', 'demo.added', 'demo.gone']));
  expect(byId['demo.kept']!.cells['spec'], 'enriched-by-hand',
      reason: 'preserves text on unchanged rows');
  expect(byId['demo.gone']!.removed, isTrue,
      reason: 'marks vanished, does not delete');
  expect(byId['demo.gone']!.cells['spec'], isNotEmpty,
      reason: 'preserves text on removed rows');
  expect(byId['demo.added']!.removed, isFalse);
});

test('scaffoldUpdate is idempotent (re-running with same source produces no diff)', () async {
  final tmp = await Directory.systemTemp.createTemp('id_stability_b1_idempotent');
  addTearDown(() async {
    await tmp.delete(recursive: true);
  });
  final store = FileCanonicalStore(tmp.path);
  final service = DefaultCanonicalService(store: store);

  final artStore = _FakeArtifactStore({
    'demo': '## Public API\n- `a` (function)\n- `b` (function)\n',
  });
  await service.scaffoldFromArtifact(
    'demo',
    title: 'Demo',
    artifactNames: const ['demo'],
    artifactStore: artStore,
  );

  final r1 = await service.scaffoldUpdate(
    'demo',
    artifactNames: const ['demo'],
    artifactStore: artStore,
  );
  expect(r1.added, isEmpty);
  expect(r1.removed, isEmpty);
  expect(r1.unchanged, 2);

  final r2 = await service.scaffoldUpdate(
    'demo',
    artifactNames: const ['demo'],
    artifactStore: artStore,
  );
  expect(r2.added, isEmpty);
  expect(r2.removed, isEmpty);
  expect(r2.unchanged, 2);
});

test('scaffoldUpdate preserves accepted_concept rows (no false tombstone)', () async {
  // Without the provenance check, accepted-concept rows look like vanished
  // symbols (no source id matches) and would be tombstoned every --update.
  final tmp = await Directory.systemTemp.createTemp('id_stability_b1_accept_preserve');
  addTearDown(() async {
    await tmp.delete(recursive: true);
  });
  final store = FileCanonicalStore(tmp.path);
  final service = DefaultCanonicalService(store: store);

  final artStore = _FakeArtifactStore({
    'demo': '## Public API\n- `kept` (function)\n',
  });
  await service.scaffoldFromArtifact(
    'demo',
    title: 'Demo',
    artifactNames: const ['demo'],
    artifactStore: artStore,
  );

  // Hand-add an accepted-concept row (mimics a successful B4 acceptConcept).
  final pre = (await service.load('demo'))!;
  final withAccepted = CanonicalPack(
    meta: pre.meta,
    indexContent: pre.indexContent,
    matrix: CanonicalMatrix(
      concept: pre.matrix.concept,
      version: pre.matrix.version,
      columnSchema: pre.matrix.columnSchema,
      features: [
        ...pre.matrix.features,
        CanonicalFeature(
          id: FeatureId.parse('demo.json_envelope'),
          cells: const {
            'spec': 'every command writes JSON',
            'invariant': 'success is bool',
            'provenance': 'accepted_concept',
          },
        ),
      ],
    ),
  );
  await service.upsert('demo', withAccepted);

  // Re-run --update against the same artifact (no source change).
  final report = await service.scaffoldUpdate(
    'demo',
    artifactNames: const ['demo'],
    artifactStore: artStore,
  );

  expect(report.removed, isEmpty,
      reason: 'accepted_concept rows must not be tombstoned by --update');
  expect(report.added, isEmpty);

  final after = (await service.load('demo'))!;
  final byId = {for (final f in after.matrix.features) f.id.toString(): f};
  expect(byId['demo.json_envelope']!.removed, isFalse);
  expect(byId['demo.json_envelope']!.cells['provenance'], 'accepted_concept');
});

test('scaffoldUpdate errors when the canonical does not exist', () async {
  final tmp = await Directory.systemTemp.createTemp('id_stability_b1_missing');
  addTearDown(() async {
    await tmp.delete(recursive: true);
  });
  final store = FileCanonicalStore(tmp.path);
  final service = DefaultCanonicalService(store: store);

  final artStore = _FakeArtifactStore({
    'demo': '## Public API\n- `x` (function)\n',
  });
  expect(
    () => service.scaffoldUpdate(
      'never_scaffolded',
      artifactNames: const ['demo'],
      artifactStore: artStore,
    ),
    throwsA(isA<StateError>().having(
      (final e) => e.message,
      'message',
      contains('canonical_not_found'),
    )),
  );
});
```

The `_FakeArtifactStore` helper may need to be added at the top of the test file if it doesn't already exist. Check first:

```bash
grep -n "_FakeArtifactStore\|class.*ArtifactStore" agentic_executables_core/test/default_canonical_service_test.dart
```

If absent, add this minimal in-memory implementation just after the existing helpers (before `void main()`):

```dart
class _FakeArtifactStore implements ArtifactStore {
  _FakeArtifactStore(this._packs);
  final Map<String, String> _packs; // name → indexContent

  @override
  Future<bool> exists(final String name) async => _packs.containsKey(name);

  @override
  Future<ArtifactPack?> load(final String name) async {
    final indexContent = _packs[name];
    if (indexContent == null) return null;
    return ArtifactPack(
      meta: ArtifactMeta(
        artifact: name,
        version: 1,
        license: const ArtifactLicense(spdx: 'CC-BY-4.0', url: 'https://x'),
        source: const ArtifactSource(files: []),
        provenance: ArtifactProvenance(
          authored: ArtifactAuthored.hand,
          authoredAt: DateTime.utc(2026, 4, 27),
          extractor: 'dart_heuristic',
        ),
      ),
      indexContent: indexContent,
    );
  }

  @override
  noSuchMethod(final Invocation i) => super.noSuchMethod(i);
}
```

If the existing test file already has a real `ArtifactStore` test fixture, reuse it instead — don't add a duplicate.

- [ ] **Step 8: Run, verify the service tests fail**

```bash
cd agentic_executables_core && dart test test/default_canonical_service_test.dart --name 'scaffoldUpdate'
```

Expected: compile failure (`scaffoldUpdate` not defined; `ScaffoldUpdateReport` not defined).

- [ ] **Step 9: Define `ScaffoldUpdateReport`**

In `agentic_executables_core/lib/src/services/canonical_service.dart`, append after `CanonicalDiff`:

```dart
/// Result of [CanonicalService.scaffoldUpdate]. Reports the diff between
/// source-artifact symbols and the existing matrix.
class ScaffoldUpdateReport {
  const ScaffoldUpdateReport({
    required this.added,
    required this.removed,
    required this.renamed,
    required this.unchanged,
  });

  /// Feature ids appended to the matrix because they are present in the
  /// source artifact but were absent from the matrix.
  final List<String> added;

  /// Feature ids whose `removed` flag was set to true because they are
  /// absent from the source artifact but present in the matrix. Text
  /// (spec/invariant) is preserved on these rows.
  final List<String> removed;

  /// Pairs `[old_id, new_id]` for `--rename` migrations performed during
  /// this update. Empty unless `--rename` was supplied. See Task B2.
  final List<List<String>> renamed;

  /// Count of rows present in both source and matrix; their text was
  /// preserved verbatim.
  final int unchanged;

  Map<String, dynamic> toJson() => {
        'added': added,
        'removed': removed,
        'renamed': [for (final pair in renamed) {'from': pair[0], 'to': pair[1]}],
        'unchanged': unchanged,
      };
}
```

- [ ] **Step 10: Add `scaffoldUpdate` to the interface**

In the same file, add to the `CanonicalService` interface (after `scaffoldFromArtifact`):

```dart
  /// Reconcile the existing canonical at [conceptId] against the current
  /// public-API symbols of [artifactNames]. Deterministic — no LLM. Adds
  /// rows for new symbols (stub spec/invariant), marks vanished symbols
  /// `removed: true` while preserving their text, and leaves unchanged
  /// rows untouched. Throws [StateError] with code `canonical_not_found`
  /// if no pack exists at [conceptId].
  ///
  /// [renames] is an optional list of `old=new` pairs (per Task B2): each
  /// pair migrates the row at `old` to `new`, preserving text under `new`
  /// and leaving a stub `removed: true` row at `old` with `renamed_to:
  /// <new>`. Validates that `old` exists in the matrix and `new` does not.
  Future<ScaffoldUpdateReport> scaffoldUpdate(
    final String conceptId, {
    required final List<String> artifactNames,
    required final ArtifactStore artifactStore,
    final List<List<String>> renames = const [],
  });
```

- [ ] **Step 11: Implement `scaffoldUpdate` (without rename support yet)**

In `agentic_executables_core/lib/src/services/default_canonical_service.dart`, add the method (before `mergeDistillation`):

```dart
  @override
  Future<ScaffoldUpdateReport> scaffoldUpdate(
    final String conceptId, {
    required final List<String> artifactNames,
    required final ArtifactStore artifactStore,
    final List<List<String>> renames = const [],
  }) async {
    final existing = await store.load(conceptId);
    if (existing == null) {
      throw StateError(
        'canonical_not_found: $conceptId — run `ae canonical scaffold` '
        'or `ae canonical init` first',
      );
    }

    // Collect current source symbols, keyed by their canonical feature id.
    // Keep the symbol/kind so new rows can reuse scaffoldFromArtifact's seed
    // text format (`<symbol> (<kind>) — fill in the spec here.`).
    final sourceSyms = <String, _ScaffoldSymbol>{};
    final missingArtifacts = <String>[];
    for (final name in artifactNames) {
      final art = await artifactStore.load(name);
      if (art == null) {
        missingArtifacts.add(name);
        continue;
      }
      for (final sym in _parsePublicApi(art.indexContent)) {
        final id = _featureIdFor(name, sym.symbol);
        if (id == null) continue;
        sourceSyms.putIfAbsent(id, () => sym);
      }
    }
    if (missingArtifacts.isNotEmpty) {
      throw ArgumentError(
        'artifact_not_found: ${missingArtifacts.join(', ')}',
      );
    }
    final sourceIds = sourceSyms.keys.toSet();

    // Index the existing matrix.
    final byId = <String, CanonicalFeature>{
      for (final f in existing.matrix.features) f.id.toString(): f,
    };

    // (Rename handling — Task B2 fills this in. For B1 the loop stays empty.)
    final renamedReport = <List<String>>[];
    for (final pair in renames) {
      // Implemented in Task B2.
      throw UnsupportedError('--rename pending: Task B2');
    }

    final added = <String>[];
    for (final id in sourceIds) {
      if (byId.containsKey(id)) continue;
      // Mirror scaffoldFromArtifact's seed text so an operator can't tell
      // a row came from --update vs. from initial scaffold.
      final sym = sourceSyms[id]!;
      final feature = CanonicalFeature(
        id: FeatureId.parse(id),
        cells: {
          'spec': '${sym.symbol} (${sym.kind}) — fill in the spec here.',
          'invariant': '',
        },
      );
      byId[id] = feature;
      added.add(id);
    }

    final removed = <String>[];
    for (final entry in byId.entries.toList()) {
      final id = entry.key;
      final feature = entry.value;
      if (sourceIds.contains(id)) continue;
      if (feature.removed) continue; // already marked, idempotent
      // Accepted-concept rows are deliberately not symbol-derived; never
      // tombstone them via --update. Operator removes them manually if
      // they want to retire one. (Bug caught in plan-review: without this,
      // every --update would mark accept-concept rows removed:true.)
      if (feature.cells['provenance'] == 'accepted_concept') continue;
      // Mark as removed; preserve text.
      byId[id] = CanonicalFeature(
        id: feature.id,
        cells: feature.cells,
        removed: true,
      );
      removed.add(id);
    }

    final unchanged = byId.length - added.length - removed.length;

    final mergedFeatures = byId.values.toList(growable: false);
    final mergedMatrix = CanonicalMatrix(
      concept: existing.matrix.concept,
      version: existing.matrix.version,
      columnSchema: existing.matrix.columnSchema,
      features: mergedFeatures,
    );
    final updated = CanonicalPack(
      meta: existing.meta,
      indexContent: existing.indexContent,
      matrix: mergedMatrix,
      changelogContent: existing.changelogContent,
    );
    await store.save(conceptId, updated);

    added.sort();
    removed.sort();
    return ScaffoldUpdateReport(
      added: added,
      removed: removed,
      renamed: renamedReport,
      unchanged: unchanged,
    );
  }
```

- [ ] **Step 12: Run service tests, verify they pass**

```bash
cd agentic_executables_core && dart test test/default_canonical_service_test.dart
```

Expected: all passing including the three new ones.

- [ ] **Step 13: Wire CLI flag and handler**

In `agentic_executables_cli/lib/src/cli.dart`, find the `scaffold` ArgParser block (~line 331) and add the `--update` flag:

```dart
canonical?.addCommand('scaffold')
  ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
  ..addOption('concept', help: 'Concept slug (required).')
  ..addOption('title', help: 'Human title (optional with --update).')
  ..addMultiOption('from-artifact',
      help: 'Artifact pack name (repeatable; required).')
  ..addFlag('overwrite',
      defaultsTo: false,
      negatable: false,
      help: 'Replace an existing canonical at --concept.')
  ..addFlag('update',
      defaultsTo: false,
      negatable: false,
      help: 'Reconcile existing canonical against current source symbols. '
          'Adds rows for new symbols, marks vanished symbols removed:true. '
          'Preserves text. Idempotent. Mutually exclusive with --overwrite.')
  ..addOption('root', help: 'Project root (defaults to cwd).');
```

In the `case 'scaffold':` handler block (~line 2166), branch on `--update`:

```dart
case 'scaffold':
  final concept = sub['concept']?.toString();
  final title = sub['title']?.toString();
  final fromArtifacts =
      (sub['from-artifact'] as List?)?.cast<String>() ?? const <String>[];
  final overwrite = sub['overwrite'] == true;
  final update = sub['update'] == true;
  if (concept == null || concept.isEmpty) {
    return AeResult.fail(
      code: 'validation_error',
      message: 'Missing required --concept',
    );
  }
  if (fromArtifacts.isEmpty) {
    return AeResult.fail(
      code: 'validation_error',
      message: 'Missing required --from-artifact (repeatable).',
    );
  }
  if (update && overwrite) {
    return AeResult.fail(
      code: 'validation_error',
      message: '--update and --overwrite are mutually exclusive.',
    );
  }

  final artStore = FileArtifactStore(hubPath);

  if (update) {
    try {
      final report = await svc.scaffoldUpdate(
        concept,
        artifactNames: fromArtifacts,
        artifactStore: artStore,
      );
      return AeResult.ok({
        'concept': concept,
        'mode': 'update',
        'added': report.added,
        'removed': report.removed,
        'unchanged': report.unchanged,
        'from_artifacts': fromArtifacts,
      });
    } on StateError catch (e) {
      if (e.message.contains('canonical_not_found')) {
        return AeResult.fail(
          code: 'canonical_not_found',
          message: e.message,
        );
      }
      rethrow;
    } on ArgumentError catch (e) {
      final msg = e.message?.toString() ?? '';
      if (msg.contains('artifact_not_found')) {
        return AeResult.fail(
          code: 'artifact_not_found',
          message: msg,
        );
      }
      return AeResult.fail(code: 'validation_error', message: msg);
    }
  }

  // Original (non-update) path. --title is required only here.
  if (title == null || title.isEmpty) {
    return AeResult.fail(
      code: 'validation_error',
      message: 'Missing required --title',
    );
  }
  try {
    final pack = await svc.scaffoldFromArtifact(
      concept,
      title: title,
      artifactNames: fromArtifacts,
      artifactStore: artStore,
      overwrite: overwrite,
    );
    return AeResult.ok({
      'concept': pack.meta.concept,
      'version': pack.meta.version,
      'feature_count': pack.matrix.features.length,
      'authored': pack.meta.provenance.authored.value,
      'from_artifacts': fromArtifacts,
    });
  } on StateError catch (e) {
    if (e.message.contains('canonical_exists')) {
      return AeResult.fail(
        code: 'canonical_exists',
        message: e.message,
      );
    }
    rethrow;
  } on ArgumentError catch (e) {
    final msg = e.message?.toString() ?? '';
    if (msg.contains('artifact_not_found')) {
      return AeResult.fail(
        code: 'artifact_not_found',
        message: msg,
      );
    }
    return AeResult.fail(code: 'validation_error', message: msg);
  }
```

(Compare to the existing block — only the `--update` branch is new; the original behavior is preserved word-for-word in the else path.)

- [ ] **Step 14: Write CLI integration test for --update**

Find the existing canonical-scaffold CLI test:

```bash
grep -rln "canonical scaffold\|ae_canonical.*scaffold\|case 'scaffold'" agentic_executables_cli/test
```

Append a new test to whichever file covers `_handleCanonical` / `case 'scaffold'`. Mirror the existing scaffold test's setup (hub init, artifact ingestion, run command, parse envelope):

```dart
test('canonical scaffold --update reports added/removed against existing canonical', () async {
  final tmp = await Directory.systemTemp.createTemp('cli_scaffold_update_');
  addTearDown(() async { await tmp.delete(recursive: true); });
  // ... existing test scaffolding (hubInit, ingest a synthetic artifact with
  // public-api containing "alpha" and "beta", scaffold from it) ...

  // Hand-edit the artifact: add "gamma", remove "beta".
  // ... write the updated artifact's index.md ...

  final result = await cli.run([
    'canonical', 'scaffold',
    '--concept', 'demo',
    '--from-artifact', 'demo_pack',
    '--update',
    '--root', tmp.path,
  ]);
  final json = jsonDecode(result.stdout) as Map<String, dynamic>;
  expect(json['success'], isTrue);
  expect(json['data']['mode'], 'update');
  expect((json['data']['added'] as List), contains('demo_pack.gamma'));
  expect((json['data']['removed'] as List), contains('demo_pack.beta'));
});
```

(The exact test fixture pattern depends on the CLI test-suite scaffolding — copy from the closest existing scaffold test rather than inventing a new pattern.)

- [ ] **Step 15: Wire the MCP `update` parameter**

In `agentic_executables_mcp/lib/src/adapter.dart`, in the `case 'scaffold':` block, add:

```dart
case 'scaffold':
  final concept = params['concept']?.toString();
  final title = params['title']?.toString();
  final overwrite = _typedBool(params, 'overwrite', defaultValue: false);
  final update = _typedBool(params, 'update', defaultValue: false);
  if (concept == null || concept.isEmpty) {
    return _validationError('Missing "concept"');
  }
  final fromArtifacts = _coerceStringList(params['from_artifact']);
  if (fromArtifacts.isEmpty) {
    return _validationError(
      'Missing "from_artifact" (string or list of strings).',
    );
  }
  if (update && overwrite) {
    return _validationError('"update" and "overwrite" are mutually exclusive.');
  }

  final artStore = FileArtifactStore(hubPath);
  final missing = <String>[];
  for (final name in fromArtifacts) {
    if (!await artStore.exists(name)) missing.add(name);
  }
  if (missing.isNotEmpty) {
    return {
      'success': false,
      'error': {
        'code': 'artifact_not_found',
        'message': 'artifact_not_found: ${missing.join(', ')}',
      },
    };
  }

  if (update) {
    try {
      final report = await svc.scaffoldUpdate(
        concept,
        artifactNames: fromArtifacts,
        artifactStore: artStore,
      );
      return {
        'success': true,
        'data': {
          'concept': concept,
          'mode': 'update',
          'added': report.added,
          'removed': report.removed,
          'unchanged': report.unchanged,
          'from_artifacts': fromArtifacts,
        },
      };
    } on StateError catch (e) {
      if (e.message.contains('canonical_not_found')) {
        return {
          'success': false,
          'error': {
            'code': 'canonical_not_found',
            'message': e.message,
          },
        };
      }
      rethrow;
    }
  }

  // Original non-update path (preserve existing canonical_exists pre-check):
  if (title == null || title.isEmpty) {
    return _validationError('Missing "title"');
  }
  if (!overwrite && await svc.load(concept) != null) {
    return {
      'success': false,
      'error': {
        'code': 'canonical_exists',
        'message': 'canonical_exists: $concept already exists; pass '
            'overwrite=true to replace.',
      },
    };
  }
  final pack = await svc.scaffoldFromArtifact(
    concept,
    title: title,
    artifactNames: fromArtifacts,
    artifactStore: artStore,
    overwrite: overwrite,
  );
  return {
    'success': true,
    'data': {
      'concept': pack.meta.concept,
      'version': pack.meta.version,
      'feature_count': pack.matrix.features.length,
      'authored': pack.meta.provenance.authored.value,
      'from_artifacts': fromArtifacts,
    },
  };
```

- [ ] **Step 16: Add MCP test mirroring the CLI integration test**

In `agentic_executables_mcp/test/...` (find the file via `grep -rln "case 'scaffold'\|ae_canonical.*scaffold" agentic_executables_mcp/test`), add:

```dart
test('ae_canonical scaffold update reports added/removed', () async {
  // ... existing MCP test scaffolding ...
  final result = await adapter.callTool('ae_canonical', {
    'op': 'scaffold',
    'concept': 'demo',
    'from_artifact': 'demo_pack',
    'update': true,
  });
  expect(result['success'], isTrue);
  expect((result['data'] as Map)['mode'], 'update');
});
```

- [ ] **Step 17: Verify spec_export carries `removed` through (design Q11 commitment)**

`agentic_executables_cli/lib/src/spec_export_support.dart` serializes via `pack.matrix.toJson()`, which now emits `removed: true` on tombstoned rows automatically (B1 step 4 extended `CanonicalFeature.toJson`). Add a sanity check to the CLI test suite:

```bash
grep -rln "spec.export\|exportSpec\|spec_export" agentic_executables_cli/test
```

In whichever test file covers `ae spec export` (likely `spec_export_test.dart`), append:

```dart
test('spec export carries CanonicalFeature.removed through to spec_index.json', () async {
  // Build a hub with a canonical that has one removed:true row.
  // ... setup using the same scaffolding as the existing spec_export test ...
  // After running exportSpec:
  final indexFile = File(p.join(outDir, 'spec_index.json'));
  final indexJson = jsonDecode(await indexFile.readAsString()) as Map<String, dynamic>;
  // Walk into the canonical's matrix features:
  final canonicals = (indexJson['canonicals'] as List).cast<Map<String, dynamic>>();
  final demo = canonicals.firstWhere((c) => c['concept'] == 'demo');
  final features = ((demo['matrix'] as Map)['features'] as List).cast<Map<String, dynamic>>();
  final tombstone = features.firstWhere((f) => f['id'] == 'demo.gone');
  expect(tombstone['removed'], isTrue,
      reason: 'spec_export.v3 must surface the removed flag for downstream consumers '
              '(see id-stability design Q11)');
});
```

(If the existing `spec_export_test.dart` uses a different navigation pattern — e.g. one file per canonical — match that pattern instead. The point is to assert `removed: true` survives the export.)

- [ ] **Step 18: Run all three suites, verify they pass**

```bash
cd agentic_executables_core && dart test 2>&1 | tail -3
cd ../agentic_executables_cli && dart test 2>&1 | tail -3
cd ../agentic_executables_mcp && dart test 2>&1 | tail -3
```

Expected: core 231+, CLI 65+, MCP 48+ passing. (B0 added 2 core; B1 adds 6 core + 2 CLI + 1 MCP.)

- [ ] **Step 19: Commit**

```bash
git add agentic_executables_core agentic_executables_cli agentic_executables_mcp
git commit -m "feat: ae canonical scaffold --update — sync matrix with source symbols"
```

### Task B2: `--rename old=new` flag

**Why:** Without explicit rename detection, `--update` sees a symbol rename as remove + add — losing the spec/invariant text and breaking downstream references to the old id. Strict-by-default discipline (per design Q4): the operator must opt into each rename. Repeatable flag.

**Files:**
- Modify: `agentic_executables_core/lib/src/services/default_canonical_service.dart` — replace the rename `throw UnsupportedError` block with the actual implementation.
- Modify: `agentic_executables_core/test/default_canonical_service_test.dart` — two new tests (clean rename; collision error).
- Modify: `agentic_executables_cli/lib/src/cli.dart` — add `--rename` repeatable option.
- Modify: `agentic_executables_cli/test/...` — one CLI test.
- Modify: `agentic_executables_mcp/lib/src/adapter.dart` — accept `renames` array on scaffold op.
- Modify: `agentic_executables_mcp/test/...` — one MCP test.

- [ ] **Step 1: Write the failing service tests**

Append:

```dart
test('scaffoldUpdate --rename migrates id and preserves text', () async {
  final tmp = await Directory.systemTemp.createTemp('id_stability_b2_rename');
  addTearDown(() async { await tmp.delete(recursive: true); });
  final store = FileCanonicalStore(tmp.path);
  final service = DefaultCanonicalService(store: store);

  final initialArt = _FakeArtifactStore({
    'demo': '## Public API\n- `oldName` (function)\n',
  });
  await service.scaffoldFromArtifact(
    'demo',
    title: 'Demo',
    artifactNames: const ['demo'],
    artifactStore: initialArt,
  );

  // Hand-enrich the row.
  final pre = (await service.load('demo'))!;
  final enriched = CanonicalPack(
    meta: pre.meta,
    indexContent: pre.indexContent,
    matrix: CanonicalMatrix(
      concept: pre.matrix.concept,
      version: pre.matrix.version,
      columnSchema: pre.matrix.columnSchema,
      features: [
        CanonicalFeature(
          id: FeatureId.parse('demo.old_name'),
          cells: const {'spec': 'PRESERVE-ME', 'invariant': 'KEEP-ME'},
        ),
      ],
    ),
  );
  await service.upsert('demo', enriched);

  // Source artifact renamed `oldName` → `newName`.
  final renamedArt = _FakeArtifactStore({
    'demo': '## Public API\n- `newName` (function)\n',
  });
  final report = await service.scaffoldUpdate(
    'demo',
    artifactNames: const ['demo'],
    artifactStore: renamedArt,
    renames: [['demo.old_name', 'demo.new_name']],
  );

  expect(report.renamed, [['demo.old_name', 'demo.new_name']]);
  expect(report.added, isEmpty);
  expect(report.removed, isEmpty);
  expect(report.unchanged, 0);

  final after = (await service.load('demo'))!;
  final byId = {for (final f in after.matrix.features) f.id.toString(): f};
  expect(byId.keys, containsAll(['demo.new_name', 'demo.old_name']));
  expect(byId['demo.new_name']!.cells['spec'], 'PRESERVE-ME');
  expect(byId['demo.new_name']!.removed, isFalse);
  expect(byId['demo.old_name']!.removed, isTrue,
      reason: 'old id retained as a tombstone for traceability');
  expect(byId['demo.old_name']!.cells['renamed_to'], 'demo.new_name');
});

test('scaffoldUpdate --rename errors when target id already exists', () async {
  final tmp = await Directory.systemTemp.createTemp('id_stability_b2_collision');
  addTearDown(() async { await tmp.delete(recursive: true); });
  final store = FileCanonicalStore(tmp.path);
  final service = DefaultCanonicalService(store: store);

  final art = _FakeArtifactStore({
    'demo': '## Public API\n- `a` (function)\n- `b` (function)\n',
  });
  await service.scaffoldFromArtifact(
    'demo',
    title: 'Demo',
    artifactNames: const ['demo'],
    artifactStore: art,
  );

  expect(
    () => service.scaffoldUpdate(
      'demo',
      artifactNames: const ['demo'],
      artifactStore: art,
      renames: [['demo.a', 'demo.b']], // demo.b already exists
    ),
    throwsA(isA<ArgumentError>().having(
      (final e) => e.message?.toString() ?? '',
      'message',
      contains('rename_collision'),
    )),
  );
});

test('scaffoldUpdate --rename errors when source id is absent', () async {
  final tmp = await Directory.systemTemp.createTemp('id_stability_b2_missing_old');
  addTearDown(() async { await tmp.delete(recursive: true); });
  final store = FileCanonicalStore(tmp.path);
  final service = DefaultCanonicalService(store: store);

  final art = _FakeArtifactStore({
    'demo': '## Public API\n- `a` (function)\n',
  });
  await service.scaffoldFromArtifact(
    'demo',
    title: 'Demo',
    artifactNames: const ['demo'],
    artifactStore: art,
  );

  expect(
    () => service.scaffoldUpdate(
      'demo',
      artifactNames: const ['demo'],
      artifactStore: art,
      renames: [['demo.does_not_exist', 'demo.something']],
    ),
    throwsA(isA<ArgumentError>().having(
      (final e) => e.message?.toString() ?? '',
      'message',
      contains('rename_missing'),
    )),
  );
});
```

(Note `cells['renamed_to']` — we extend the cells map rather than adding a typed field, to keep schema additive. The matrix yaml emits the entire cells map verbatim, so `renamed_to` appears as a normal cell on the tombstone row.)

- [ ] **Step 2: Run, verify they fail**

```bash
cd agentic_executables_core && dart test test/default_canonical_service_test.dart --name 'rename'
```

Expected: failures (the current `scaffoldUpdate` throws `UnsupportedError` whenever `renames` is non-empty).

- [ ] **Step 3: Implement rename handling**

Replace the `for (final pair in renames) { throw UnsupportedError(...); }` stub in `scaffoldUpdate` with:

```dart
    // Rename handling. Strict-by-default: each pair is operator-confirmed.
    // Validates old exists / new doesn't, then migrates the row's text and
    // leaves a `removed: true` tombstone at old with `renamed_to: <new>`.
    final renamedReport = <List<String>>[];
    for (final pair in renames) {
      if (pair.length != 2) {
        throw ArgumentError(
          'rename_malformed: expected [old, new], got $pair',
        );
      }
      final oldId = pair[0];
      final newId = pair[1];
      final oldFeature = byId[oldId];
      if (oldFeature == null) {
        throw ArgumentError(
          'rename_missing: $oldId is not in the matrix for $conceptId',
        );
      }
      if (byId.containsKey(newId)) {
        throw ArgumentError(
          'rename_collision: $newId already exists in the matrix for '
          '$conceptId',
        );
      }
      // Migrate text under the new id; preserve removed flag (caller may
      // be renaming a row that's already marked removed).
      byId[newId] = CanonicalFeature(
        id: FeatureId.parse(newId),
        cells: Map<String, String>.from(oldFeature.cells),
        removed: false,
      );
      // Tombstone at the old id with renamed_to pointer.
      byId[oldId] = CanonicalFeature(
        id: oldFeature.id,
        cells: {
          ...oldFeature.cells,
          'renamed_to': newId,
        },
        removed: true,
      );
      renamedReport.add([oldId, newId]);
    }
```

The rest of `scaffoldUpdate` (added/removed loops) operates on the post-rename `byId` map, so nothing else changes. **Order matters**: rename runs before the add/remove diff so the new ids are visible to the source-vs-matrix comparison.

- [ ] **Step 4: Tweak the added/removed loops to skip already-renamed rows**

The `renamed_to` tombstone created above has `removed: true`, so the existing `if (feature.removed) continue;` in the removed loop already handles it correctly — but verify the new id (`newId`) is also in `sourceIds` before reaching the added loop, otherwise `--rename` of a symbol that's also in the source would double-add. Trace once: pair=`[demo.a, demo.b]`, source has `demo.b` only:
- after rename: `byId['demo.b'] = <migrated>`, `byId['demo.a'] = <tombstone removed>`.
- added loop: iterating `sourceIds = {'demo.b'}`. `byId.containsKey('demo.b')` is true → continue. No double-add. ✓
- removed loop: iterating `byId.entries`. `demo.a` is removed=true → skip. `demo.b` has matching source entry → skip. No false removal. ✓

OK. No change needed.

- [ ] **Step 5: Run, verify the new tests pass**

```bash
cd agentic_executables_core && dart test test/default_canonical_service_test.dart --name 'rename'
```

Expected: 3 passing.

- [ ] **Step 6: Wire the CLI flag**

In the scaffold ArgParser (~line 331), add to the chain:

```dart
  ..addMultiOption('rename',
      help: 'Migrate an id during --update. Format: old=new. Repeatable. '
          'Strict: errors if old missing or new already exists.')
```

In the `case 'scaffold':` handler's `if (update) { ... }` branch, parse the `--rename` strings before calling `scaffoldUpdate`:

```dart
  if (update) {
    final renameRaw = (sub['rename'] as List?)?.cast<String>() ?? const <String>[];
    final renames = <List<String>>[];
    for (final r in renameRaw) {
      final eq = r.indexOf('=');
      if (eq < 1 || eq == r.length - 1) {
        return AeResult.fail(
          code: 'validation_error',
          message: 'malformed --rename "$r": expected old=new',
        );
      }
      renames.add([r.substring(0, eq), r.substring(eq + 1)]);
    }
    try {
      final report = await svc.scaffoldUpdate(
        concept,
        artifactNames: fromArtifacts,
        artifactStore: artStore,
        renames: renames,
      );
      return AeResult.ok({
        'concept': concept,
        'mode': 'update',
        'added': report.added,
        'removed': report.removed,
        'renamed': [for (final pair in report.renamed) {'from': pair[0], 'to': pair[1]}],
        'unchanged': report.unchanged,
        'from_artifacts': fromArtifacts,
      });
    } on StateError catch (e) {
      // ... existing canonical_not_found handler ...
    } on ArgumentError catch (e) {
      final msg = e.message?.toString() ?? '';
      if (msg.contains('rename_collision') ||
          msg.contains('rename_missing') ||
          msg.contains('rename_malformed')) {
        return AeResult.fail(code: 'validation_error', message: msg);
      }
      if (msg.contains('artifact_not_found')) {
        return AeResult.fail(code: 'artifact_not_found', message: msg);
      }
      return AeResult.fail(code: 'validation_error', message: msg);
    }
  }
```

- [ ] **Step 7: Add CLI integration test**

```dart
test('canonical scaffold --update --rename migrates id and preserves text', () async {
  // ... existing CLI test scaffolding (hub init + ingest a synthetic artifact
  // whose public-api becomes oldName, then renamed to newName) ...
  // After scaffolding + hand-edit + artifact rewrite:
  final result = await cli.run([
    'canonical', 'scaffold',
    '--concept', 'demo',
    '--from-artifact', 'demo_pack',
    '--update',
    '--rename', 'demo_pack.old_name=demo_pack.new_name',
    '--root', tmp.path,
  ]);
  final json = jsonDecode(result.stdout) as Map<String, dynamic>;
  expect(json['success'], isTrue);
  expect(
    (json['data']['renamed'] as List).single,
    {'from': 'demo_pack.old_name', 'to': 'demo_pack.new_name'},
  );
});
```

- [ ] **Step 8: Wire MCP renames parameter**

In `agentic_executables_mcp/lib/src/adapter.dart`'s `case 'scaffold':` block, when `update == true`, parse `params['renames']`:

```dart
  final renamesRaw = params['renames'];
  final renames = <List<String>>[];
  if (renamesRaw is List) {
    for (final entry in renamesRaw) {
      if (entry is Map &&
          entry['from'] is String &&
          entry['to'] is String) {
        renames.add([entry['from'].toString(), entry['to'].toString()]);
      } else {
        return _validationError(
          'malformed renames entry; expected [{from, to}, ...]',
        );
      }
    }
  } else if (renamesRaw != null) {
    return _validationError('renames must be a list of {from, to} objects.');
  }
  // ... pass renames to svc.scaffoldUpdate, mirror the CLI envelope shape ...
```

- [ ] **Step 9: Run all three suites**

```bash
cd agentic_executables_core && dart test 2>&1 | tail -3
cd ../agentic_executables_cli && dart test 2>&1 | tail -3
cd ../agentic_executables_mcp && dart test 2>&1 | tail -3
```

Expected: core 234+, CLI 66+, MCP 49+ (B2 adds 3 core + 1 CLI + 1 MCP).

- [ ] **Step 10: Commit**

```bash
git add agentic_executables_core agentic_executables_cli agentic_executables_mcp
git commit -m "feat: ae canonical scaffold --update --rename — explicit id migration"
```

### Task B3: Persist `.last_proposals.json` at distill end

**Why:** B4's `accept-concept` command needs to look up proposals by name. Distill runs are interactive (the user sees the JSON envelope, picks one, runs `accept-concept --from-proposal <name>`). The proposals must persist between the two commands. This is also useful for `accept-concept` to know the executor + timestamp the proposal came from. Service-level method so both CLI and MCP go through the same write path.

**Files:**
- Modify: `agentic_executables_core/lib/src/services/canonical_service.dart` — add `writeProposalsFile` interface method.
- Modify: `agentic_executables_core/lib/src/services/default_canonical_service.dart` — implement.
- Modify: `agentic_executables_core/test/default_canonical_service_test.dart` — one new test.
- Modify: `agentic_executables_cli/lib/src/cli.dart` — call `writeProposalsFile` after `mergeDistillationDetailed` succeeds.
- Modify: `agentic_executables_mcp/lib/src/adapter.dart` — same.

- [ ] **Step 1: Write the failing test**

Append:

```dart
test('writeProposalsFile persists last_proposals.json under the concept dir', () async {
  final tmp = await Directory.systemTemp.createTemp('id_stability_b3_persist');
  addTearDown(() async { await tmp.delete(recursive: true); });
  final store = FileCanonicalStore(tmp.path);
  final service = DefaultCanonicalService(store: store);

  await service.scaffold('demo', title: 'Demo');

  await service.writeProposalsFile(
    'demo',
    proposals: const [
      ProposedConcept(
        name: 'envelope-shape',
        spec: 'every command writes JSON',
        invariant: 'success is bool',
        rationale: 'cross-cutting',
      ),
      ProposedConcept(
        name: 'streaming',
        spec: 'progress events emitted as ndjson',
        invariant: 'one event per line',
        rationale: 'cross-cutting',
      ),
    ],
    executorUsed: 'claude_code',
  );

  // Find the concept dir via the same store layout the production code uses.
  final conceptDir = p.join(
    tmp.path,
    AeCoreConfig.hubCanonicalDir,
    'demo',
  );
  final file = File(p.join(conceptDir, '.last_proposals.json'));
  expect(await file.exists(), isTrue,
      reason: '.last_proposals.json must be written at the concept dir root');

  final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  expect(json['schema'], 'ae.proposed_concepts.v1');
  expect(json['concept'], 'demo');
  expect(json['executor_used'], 'claude_code');
  expect((json['proposals'] as List), hasLength(2));
  expect((json['proposals'] as List).first['name'], 'envelope-shape');
  expect(json['produced_at'], isA<String>(),
      reason: 'ISO-8601 produced_at present');
});

test('writeProposalsFile with empty proposals removes any prior file', () async {
  final tmp = await Directory.systemTemp.createTemp('id_stability_b3_empty_clears');
  addTearDown(() async { await tmp.delete(recursive: true); });
  final store = FileCanonicalStore(tmp.path);
  final service = DefaultCanonicalService(store: store);

  await service.scaffold('demo', title: 'Demo');
  await service.writeProposalsFile(
    'demo',
    proposals: const [
      ProposedConcept(name: 'p', spec: 's', invariant: 'i', rationale: 'r'),
    ],
    executorUsed: 'claude_code',
  );
  final conceptDir = p.join(tmp.path, AeCoreConfig.hubCanonicalDir, 'demo');
  final file = File(p.join(conceptDir, '.last_proposals.json'));
  expect(await file.exists(), isTrue);

  // Subsequent distill returns no proposals — the file should be cleared so
  // accept-concept doesn't operate on stale data.
  await service.writeProposalsFile(
    'demo',
    proposals: const [],
    executorUsed: 'claude_code',
  );
  expect(await file.exists(), isFalse,
      reason: 'empty proposals → file removed (no stale state)');
});
```

The test imports `package:path/path.dart as p;` and `dart:convert` (jsonDecode); add to existing imports if missing. `AeCoreConfig` is the core's path config — confirm via:

```bash
grep -n "hubCanonicalDir\|AeCoreConfig" agentic_executables_core/lib/src/config/ae_core_config.dart
```

- [ ] **Step 2: Run, verify it fails**

```bash
cd agentic_executables_core && dart test test/default_canonical_service_test.dart --name 'writeProposalsFile'
```

Expected: compile failure (`writeProposalsFile` not defined).

- [ ] **Step 3: Add interface method**

In `agentic_executables_core/lib/src/services/canonical_service.dart`, append to `CanonicalService`:

```dart
  /// Writes (or removes) the `.last_proposals.json` sidecar at the concept
  /// directory root. Called by CLI/MCP after a successful `distill` run, so
  /// `accept-concept` can look up proposals by name. When [proposals] is
  /// empty, any existing file is removed (stale-state hygiene).
  ///
  /// File schema: `ae.proposed_concepts.v1` — see Task B4 for the consumer.
  ///
  /// [producedAt] is optional. The distill-end caller leaves it null so the
  /// service stamps the current time. The accept-concept rewriter (B4) passes
  /// the original timestamp through to avoid drifting the file's "this is
  /// when distill produced these" semantics.
  Future<void> writeProposalsFile(
    final String conceptId, {
    required final List<ProposedConcept> proposals,
    required final String executorUsed,
    final DateTime? producedAt,
  });
```

- [ ] **Step 4: Implement**

In `agentic_executables_core/lib/src/services/default_canonical_service.dart`, add:

```dart
  @override
  Future<void> writeProposalsFile(
    final String conceptId, {
    required final List<ProposedConcept> proposals,
    required final String executorUsed,
    final DateTime? producedAt,
  }) async {
    // Resolve the concept dir via the store's canonical layout. We delegate
    // path computation to the store rather than reconstructing it here so a
    // future store impl that uses a different layout still works.
    final dirPath = await store.conceptDirectoryPath(conceptId);
    final file = File(p.join(dirPath, '.last_proposals.json'));
    if (proposals.isEmpty) {
      if (await file.exists()) await file.delete();
      return;
    }
    // [producedAt] is optional so callers that re-write the file after a
    // partial accept (B4) can preserve the timestamp of the original distill
    // run. Defaults to now() for the distill-end caller.
    final timestamp = (producedAt ?? DateTime.now().toUtc()).toIso8601String();
    final payload = {
      'schema': 'ae.proposed_concepts.v1',
      'concept': conceptId,
      'produced_at': timestamp,
      'executor_used': executorUsed,
      'proposals': [for (final pc in proposals) pc.toJson()],
    };
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
  }
```

This depends on a new method `conceptDirectoryPath` on `CanonicalStore`. Check:

```bash
grep -n "conceptDirectoryPath\|abstract.*class CanonicalStore\|class.*CanonicalStore" agentic_executables_core/lib/src/ports/canonical_store.dart agentic_executables_core/lib/src/adapters/file_canonical_store.dart
```

If absent, add to the port:

```dart
// agentic_executables_core/lib/src/ports/canonical_store.dart
abstract class CanonicalStore {
  // ... existing methods ...

  /// Absolute filesystem path to the concept's directory (where matrix.yaml
  /// and meta.yaml live). Used by services that need to write sidecar files
  /// alongside the canonical (e.g. `.last_proposals.json`).
  Future<String> conceptDirectoryPath(final String conceptId);
}
```

And implement in `FileCanonicalStore`:

```dart
@override
Future<String> conceptDirectoryPath(final String conceptId) async =>
    _conceptDir(conceptId);
```

Imports: add `import 'dart:convert';` and `import 'package:path/path.dart' as p;` to `default_canonical_service.dart` if not already present.

- [ ] **Step 5: Run service tests**

```bash
cd agentic_executables_core && dart test test/default_canonical_service_test.dart
```

Expected: all passing including the two new ones.

- [ ] **Step 6: Wire CLI to write the file after distill**

In `agentic_executables_cli/lib/src/cli.dart`, in `_handleCanonicalDistill` after the `mergeReport = ...` line and before the success return:

```dart
    // Persist proposals so `ae canonical accept-concept` can look them up.
    // Cleared automatically when the next distill produces zero proposals.
    await canonicalService.writeProposalsFile(
      concept,
      proposals: mergeReport.proposedConcepts,
      executorUsed: result.executorId,
    );
```

- [ ] **Step 7: Wire MCP**

In `agentic_executables_mcp/lib/src/adapter.dart`'s `case 'distill':` after the merge succeeds and before returning the success envelope, add the same `writeProposalsFile` call.

- [ ] **Step 8: Run all three suites**

```bash
cd agentic_executables_core && dart test 2>&1 | tail -3
cd ../agentic_executables_cli && dart test 2>&1 | tail -3
cd ../agentic_executables_mcp && dart test 2>&1 | tail -3
```

Expected: core 236+, CLI 66+, MCP 49+ (B3 adds 2 core; CLI/MCP integration tests live in B4).

- [ ] **Step 9: Commit**

```bash
git add agentic_executables_core agentic_executables_cli agentic_executables_mcp
git commit -m "feat: persist .last_proposals.json at distill end"
```

### Task B4: `ae canonical accept-concept` command

**Why:** Promotes a proposed cross-cutting concept to a stable matrix row at an operator-chosen id. One chance to pick the id; afterwards it's locked in (per design Q5). New error codes: `proposal_not_found`, `id_collision`.

**Files:**
- Modify: `agentic_executables_core/lib/src/services/canonical_service.dart` — add `acceptConcept` method, `ProposalNotFoundException`, `IdCollisionException`.
- Modify: `agentic_executables_core/lib/src/services/default_canonical_service.dart` — implement.
- Modify: `agentic_executables_core/test/default_canonical_service_test.dart` — four new tests.
- Modify: `agentic_executables_cli/lib/src/cli.dart` — add `accept-concept` subcommand parser + handler.
- Modify: `agentic_executables_cli/test/...` — one CLI integration test.
- Modify: `agentic_executables_mcp/lib/src/adapter.dart` — add `op: 'accept-concept'` operation.
- Modify: `agentic_executables_mcp/test/...` — one MCP test.

- [ ] **Step 1: Write the failing service tests**

```dart
test('acceptConcept happy path: appends row and clears the proposal', () async {
  final tmp = await Directory.systemTemp.createTemp('id_stability_b4_accept_ok');
  addTearDown(() async { await tmp.delete(recursive: true); });
  final store = FileCanonicalStore(tmp.path);
  final service = DefaultCanonicalService(store: store);

  await service.scaffold('demo', title: 'Demo');
  await service.writeProposalsFile(
    'demo',
    proposals: const [
      ProposedConcept(
        name: 'envelope-shape',
        spec: 'every command writes JSON',
        invariant: 'success is bool',
        rationale: 'cross-cutting',
      ),
    ],
    executorUsed: 'claude_code',
  );

  final result = await service.acceptConcept(
    'demo',
    newId: 'demo.json_envelope',
    fromProposal: 'envelope-shape',
  );

  expect(result.acceptedId, 'demo.json_envelope');
  expect(result.proposalName, 'envelope-shape');

  final after = (await service.load('demo'))!;
  final byId = {for (final f in after.matrix.features) f.id.toString(): f};
  expect(byId.keys, contains('demo.json_envelope'));
  expect(byId['demo.json_envelope']!.cells['spec'],
      'every command writes JSON');
  expect(byId['demo.json_envelope']!.cells['invariant'], 'success is bool');
  expect(byId['demo.json_envelope']!.cells['provenance'], 'accepted_concept');
});

test('acceptConcept errors when the proposal name is not in last_proposals', () async {
  final tmp = await Directory.systemTemp.createTemp('id_stability_b4_no_proposal');
  addTearDown(() async { await tmp.delete(recursive: true); });
  final store = FileCanonicalStore(tmp.path);
  final service = DefaultCanonicalService(store: store);

  await service.scaffold('demo', title: 'Demo');
  await service.writeProposalsFile(
    'demo',
    proposals: const [
      ProposedConcept(name: 'a', spec: 's', invariant: 'i', rationale: 'r'),
    ],
    executorUsed: 'claude_code',
  );

  expect(
    () => service.acceptConcept(
      'demo',
      newId: 'demo.x',
      fromProposal: 'not-a-proposal',
    ),
    throwsA(isA<ProposalNotFoundException>()
        .having((final e) => e.proposalName, 'proposalName', 'not-a-proposal')),
  );
});

test('acceptConcept errors when the new id already exists', () async {
  final tmp = await Directory.systemTemp.createTemp('id_stability_b4_collision');
  addTearDown(() async { await tmp.delete(recursive: true); });
  final store = FileCanonicalStore(tmp.path);
  final service = DefaultCanonicalService(store: store);

  await service.scaffold('demo', title: 'Demo');
  final seeded = _samplePack('demo', features: [
    CanonicalFeature(
      id: FeatureId.parse('demo.taken'),
      cells: const {'spec': 's', 'invariant': 'i'},
    ),
  ]);
  await service.upsert('demo', seeded);
  await service.writeProposalsFile(
    'demo',
    proposals: const [
      ProposedConcept(name: 'p', spec: 's', invariant: 'i', rationale: 'r'),
    ],
    executorUsed: 'claude_code',
  );

  expect(
    () => service.acceptConcept(
      'demo',
      newId: 'demo.taken',
      fromProposal: 'p',
    ),
    throwsA(isA<IdCollisionException>()
        .having((final e) => e.collidingId, 'collidingId', 'demo.taken')),
  );
});

test('acceptConcept errors when no proposals file exists', () async {
  final tmp = await Directory.systemTemp.createTemp('id_stability_b4_no_file');
  addTearDown(() async { await tmp.delete(recursive: true); });
  final store = FileCanonicalStore(tmp.path);
  final service = DefaultCanonicalService(store: store);

  await service.scaffold('demo', title: 'Demo');
  // Note: no writeProposalsFile call.

  expect(
    () => service.acceptConcept(
      'demo',
      newId: 'demo.x',
      fromProposal: 'anything',
    ),
    throwsA(isA<ProposalNotFoundException>()
        .having(
          (final e) => e.toString(),
          'toString',
          contains('no .last_proposals.json'),
        )),
  );
});
```

- [ ] **Step 2: Run, verify they fail**

```bash
cd agentic_executables_core && dart test test/default_canonical_service_test.dart --name 'acceptConcept'
```

Expected: compile failures (acceptConcept, ProposalNotFoundException, IdCollisionException).

- [ ] **Step 3: Define exceptions and result type**

In `canonical_service.dart`, append:

```dart
class ProposalNotFoundException implements Exception {
  const ProposalNotFoundException({
    required this.conceptId,
    required this.proposalName,
    required this.reason,
  });

  final String conceptId;
  final String proposalName;
  final String reason; // e.g. 'no .last_proposals.json' or 'name not in file'

  @override
  String toString() =>
      'ProposalNotFoundException(concept: $conceptId, '
      'proposal: $proposalName, reason: $reason)';
}

class IdCollisionException implements Exception {
  const IdCollisionException({
    required this.conceptId,
    required this.collidingId,
  });

  final String conceptId;
  final String collidingId;

  @override
  String toString() =>
      'IdCollisionException(concept: $conceptId, id: $collidingId)';
}

/// Result of [CanonicalService.acceptConcept]. Identifies the chosen id and
/// the proposal it was promoted from.
class AcceptConceptResult {
  const AcceptConceptResult({
    required this.acceptedId,
    required this.proposalName,
  });

  final String acceptedId;
  final String proposalName;
}
```

Add interface method:

```dart
  /// Promote a proposed concept to a stable matrix row. Reads the proposal
  /// by name from `<concept>/.last_proposals.json` (written by
  /// [writeProposalsFile] at distill end). The new row's `spec` and
  /// `invariant` come from the proposal verbatim; `provenance: accepted_concept`
  /// is added so future audits can identify accepted-concept rows.
  ///
  /// Throws [ProposalNotFoundException] if the proposals file is absent or
  /// the [fromProposal] name is not in it. Throws [IdCollisionException] if
  /// [newId] is already in the matrix. Throws [StateError] if the canonical
  /// does not exist.
  Future<AcceptConceptResult> acceptConcept(
    final String conceptId, {
    required final String newId,
    required final String fromProposal,
  });
```

- [ ] **Step 4: Implement**

In `default_canonical_service.dart`:

```dart
  @override
  Future<AcceptConceptResult> acceptConcept(
    final String conceptId, {
    required final String newId,
    required final String fromProposal,
  }) async {
    final existing = await store.load(conceptId);
    if (existing == null) {
      throw StateError(
        'canonical_not_found: $conceptId — run `ae canonical scaffold` or '
        '`ae canonical init` first',
      );
    }

    final knownIds = {
      for (final f in existing.matrix.features) f.id.toString(),
    };
    if (knownIds.contains(newId)) {
      throw IdCollisionException(
        conceptId: conceptId,
        collidingId: newId,
      );
    }

    final dirPath = await store.conceptDirectoryPath(conceptId);
    final file = File(p.join(dirPath, '.last_proposals.json'));
    if (!await file.exists()) {
      throw ProposalNotFoundException(
        conceptId: conceptId,
        proposalName: fromProposal,
        reason: 'no .last_proposals.json — run `ae canonical distill` first',
      );
    }
    final payload = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final proposalsRaw = (payload['proposals'] as List?) ?? const [];
    final proposalMap = <String, ProposedConcept>{};
    for (final raw in proposalsRaw) {
      if (raw is Map) {
        final pc = ProposedConcept.fromMap(raw);
        proposalMap[pc.name] = pc;
      }
    }
    final proposal = proposalMap[fromProposal];
    if (proposal == null) {
      throw ProposalNotFoundException(
        conceptId: conceptId,
        proposalName: fromProposal,
        reason: 'name not in .last_proposals.json '
            '(available: ${proposalMap.keys.join(", ")})',
      );
    }

    // Append the new row.
    final newFeature = CanonicalFeature(
      id: FeatureId.parse(newId),
      cells: {
        'spec': proposal.spec,
        'invariant': proposal.invariant,
        'provenance': 'accepted_concept',
      },
    );
    final mergedFeatures = [
      ...existing.matrix.features,
      newFeature,
    ];
    final mergedMatrix = CanonicalMatrix(
      concept: existing.matrix.concept,
      version: existing.matrix.version,
      columnSchema: _widenColumnSchema(
        existing.matrix.columnSchema,
        mergedFeatures,
      ),
      features: mergedFeatures,
    );
    final updated = CanonicalPack(
      meta: existing.meta,
      indexContent: existing.indexContent,
      matrix: mergedMatrix,
      changelogContent: existing.changelogContent,
    );
    await store.save(conceptId, updated);

    // Hygiene: drop the accepted proposal from the file. (Don't delete the
    // whole file — other proposals may still be pending.) Preserve the
    // original `produced_at` so the file keeps reflecting when distill
    // actually ran, not when the most recent accept happened.
    proposalMap.remove(fromProposal);
    final originalProducedAt = DateTime.tryParse(
      payload['produced_at']?.toString() ?? '',
    );
    await writeProposalsFile(
      conceptId,
      proposals: proposalMap.values.toList(growable: false),
      executorUsed: payload['executor_used']?.toString() ?? 'unknown',
      producedAt: originalProducedAt,
    );

    return AcceptConceptResult(
      acceptedId: newId,
      proposalName: fromProposal,
    );
  }
```

- [ ] **Step 5: Run service tests**

```bash
cd agentic_executables_core && dart test test/default_canonical_service_test.dart
```

Expected: all passing including the four new ones.

- [ ] **Step 6: Wire CLI subcommand**

In `agentic_executables_cli/lib/src/cli.dart` ArgParser block (~line 360, alongside `canonical?.addCommand('distill')`):

```dart
canonical?.addCommand('accept-concept')
  ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
  ..addOption('concept', help: 'Canonical concept slug (required).')
  ..addOption('id', help: 'New feature id to assign (required, operator-chosen).')
  ..addOption('from-proposal',
      help: 'Proposal name from the most recent distill run (required).')
  ..addOption('root', help: 'Project root.');
```

In the `case 'canonical':` switch in `_handleCanonical`, add a new `case 'accept-concept':` branch (after `case 'distill':`):

```dart
case 'accept-concept':
  final concept = sub['concept']?.toString();
  final id = sub['id']?.toString();
  final fromProposal = sub['from-proposal']?.toString();
  if (concept == null || concept.isEmpty) {
    return AeResult.fail(
      code: 'validation_error',
      message: 'Missing required --concept',
    );
  }
  if (id == null || id.isEmpty) {
    return AeResult.fail(
      code: 'validation_error',
      message: 'Missing required --id',
    );
  }
  if (fromProposal == null || fromProposal.isEmpty) {
    return AeResult.fail(
      code: 'validation_error',
      message: 'Missing required --from-proposal',
    );
  }
  try {
    final result = await svc.acceptConcept(
      concept,
      newId: id,
      fromProposal: fromProposal,
    );
    return AeResult.ok({
      'concept': concept,
      'accepted_id': result.acceptedId,
      'from_proposal': result.proposalName,
    });
  } on ProposalNotFoundException catch (e) {
    return AeResult.fail(
      code: 'proposal_not_found',
      message: e.toString(),
    );
  } on IdCollisionException catch (e) {
    return AeResult.fail(
      code: 'id_collision',
      message: e.toString(),
    );
  } on StateError catch (e) {
    if (e.message.contains('canonical_not_found')) {
      return AeResult.fail(
        code: 'canonical_not_found',
        message: e.message,
      );
    }
    rethrow;
  }
```

If the `_handleCanonical` switch has a default case that returns `invalid_command`, ensure the new `accept-concept` case falls before it.

- [ ] **Step 7: Wire MCP `op: accept-concept`**

In `agentic_executables_mcp/lib/src/adapter.dart`, add a new case in the `ae_canonical` operation switch (alongside `case 'distill'`):

```dart
case 'accept-concept':
  final concept = params['concept']?.toString();
  final id = params['id']?.toString();
  final fromProposal = params['from_proposal']?.toString();
  if (concept == null || concept.isEmpty) {
    return _validationError('Missing "concept"');
  }
  if (id == null || id.isEmpty) {
    return _validationError('Missing "id"');
  }
  if (fromProposal == null || fromProposal.isEmpty) {
    return _validationError('Missing "from_proposal"');
  }
  try {
    final result = await svc.acceptConcept(
      concept,
      newId: id,
      fromProposal: fromProposal,
    );
    return {
      'success': true,
      'data': {
        'concept': concept,
        'accepted_id': result.acceptedId,
        'from_proposal': result.proposalName,
      },
    };
  } on ProposalNotFoundException catch (e) {
    return {
      'success': false,
      'error': {'code': 'proposal_not_found', 'message': e.toString()},
    };
  } on IdCollisionException catch (e) {
    return {
      'success': false,
      'error': {'code': 'id_collision', 'message': e.toString()},
    };
  } on StateError catch (e) {
    if (e.message.contains('canonical_not_found')) {
      return {
        'success': false,
        'error': {'code': 'canonical_not_found', 'message': e.message},
      };
    }
    rethrow;
  }
```

- [ ] **Step 8: Add CLI + MCP integration tests**

Mirror the existing `canonical_distill_command_test.dart` pattern. Sketch:

```dart
test('canonical accept-concept promotes proposal to matrix row', () async {
  // ... hub init, scaffold (so canonical exists), writeProposalsFile direct
  // (or run a fake distill first via injected service) ...
  final result = await cli.run([
    'canonical', 'accept-concept',
    '--concept', 'demo',
    '--id', 'demo.json_envelope',
    '--from-proposal', 'envelope-shape',
    '--root', tmp.path,
  ]);
  final json = jsonDecode(result.stdout) as Map<String, dynamic>;
  expect(json['success'], isTrue);
  expect(json['data']['accepted_id'], 'demo.json_envelope');
});

test('canonical accept-concept returns proposal_not_found on bad name', () async {
  // ... setup as above ...
  final result = await cli.run([
    'canonical', 'accept-concept',
    '--concept', 'demo',
    '--id', 'demo.x',
    '--from-proposal', 'not-real',
    '--root', tmp.path,
  ]);
  final json = jsonDecode(result.stdout) as Map<String, dynamic>;
  expect(json['success'], isFalse);
  expect(json['error']['code'], 'proposal_not_found');
});
```

MCP coverage: split into two tests so MCP suite reaches the 51+ target.

```dart
test('ae_canonical accept-concept happy path returns accepted_id', () async {
  // ... MCP setup: hub init, scaffold a concept, write proposals via service
  //     (or via a fake distill) ...
  final result = await adapter.callTool('ae_canonical', {
    'op': 'accept-concept',
    'concept': 'demo',
    'id': 'demo.json_envelope',
    'from_proposal': 'envelope-shape',
  });
  expect(result['success'], isTrue);
  expect((result['data'] as Map)['accepted_id'], 'demo.json_envelope');
});

test('ae_canonical accept-concept returns id_collision when id already exists', () async {
  // ... MCP setup: scaffold + upsert a row with id `demo.taken` + write
  //     proposals as above ...
  final result = await adapter.callTool('ae_canonical', {
    'op': 'accept-concept',
    'concept': 'demo',
    'id': 'demo.taken',
    'from_proposal': 'envelope-shape',
  });
  expect(result['success'], isFalse);
  expect(((result['error']) as Map)['code'], 'id_collision');
});
```

- [ ] **Step 9: Run all three suites**

```bash
cd agentic_executables_core && dart test 2>&1 | tail -3
cd ../agentic_executables_cli && dart test 2>&1 | tail -3
cd ../agentic_executables_mcp && dart test 2>&1 | tail -3
```

Expected: core 238+, CLI 67+, MCP 51+ (B4 adds 4 core + 2 CLI + 2 MCP; combined with B0–B3, totals match the handoff target).

- [ ] **Step 10: Commit**

```bash
git add agentic_executables_core agentic_executables_cli agentic_executables_mcp
git commit -m "feat: ae canonical accept-concept — promote proposal to stable id"
```

### Task B5: Documentation

**Files:**
- Modify: `docs_site/docs/ae-3/cli-reference.md` — `--update`, `--rename` on scaffold; new `### ae canonical accept-concept` section; `proposed_concepts` envelope note (already partially landed in A7).
- Modify: `docs_site/docs/ae-3/mcp-reference.md` — analogous on `ae_canonical` tool.
- Modify: `docs/error_code_playbook.md` — add `canonical_not_found`, `proposal_not_found`, `id_collision`.
- Modify: `docs_site/docs/ae-3/cli-reference.md` and `mcp-reference.md` — "Commands at a glance" / "Tools at a glance" tables.

- [ ] **Step 1: Document `scaffold --update` in the CLI reference**

In `docs_site/docs/ae-3/cli-reference.md`, find the `### ae canonical scaffold` section. Append after the existing flag docs:

```markdown
**`--update` mode (3.2.0).** Reconciles an existing canonical against current source-artifact symbols. Deterministic — no LLM. Adds rows for new symbols (with stub spec/invariant text), marks vanished symbols `removed: true` while preserving their text, and leaves unchanged rows untouched. Idempotent.

Mutually exclusive with `--overwrite`. Requires the canonical to exist (`canonical_not_found` otherwise). The envelope's `data` carries `mode: "update"`, `added: [...]`, `removed: [...]`, `unchanged: <int>`, and (when `--rename` was supplied) `renamed: [{from, to}, ...]`.

```bash
ae canonical scaffold --concept ae_cli --from-artifact agentic_executables_cli --update
```

**`--rename old=new` (3.2.0).** Repeatable. Strict-by-default rename detection — without `--rename`, a renamed source symbol appears as `removed: true` of the old id plus a fresh row at the new id (text is lost). With `--rename`, the row's `spec`/`invariant` text migrates to the new id; a tombstone row at the old id retains `removed: true` plus `renamed_to: <new>` for downstream traceability. Errors `validation_error` if `old` is missing or `new` already exists in the matrix. See [id-stability design Q4](../../../docs/superpowers/specs/2026-04-27-canonical-id-stability-design.md).

```bash
ae canonical scaffold --concept ae_cli --from-artifact agentic_executables_cli --update \
  --rename ae_cli.old_name=ae_cli.new_name
```
```

- [ ] **Step 2: Document `accept-concept` in the CLI reference**

After the `### ae canonical distill` section, add:

```markdown
### ae canonical accept-concept

Promote a proposed cross-cutting concept (from the most recent `distill` run) to a stable matrix row at an operator-chosen id.

Required: `--concept`, `--id` (the new feature id), `--from-proposal` (the proposal's `name` field as it appeared in `proposed_concepts`).

Reads `.ae_hub/canonical/<concept>/.last_proposals.json` (written automatically at distill end, gitignored). Errors:
- `proposal_not_found` — no proposals file exists, or `--from-proposal` is not in the file.
- `id_collision` — `--id` already exists in the matrix.
- `canonical_not_found` — the concept does not exist (run `ae canonical scaffold` or `ae canonical init` first).

```bash
ae canonical accept-concept --concept ae_cli \
  --id ae_cli.json_envelope_shape \
  --from-proposal envelope-shape
```

The new row carries `spec` and `invariant` from the proposal verbatim, plus `provenance: accepted_concept` for audit. The accepted proposal is removed from `.last_proposals.json` so subsequent `accept-concept` calls can't double-promote it. See [id-stability design Q5](../../../docs/superpowers/specs/2026-04-27-canonical-id-stability-design.md) for the proposal-then-accept rationale.
```

- [ ] **Step 3: Update CLI "Commands at a glance" table**

Find the table near the top of `cli-reference.md` and add rows for the new commands:

```markdown
| `ae canonical scaffold --update` | Reconcile matrix against current source symbols (no LLM). |
| `ae canonical accept-concept` | Promote a distilled `proposed_concept` to a stable matrix row. |
```

- [ ] **Step 4: Mirror in MCP reference**

In `docs_site/docs/ae-3/mcp-reference.md`, find the `ae_canonical` tool section. Document:
- `op: 'scaffold'` with `update: true` parameter (and `renames: [{from, to}, ...]`).
- New `op: 'accept-concept'` with required params `concept`, `id`, `from_proposal`.
- Error codes `canonical_not_found`, `proposal_not_found`, `id_collision`.

Sample MCP tool call:

```json
{
  "name": "ae_canonical",
  "arguments": {
    "op": "accept-concept",
    "concept": "ae_cli",
    "id": "ae_cli.json_envelope_shape",
    "from_proposal": "envelope-shape"
  }
}
```

- [ ] **Step 5: Update error_code_playbook.md**

In `docs/error_code_playbook.md`, append rows to the table:

```markdown
| `canonical_not_found` | CLI/MCP `canonical scaffold --update`, `accept-concept` | Operation requires an existing canonical at the concept slug | no | `ae canonical scaffold --concept <c> --title <t> --from-artifact <p>` to create the canonical first |
| `proposal_not_found` | CLI/MCP `canonical accept-concept` | `--from-proposal` name is absent from `.last_proposals.json`, or the file does not exist | no | Run `ae canonical distill` first; copy the `name` field from `proposed_concepts` in the envelope |
| `id_collision` | CLI/MCP `canonical accept-concept` | `--id` already exists in the matrix at the concept | no | Pick a different `--id`, or rename the existing row first via `ae canonical scaffold --update --rename old=new` |
```

The `id_not_in_matrix` row already exists from Phase A — leave it.

- [ ] **Step 6: Note the additive schema bump in spec-export docs**

Per design Q11, `removed: true` and `renamed_to: <id>` (carried as a cell value) are surfaced through `spec_export.v3` automatically (B1's `CanonicalFeature.toJson` extension and the matrix's existing `cells` passthrough do the work). The schema is additive — old consumers ignore unknown keys — but the change should be documented so downstream callers know the fields are now possible.

In `docs_site/docs/ae-3/cli-reference.md`, find the `### ae spec export` section. Append a paragraph:

```markdown
**Schema additions (3.2.0).** Feature rows in `spec_index.json` may now include `removed: true` (set by `ae canonical scaffold --update` for symbols that vanished from source) and a `renamed_to: <new_id>` cell (set by `ae canonical scaffold --update --rename`). Both fields are additive — old consumers of `spec_export.v3` ignore them. See [id-stability design Q11](../../../docs/superpowers/specs/2026-04-27-canonical-id-stability-design.md).
```

- [ ] **Step 7: Verify the docs site builds**

```bash
cd docs_site && npm run build 2>&1 | tail -5
```

Expected: `build complete in N.NNs.` No broken links.

- [ ] **Step 8: Verify docs_contract_test still passes**

The CLI's `docs_contract_test.dart` regex-scans for `code: '...'` literals and requires every code in source to appear in the playbook. The new error codes must already be in the playbook (Step 5).

```bash
cd agentic_executables_cli && dart test test/docs_contract_test.dart
```

Expected: pass.

- [ ] **Step 9: Commit**

```bash
git add docs_site/docs/ae-3/cli-reference.md \
        docs_site/docs/ae-3/mcp-reference.md \
        docs/error_code_playbook.md
git commit -m "docs: document Phase B canonical commands and error codes"
```

### Task B6: Phase B smoke test

This is **manual verification** — proves the new operator workflow end-to-end on the dogfood-iter-1 hub. Three sub-scenarios:
1. **scaffold-update detects source diff** (add/remove a fake symbol; run `--update`; verify report).
2. **accept-concept persists across re-distill** (distill; accept one proposal; re-scaffold + re-distill; verify the accepted row survives).
3. **B0 closure verified** (distill before init/scaffold rejects with `id_not_in_matrix`).

- [ ] **Step 1: Compile the post-Phase-B binary**

```bash
cd agentic_executables_cli && dart pub get && cd ..
dart compile exe agentic_executables_cli/bin/ae.dart -o /tmp/ae-phase-b
/tmp/ae-phase-b --help | head -5
```

- [ ] **Step 2: Preserve the v2 hub and set up a clean smoke environment**

```bash
mv .ae_hub .ae_hub.preserve.phase-b 2>/dev/null || true
/tmp/ae-phase-b hub init --project
/tmp/ae-phase-b init --root .
```

- [ ] **Step 3: Verify B0 — distill before scaffold/init must reject**

```bash
/tmp/ae-phase-b canonical distill --pack agentic_executables_cli --concept ae_cli_b6 --root . | tee /tmp/phase-b-no-init.json
```

Expected: `{"success": false, "error": {"code": "id_not_in_matrix" or "...", ...}}`. The exact code depends on whether the LLM proposes any features under an empty matrix (likely 0 features → success with empty matrix is also acceptable; what matters is no rows landed). Capture either way.

Actually, more reliable: skip distill entirely for B0; instead test the validator directly on a synthetic distill output via the unit-test scaffolding. The CLI smoke for B0 is "init alone, then verify distill respects the empty matrix":

```bash
/tmp/ae-phase-b canonical init --concept ae_cli_b6 --title "AE CLI B6" --root .
/tmp/ae-phase-b canonical distill --pack agentic_executables_cli --concept ae_cli_b6 --root . | tee /tmp/phase-b-init-only.json
```

Expected: either `"success": false` with `id_not_in_matrix` (LLM produced features against the empty matrix), or `"success": true` with `feature_count: 0` and `proposed_concepts: [...]` (LLM correctly routed everything to proposals). Both prove B0 is sound.

- [ ] **Step 4: Verify B1 — scaffold and run --update**

```bash
rm -rf .ae_hub/canonical/ae_cli_b6
/tmp/ae-phase-b canonical scaffold --concept ae_cli_b6 --title "AE CLI" \
  --from-artifact agentic_executables_cli --root .
SCAFFOLD_COUNT=$(grep -c '^  - id:' .ae_hub/canonical/ae_cli_b6/matrix.yaml)
echo "scaffold_count: $SCAFFOLD_COUNT"

# Re-run scaffold with --update against the same artifact (no source change).
/tmp/ae-phase-b canonical scaffold --concept ae_cli_b6 \
  --from-artifact agentic_executables_cli --update --root . | tee /tmp/phase-b-update-noop.json
```

Expected: the `--update` envelope shows `added: []`, `removed: []`, `unchanged: <SCAFFOLD_COUNT>`. Idempotent re-run produces no diff.

- [ ] **Step 5: Verify B1 — simulate a source change**

Edit one source file in `agentic_executables_cli/lib/src/cli.dart` to add a fake public method (or use `agentic_executables_core` and rebuild the artifact pack via `ae init`). Re-run `--update`:

```bash
# After hand-editing a source file to add a fake public symbol:
/tmp/ae-phase-b init --root .
/tmp/ae-phase-b canonical scaffold --concept ae_cli_b6 \
  --from-artifact agentic_executables_cli --update --root . | tee /tmp/phase-b-update-added.json
```

Expected: envelope shows `added: ["agentic_executables_cli.fake_method"]` (or similar). Then revert the source change and re-run; expected `removed:` populated.

(Alternative if hand-editing source feels too invasive: copy the artifact pack to a tmp hub location, hand-edit the artifact's index.md to add a synthetic `## Public API` bullet, and re-run scaffold against that hand-edited pack.)

- [ ] **Step 6: Verify B3+B4 — accept-concept persists across re-distill**

```bash
# Run distill to populate proposed_concepts.
/tmp/ae-phase-b canonical distill --pack agentic_executables_cli --concept ae_cli_b6 --root . \
  | tee /tmp/phase-b-distill-1.json
# Pick a proposal name from the envelope (jq if installed):
PROPOSAL=$(jq -r '.data.proposed_concepts[0].name' /tmp/phase-b-distill-1.json)
echo "accepting proposal: $PROPOSAL"
/tmp/ae-phase-b canonical accept-concept --concept ae_cli_b6 \
  --id "ae_cli_b6.accepted_$PROPOSAL" \
  --from-proposal "$PROPOSAL" --root . | tee /tmp/phase-b-accept.json
# Verify the new row exists.
grep "^  - id: ae_cli_b6.accepted_" .ae_hub/canonical/ae_cli_b6/matrix.yaml
```

Expected: the accept envelope reports `success: true` with `accepted_id`. The new row is in `matrix.yaml`. Re-running distill should preserve this row (the validator now knows its id).

- [ ] **Step 7: Verify the determinism gate from Phase A still holds**

```bash
rm -rf .ae_hub/canonical/ae_cli_b6
/tmp/ae-phase-b canonical scaffold --concept ae_cli_b6 --title "AE CLI" \
  --from-artifact agentic_executables_cli --root .
/tmp/ae-phase-b canonical distill --pack agentic_executables_cli --concept ae_cli_b6 --root . > /tmp/phase-b-run-x.json
cp .ae_hub/canonical/ae_cli_b6/matrix.yaml /tmp/phase-b-matrix-x.yaml

rm -rf .ae_hub/canonical/ae_cli_b6
/tmp/ae-phase-b canonical scaffold --concept ae_cli_b6 --title "AE CLI" \
  --from-artifact agentic_executables_cli --root .
/tmp/ae-phase-b canonical distill --pack agentic_executables_cli --concept ae_cli_b6 --root . > /tmp/phase-b-run-y.json
cp .ae_hub/canonical/ae_cli_b6/matrix.yaml /tmp/phase-b-matrix-y.yaml

awk '/^  - id:/ {print $3}' /tmp/phase-b-matrix-x.yaml | sort -u > /tmp/phase-b-ids-x
awk '/^  - id:/ {print $3}' /tmp/phase-b-matrix-y.yaml | sort -u > /tmp/phase-b-ids-y
echo "x_ids: $(wc -l < /tmp/phase-b-ids-x)"
echo "y_ids: $(wc -l < /tmp/phase-b-ids-y)"
echo "common: $(comm -12 /tmp/phase-b-ids-x /tmp/phase-b-ids-y | wc -l)"
echo "only_in_x: $(comm -23 /tmp/phase-b-ids-x /tmp/phase-b-ids-y | wc -l)"
echo "only_in_y: $(comm -13 /tmp/phase-b-ids-x /tmp/phase-b-ids-y | wc -l)"
```

Expected: same numbers as Phase A's smoke (14/14 for `agentic_executables_cli`). Phase B must not regress determinism.

- [ ] **Step 8: Restore the v2 hub and commit smoke artifacts**

```bash
rm -rf .ae_hub
[ -d .ae_hub.preserve.phase-b ] && mv .ae_hub.preserve.phase-b .ae_hub
git status --short
mkdir -p docs/superpowers/notes/phase-b-smoke
cp /tmp/phase-b-*.json /tmp/phase-b-matrix-x.yaml /tmp/phase-b-matrix-y.yaml \
   /tmp/phase-b-ids-x /tmp/phase-b-ids-y \
   docs/superpowers/notes/phase-b-smoke/
cat > docs/superpowers/notes/phase-b-smoke/SUMMARY.md <<EOF
# Phase B smoke

- B0 (init-only distill): <fill: rejected with id_not_in_matrix / accepted with 0 features>
- B1 (scaffold --update no-op): added=0 removed=0 unchanged=<n>
- B1 (scaffold --update with source change): added=<list> removed=<list>
- B3+B4 (accept-concept end-to-end): accepted_id=<id>, persisted=<yes/no>
- Determinism gate: x=<n>, y=<n>, common=<n>, only_in_{x,y}=<n,n>
- Verdict: <pass / fail>
EOF
# Hand-edit SUMMARY.md to fill in the actual numbers/strings.
git add docs/superpowers/notes/phase-b-smoke/
git commit -m "test(phase-b): smoke validation of scaffold --update and accept-concept"
```

- [ ] **Step 9: Confirm Phase B is complete on `v2`**

Only after the smoke summary records `Verdict: pass`:

```bash
git log --oneline | head -12
```

Expected: B0–B6 commits visible at the tip of `v2` in order. No merge step needed (operator chose to commit directly to v2 rather than use a feature branch + `--no-ff` merge for this phase).

---

---

## Phase C — FAQ-as-context, reuse-class, migration (additive)

**Branch:** `id-stability-phase-c` off `v2` after Phase B merges.

**Status of this section:** OUTLINE-ONLY. Expand in place after Phase B smokes clean.

### Task C1: Load `DESIGN_FAQ.md` / `DX_FAQ.md` as executor context

Inside `DistillationTask.toJson()` (or in the executor's prompt builder), if `<hub>/canonical/<concept>/DESIGN_FAQ.md` and/or `DX_FAQ.md` exist, load their contents and add to the task's `examples` field (or a new `context_documents` field) verbatim. The executor includes them in the prompt as background.

Tests: 2 unit (FAQ present → included in task; FAQ absent → no error).

### Task C2: `ae status --reuse-class` derived view

New flag on `ae status`. Computes per-feature inbound-link count from artifact packs, classifies as `library` (≥2 packs across ≥2 concepts), `app` (1 pack), or `orphan` (0 packs). Filters output by class.

Tests: 3 unit (each class produces correct rows on a synthetic hub).

### Task C3: Migration helper — `--migrate` flag on scaffold update

`ae canonical scaffold --update --migrate` marks rows whose id is not in the source artifact AND was not originally produced by scaffold (no `provenance` heuristic) as `legacy: true`. Operator then either accepts each as a concept (gives it a stable id) or deletes by hand.

Tests: 2 unit (legacy detection; idempotent re-run).

### Task C4: Iter 2 dogfood plan

Separate plan file at `docs/superpowers/plans/2026-04-28-ae-3.0-dogfood-iter-2.md` (or whatever date Phase C lands). Re-runs Q1 under the post-Phase-A contract and additionally tests:
- Scaffold-update detects added/removed source symbols.
- Accept-concept persists across re-distill.
- DESIGN_FAQ.md influences distill output (compare with/without FAQ).
- Reuse-class derivation produces sensible results on the AE repo's three packs.

Pass condition: Iter 2's "two consecutive distill runs after scaffold" produces identical id sets — closes Q1 empirically.

### Task C5: Document Phase C; update spec §15 to "resolved"

CLI reference / MCP reference additions for `--reuse-class`, `--migrate`. Update [`specs/2026-04-17-ae-3.0-design.md`](../specs/2026-04-17-ae-3.0-design.md) §15 "Resolved-direction proposed by Iter 1" → "Resolved by Iter 2 (link to dogfood report)".

---

## Self-review checklist

**1. Spec coverage** — does each numbered item in the design's "Specification" section have a task?

| Spec item | Task |
|---|---|
| 1. Validator | A3 (initial) + B0 (close empty-matrix bypass) |
| 2. Distill prompt | A4 |
| 3. Distill envelope | A1, A2, A5, A6 |
| 4. `scaffold --update` | B1 |
| 5. `--rename` flag | B2 |
| 6. `accept-concept` | B3 (persist proposals) + B4 (accept) |
| 7. DESIGN_FAQ context | C1 |
| 8. Reuse-class derivation | C2 |
| 9. Migration helper | C3 |

All 9 covered. ✓

**2. Placeholder scan** — Phase A and Phase B are fully detailed with TDD code. Phase C remains OUTLINE-ONLY with named tasks; this is a deliberate scope-control choice (don't write detail for code that depends on Phase B's empirical validation). The skill's "no placeholders" rule applies to the executable work in this plan, which is now Phases A + B.

**3. Type consistency** — `ProposedConcept` is defined in A1 and used by name in A2, A3, A5, A6, B3, B4. `IdNotInMatrixException` is defined in A3 and used in B0. `CanonicalMergeResult.proposedConcepts` is the passthrough field, named consistently across A2/A5/A6 and read by B3. New Phase B types: `ScaffoldUpdateReport` (B1, used by B2), `ProposalNotFoundException`, `IdCollisionException`, `AcceptConceptResult` (all B4). `CanonicalFeature.removed` (B1) is read by B2's rename loop and by the matrix yaml emitter. The new `CanonicalStore.conceptDirectoryPath` port method (B3) is consumed by both B3 and B4.

**4. Backward compatibility** — Phase B is additive on top of Phase A:
- New CLI flags (`--update`, `--rename`) are off by default; existing scaffold invocations are unchanged.
- New CLI subcommand (`accept-concept`) doesn't touch existing commands.
- New optional model field (`CanonicalFeature.removed`) defaults to false and is omitted from json/yaml when false.
- New core service methods (`scaffoldUpdate`, `acceptConcept`, `writeProposalsFile`, `conceptDirectoryPath`) are additive on the interface.
- New error codes (`canonical_not_found`, `proposal_not_found`, `id_collision`) are scoped to the new operations.
- The B0 validator-unification change is the only behavior tightening: `distill` against a missing concept used to silently create a pack from LLM output and now rejects with `id_not_in_matrix` (or accepts an empty-features output). This was already broken behavior per Phase A's contract; B0 closes the loophole. The migration: operators run `ae canonical init` or `ae canonical scaffold` before their first distill against a concept.
