import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:test/test.dart';

void main() {
  group('DefaultAeValidationService', () {
    const service = DefaultAeValidationService();

    test('verify passes for compliant bootstrap input', () {
      final result = service.verify(
        const VerifyInput(
          context: AeContext.library,
          action: AeAction.bootstrap,
          filesModified: [
            AeModifiedFile(
              path: 'ae_bootstrap.md',
              loc: 200,
              sections: ['Workflow', 'Guidelines'],
            ),
            AeModifiedFile(path: 'ae_install.md', loc: 200),
            AeModifiedFile(path: 'ae_uninstall.md', loc: 180),
            AeModifiedFile(path: 'ae_update.md', loc: 180),
            AeModifiedFile(path: 'ae_use.md', loc: 180),
          ],
          checklistCompleted: {
            'modularity': true,
            'contextual_awareness': true,
            'agent_empowerment': true,
            'validation': true,
            'integration': true,
            'analysis_guidance': true,
            'file_generation_rules': true,
            'abstraction': true,
          },
        ),
      );

      expect(result.success, isTrue);
      expect(result.data?.overallPass, isTrue);
    });

    test('verify fails when required files are missing', () {
      final result = service.verify(
        const VerifyInput(
          context: AeContext.library,
          action: AeAction.bootstrap,
          filesModified: [AeModifiedFile(path: 'ae_bootstrap.md', loc: 200)],
          checklistCompleted: {
            'modularity': true,
            'contextual_awareness': true,
            'agent_empowerment': true,
          },
        ),
      );

      expect(result.success, isTrue);
      expect(result.data?.overallPass, isFalse);
      expect(result.data?.missingItems, isNotEmpty);
    });

    test('evaluate fails for missing section and required flags', () {
      final result = service.evaluate(
        const EvaluateInput(
          context: AeContext.library,
          action: AeAction.bootstrap,
          filesCreated: [AeCreatedFile(path: 'ae_bootstrap.md', loc: 200)],
          sectionsPresent: ['Workflow'],
          validationStepsExists: false,
          integrationPointsDefined: false,
          hasMetaRules: false,
        ),
      );

      expect(result.success, isTrue);
      expect(result.data?.overallPass, isFalse);
      expect(result.data?.actionableFixes, isNotEmpty);
    });
  });
}
