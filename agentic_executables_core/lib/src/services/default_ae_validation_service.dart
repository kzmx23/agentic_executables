import '../config/ae_core_config.dart';
import '../models/ae_result.dart';
import '../models/evaluate.dart';
import '../models/types.dart';
import '../models/verify.dart';
import 'ae_validation_service.dart';

class DefaultAeValidationService implements AeValidationService {
  const DefaultAeValidationService();

  @override
  AeResult<VerifyOutput> verify(final VerifyInput input) {
    final checklistChecks = <VerifyCheck>[];
    var passCount = 0;
    var totalChecks = 0;

    final requiredChecklistItems = <Map<String, Object>>[
      ...AeCoreConfig.getCoreChecklistItems(),
      ...AeCoreConfig.getActionChecklistItems(input.context, input.action),
    ];

    for (final item in requiredChecklistItems) {
      final itemKey = item['key'] as String;
      final itemName = item['name'] as String;
      final critical = (item['critical'] as bool?) ?? true;
      final completed = input.checklistCompleted[itemKey] == true;

      totalChecks += 1;
      if (completed) {
        passCount += 1;
      }

      checklistChecks.add(
        VerifyCheck(
          item: itemName,
          key: itemKey,
          status: completed ? 'PASS' : 'FAIL',
          critical: critical,
          details: completed
              ? 'Checklist item completed'
              : 'Checklist item not completed',
        ),
      );
    }

    final fileCheckResult = _verifyFileStructure(input);
    totalChecks += fileCheckResult.total;
    passCount += fileCheckResult.passed;

    final checks = <VerifyCheck>[...checklistChecks, ...fileCheckResult.checks];
    final overallPass = passCount == totalChecks;

    final output = VerifyOutput(
      overallPass: overallPass,
      passCount: passCount,
      totalChecks: totalChecks,
      passRate:
          totalChecks == 0 ? 0 : ((passCount / totalChecks) * 100).round(),
      checks: checks,
      missingItems: checks
          .where((final check) => check.status != 'PASS' && check.critical)
          .map((final check) => '${check.item}: ${check.details}')
          .toList(growable: false),
      warnings: _warningsForFiles(input.filesModified),
    );

    return AeResult.ok(
      output,
      meta: {'overall_status': output.overallPass ? 'PASS' : 'FAIL'},
    );
  }

