import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:test/test.dart';

void main() {
  group('VerifyTier', () {
    test('values + ordering', () {
      expect(VerifyTier.invariantViolation.tier, 1);
      expect(VerifyTier.upstreamBlocker.tier, 2);
      expect(VerifyTier.partialFeature.tier, 3);
      expect(VerifyTier.unreferencedCanonical.tier, 4);
    });
  });

  group('VerifyEntry', () {
    test('serializes minimal entry', () {
      final e = VerifyEntry(
        tier: VerifyTier.invariantViolation,
        artifact: 'dart_ecs',
        canonical: 'ecs',
        featureId: FeatureId.parse('system.tick'),
        message: 'invariant unverified: monotonic',
      );
      final j = e.toJson();
      expect(j['tier'], 1);
      expect(j['artifact'], 'dart_ecs');
      expect(j['feature_id'], 'system.tick');
    });

    test('downstreamCount surfaces in JSON when set', () {
      final e = VerifyEntry(
        tier: VerifyTier.upstreamBlocker,
        artifact: 'dart_ecs',
        canonical: 'ecs',
        featureId: FeatureId.parse('entity.create'),
        message: 'missing',
        downstreamCount: 3,
      );
      expect(e.toJson()['downstream_count'], 3);
    });
  });

  group('VerifyReport', () {
    test('groups entries by tier and counts', () {
      final r = VerifyReport(entries: [
        VerifyEntry(
          tier: VerifyTier.invariantViolation,
          artifact: 'a',
          canonical: 'ecs',
          featureId: FeatureId.parse('x.y'),
          message: 'msg',
        ),
        VerifyEntry(
          tier: VerifyTier.invariantViolation,
          artifact: 'a',
          canonical: 'ecs',
          featureId: FeatureId.parse('x.z'),
          message: 'msg',
        ),
        VerifyEntry(
          tier: VerifyTier.upstreamBlocker,
          artifact: 'b',
          canonical: 'ecs',
          featureId: FeatureId.parse('x.w'),
          message: 'msg',
        ),
      ]);
      expect(r.byTier(VerifyTier.invariantViolation).length, 2);
      expect(r.byTier(VerifyTier.upstreamBlocker).length, 1);
      expect(r.tierCounts[VerifyTier.invariantViolation], 2);
      expect(r.tierCounts[VerifyTier.upstreamBlocker], 1);
      expect(r.hasBlockingTiers, isTrue); // tier 1 or 2 present
    });

    test('hasBlockingTiers false when only tier 3+', () {
      final r = VerifyReport(entries: [
        VerifyEntry(
          tier: VerifyTier.partialFeature,
          artifact: 'a',
          canonical: 'ecs',
          featureId: FeatureId.parse('x.y'),
          message: 'partial',
        ),
      ]);
      expect(r.hasBlockingTiers, isFalse);
    });
  });
}
