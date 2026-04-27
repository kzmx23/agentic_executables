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

**Branch:** `id-stability-phase-b` off `v2` after Phase A merges.

**Status of this section:** OUTLINE-ONLY. Each task is named and scoped, but the TDD-shaped step-by-step is deferred until Phase A's smoke test demonstrates the validator works in practice. Expand this section in place when Phase A merges.

### Task B1: `ae canonical scaffold --update` mode

Extend `CanonicalService.scaffoldFromArtifact` (and `DefaultCanonicalService` impl) with an `updateExisting: bool = false` parameter. When true:
- Load existing matrix.
- Compute `current_symbol_ids` from artifact source.
- For each new id (in artifact, not in matrix): append a stub row.
- For each missing id (in matrix, not in artifact, not already `removed: true`): set `removed: true` on the row, preserve text.
- Preserve all `spec`/`invariant`/`notes` text on existing rows.
- Return a small report: `{added: [...], removed: [...], unchanged: N}`.

Surface as `--update` flag on `ae canonical scaffold`. Add MCP equivalent on `ae_canonical` operation `scaffold` (`update: true` parameter).

Tests: 3 unit tests on the service (pure new symbol; pure removed symbol; unchanged) + one CLI integration test.

### Task B2: `--rename old=new` flag

Repeatable flag on `ae canonical scaffold --update`. Maps an old id to a new id. Behavior:
- The row at `old` is updated: id → `new`, plus `renamed_to: <new>` retained on a stub `removed: true` row at `old`.
- Preserves `spec`/`invariant`/`notes` text under `new`.
- Validates that `old` exists and `new` does not already exist; errors `validation_error` otherwise.

Tests: 2 unit (clean rename; collision error) + 1 CLI integration.

### Task B3: `ae canonical accept-concept` command

New CLI command and MCP operation. Args:
- `--concept <slug>` — required.
- `--id <new_id>` — required. Operator-chosen.
- `--from-proposal <name>` — required. Looked up from a small file `.ae_hub/canonical/<concept>/.last_proposals.json` written automatically at the end of every distill run (new core service method).

Behavior:
- Read `.last_proposals.json`, find the entry by `name`, error `proposal_not_found` if missing.
- Validate `--id` is not already in the matrix (error `id_collision`).
- Append a new row with the proposed `spec`/`invariant` text and a `provenance: accepted_concept` cell.
- Write the matrix.
- Optional: remove the accepted entry from `.last_proposals.json` (or mark it `accepted_as: <id>`).

Tests: 4 unit (happy path; missing proposal; id collision; missing concept) + 1 CLI integration.

### Task B4: Persist `.last_proposals.json` at distill end

Inside `_handleCanonicalDistill` (CLI) and the MCP equivalent, after a successful distill, write the proposals to `<hub>/canonical/<concept>/.last_proposals.json`. Format:

```json
{
  "schema": "ae.proposed_concepts.v1",
  "concept": "<slug>",
  "produced_at": "<ISO-8601>",
  "executor_used": "<id>",
  "proposals": [{name, spec, invariant, rationale}, ...]
}
```

Tests: 1 unit ensuring the file is written and readable. Path is under `.ae_hub/`, gitignored, no tracked-state issues.

### Task B5: Document Phase B in cli-reference / mcp-reference

Add `### ae canonical scaffold` section's `--update` flag, `--rename` flag, and a new `### ae canonical accept-concept` section. MCP analogue. Update "Commands at a glance" table.

### Task B6: Phase B smoke test

Mirror Task A8 — test scaffold-update on `agentic_executables_cli` after a hand-edit of source (add a fake symbol; verify `--update` adds it; remove it; verify `--update` marks it removed). Test `accept-concept` end-to-end: distill → review proposals → accept one → verify matrix has the new row.

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
| 1. Validator | A3 |
| 2. Distill prompt | A4 |
| 3. Distill envelope | A1, A2, A5, A6 |
| 4. `scaffold --update` | B1 |
| 5. `--rename` flag | B2 |
| 6. `accept-concept` | B3, B4 |
| 7. DESIGN_FAQ context | C1 |
| 8. Reuse-class derivation | C2 |
| 9. Migration helper | C3 |

All 9 covered. ✓

**2. Placeholder scan** — Phase A is fully detailed with TDD code. Phase B and Phase C are explicitly OUTLINE-ONLY with named tasks; this is a deliberate scope-control choice (don't write detail for code that depends on Phase A's empirical validation). The skill's "no placeholders" rule applies to the executable work in this plan, which is Phase A.

**3. Type consistency** — `ProposedConcept` is defined in A1 and used by name in A2, A3, A5, A6, B3, B4. `IdNotInMatrixException` is defined in A3 and not referenced after — Phase A only. `CanonicalMergeResult.proposedConcepts` is the passthrough field, named consistently across A2/A5/A6.

**4. Backward compatibility** — Phase A's only externally-observable change is (a) a new optional envelope key `proposed_concepts`, and (b) a new error code `id_not_in_matrix` that fires only when distill returns ids not in matrix. Existing callers that don't read `proposed_concepts` are unaffected. Existing canonicals are unaffected (their existing ids remain valid). The only break is "distill that used to succeed by inventing ids will now fail" — which is exactly the intended behavior.