  @override
  AeResult<EvaluateOutput> evaluate(final EvaluateInput input) {
    final checks = <EvaluateCheck>[];
    var passCount = 0;
    var totalChecks = 0;

    final requiredFiles = AeCoreConfig.getRequiredFiles(
      input.context,
      input.action,
    );
    final createdPaths = input.filesCreated
        .map((final file) => file.path)
        .toList(growable: false);
    final missingFiles = requiredFiles
        .where((final file) => !createdPaths.contains(file))
        .toList();
    final filesPass = missingFiles.isEmpty;

    totalChecks += 1;
    if (filesPass) {
      passCount += 1;
    }
    checks.add(
      EvaluateCheck(
        criterion: 'Required Files',
        status: filesPass ? 'PASS' : 'FAIL',
        details: filesPass
            ? 'All required files present: ${requiredFiles.join(', ')}'
            : 'Missing files: ${missingFiles.join(', ')}',
        critical: true,
      ),
    );

    var locPass = true;
    var locWarning = false;
    final locDetails = <String>[];
    for (final file in input.filesCreated) {
      if (file.loc > AeCoreConfig.maxLoc) {
        locPass = false;
        locDetails.add(
          '${file.path}: ${file.loc} LOC (FAIL - should be <${AeCoreConfig.maxLoc})',
        );
      } else if (file.loc > AeCoreConfig.warningLoc) {
        locWarning = true;
        locDetails.add(
          '${file.path}: ${file.loc} LOC (WARNING - consider <${AeCoreConfig.warningLoc})',
        );
      } else {
        locDetails.add('${file.path}: ${file.loc} LOC (PASS - concise)');
      }
    }

    totalChecks += 1;
    if (locPass) {
      passCount += 1;
    }
    checks.add(
      EvaluateCheck(
        criterion: 'Documentation Conciseness',
        status:
            locPass ? (locWarning ? 'PASS (with warnings)' : 'PASS') : 'FAIL',
        details: locDetails.join('; '),
        critical: true,
      ),
    );

    final requiredSections = AeCoreConfig.getRequiredSections(input.action);
    final missingSections = requiredSections
        .where((final section) => !input.sectionsPresent.contains(section))
        .toList();
    final sectionsPass = missingSections.isEmpty;

    totalChecks += 1;
    if (sectionsPass) {
      passCount += 1;
    }
    checks.add(
      EvaluateCheck(
        criterion: 'Required Sections',
        status: sectionsPass ? 'PASS' : 'FAIL',
        details: sectionsPass
            ? 'All required sections present: ${requiredSections.join(', ')}'
            : 'Missing sections: ${missingSections.join(', ')}',
        critical: true,
      ),
    );

    if (AeCoreConfig.requiresValidation(input.action)) {
      totalChecks += 1;
      if (input.validationStepsExists) {
        passCount += 1;
      }
      checks.add(
        EvaluateCheck(
          criterion: 'Validation Steps',
          status: input.validationStepsExists ? 'PASS' : 'FAIL',
          details: input.validationStepsExists
              ? 'Validation steps are defined'
              : 'Validation steps are missing',
          critical: true,
        ),
      );
    }

    if (AeCoreConfig.requiresIntegration(input.action)) {
      totalChecks += 1;
      if (input.integrationPointsDefined) {
        passCount += 1;
      }
      checks.add(
        EvaluateCheck(
          criterion: 'Integration Points',
          status: input.integrationPointsDefined ? 'PASS' : 'FAIL',
          details: input.integrationPointsDefined
              ? 'Integration points are defined'
              : 'Integration points are missing',
          critical: true,
        ),
      );
    }

    if (AeCoreConfig.requiresReversibility(input.action)) {
      totalChecks += 1;
      if (input.reversibilityIncluded) {
        passCount += 1;
      }
      checks.add(
        EvaluateCheck(
          criterion: 'Reversibility',
          status: input.reversibilityIncluded ? 'PASS' : 'FAIL',
          details: input.reversibilityIncluded
              ? 'Reversibility procedures are included'
              : 'Reversibility procedures are missing',
          critical: true,
        ),
      );
    }

    if (AeCoreConfig.requiresMetaRules(input.action)) {
      totalChecks += 1;
      if (input.hasMetaRules) {
        passCount += 1;
      }
      checks.add(
        EvaluateCheck(
          criterion: 'Meta-rules',
          status: input.hasMetaRules ? 'PASS' : 'FAIL',
          details: input.hasMetaRules
              ? 'Meta-rules for agent guidance are present'
              : 'Meta-rules are missing',
          critical: true,
        ),
      );
    }

    final output = EvaluateOutput(
      overallPass: passCount == totalChecks,
      passCount: passCount,
      totalChecks: totalChecks,
      passRate:
          totalChecks == 0 ? 0 : ((passCount / totalChecks) * 100).round(),
      checks: checks,
      actionableFixes: _actionableFixes(checks),
    );

    return AeResult.ok(
      output,
      meta: {'overall_status': output.overallPass ? 'PASS' : 'FAIL'},
    );
  }

  ({List<VerifyCheck> checks, int passed, int total}) _verifyFileStructure(
    final VerifyInput input,
  ) {
    final checks = <VerifyCheck>[];
    var passed = 0;
    var total = 0;

    if (input.context == AeContext.library) {
      final expectedFiles = AeCoreConfig.getExpectedFiles(input.action);
      for (final expectedFile in expectedFiles) {
        final exists = input.filesModified.any(
          (final file) => file.path == expectedFile,
        );

        total += 1;
        if (exists) {
          passed += 1;
        }

        checks.add(
          VerifyCheck(
            item: 'Expected File: $expectedFile',
            key: 'file_$expectedFile',
            status: exists ? 'PASS' : 'FAIL',
            critical: true,
            details: exists
                ? 'File present in modifications'
                : 'Expected file not found in modifications',
          ),
        );
      }
    }

    for (final file in input.filesModified) {
      total += 1;
      if (file.loc > AeCoreConfig.maxLoc) {
        checks.add(
          VerifyCheck(
            item: 'LOC Check: ${file.path}',
            key: 'loc_${file.path}',
            status: 'FAIL',
            critical: true,
            details:
                '${file.loc} LOC exceeds maximum (${AeCoreConfig.maxLoc}). Documentation is too verbose.',
          ),
        );
      } else if (file.loc > AeCoreConfig.warningLoc) {
        passed += 1;
        checks.add(
          VerifyCheck(
            item: 'LOC Check: ${file.path}',
            key: 'loc_${file.path}',
            status: 'PASS (with warning)',
            critical: false,
            details:
                '${file.loc} LOC is acceptable but consider reducing below ${AeCoreConfig.warningLoc}.',
          ),
        );
      } else {
        passed += 1;
        checks.add(
          VerifyCheck(
            item: 'LOC Check: ${file.path}',
            key: 'loc_${file.path}',
            status: 'PASS',
            critical: false,
            details: '${file.loc} LOC is concise and agent-friendly.',
          ),
        );
      }
    }

    for (final file in input.filesModified) {
      if (file.sections.isEmpty) {
        continue;
      }

      final required = AeCoreConfig.getRequiredSectionsForFile(
        file.path,
        input.action,
      );
      if (required.isEmpty) {
        continue;
      }

      final missing = required
          .where((final section) => !file.sections.contains(section))
          .toList();

      total += 1;
      if (missing.isEmpty) {
        passed += 1;
        checks.add(
          VerifyCheck(
            item: 'Sections Check: ${file.path}',
            key: 'sections_${file.path}',
            status: 'PASS',
            critical: true,
            details: 'All required sections present',
          ),
        );
      } else {
        checks.add(
          VerifyCheck(
            item: 'Sections Check: ${file.path}',
            key: 'sections_${file.path}',
            status: 'FAIL',
            critical: true,
            details: 'Missing sections: ${missing.join(', ')}',
          ),
        );
      }
    }

    return (checks: checks, passed: passed, total: total);
  }

  List<String> _warningsForFiles(final List<AeModifiedFile> files) {
    return files
        .where(
          (final file) =>
              file.loc > AeCoreConfig.warningLoc &&
              file.loc <= AeCoreConfig.maxLoc,
        )
        .map(
          (final file) =>
              '${file.path}: Consider reducing from ${file.loc} to <${AeCoreConfig.warningLoc} LOC',
        )
        .toList(growable: false);
  }

  List<String> _actionableFixes(final List<EvaluateCheck> checks) {
    final fixes = <String>[];

    for (final check in checks) {
      if (check.status == 'PASS') {
        continue;
      }

      switch (check.criterion) {
        case 'Required Files':
          fixes.add('Create missing files: ${check.details}');
          break;
        case 'Documentation Conciseness':
          fixes.add(
            'Reduce documentation verbosity: ${check.details}. Focus on executable instructions.',
          );
          break;
        case 'Required Sections':
          fixes.add('Add missing sections: ${check.details}');
          break;
        case 'Validation Steps':
          fixes.add('Add validation steps to verify successful execution.');
          break;
        case 'Integration Points':
          fixes.add(
            'Define clear integration points with the existing codebase.',
          );
          break;
        case 'Reversibility':
          fixes.add('Add reversibility procedures to undo changes safely.');
          break;
        case 'Meta-rules':
          fixes.add(
            'Include meta-rules that guide agents in contextual decisions.',
          );
          break;
      }
    }

    if (fixes.isEmpty) {
      fixes.add('All checks passed. Implementation is compliant.');
    }

    return fixes;
  }
}
