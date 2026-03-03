import 'types.dart';

class AeCreatedFile {
  const AeCreatedFile({required this.path, required this.loc});

  final String path;
  final int loc;

  factory AeCreatedFile.fromJson(final Map<String, dynamic> json) =>
      AeCreatedFile(
        path: (json['path'] ?? '').toString(),
        loc: json['loc'] is int
            ? json['loc'] as int
            : int.tryParse(json['loc']?.toString() ?? '') ?? 0,
      );

  Map<String, dynamic> toJson() => {'path': path, 'loc': loc};
}

class EvaluateInput {
  const EvaluateInput({
    required this.context,
    required this.action,
    this.filesCreated = const [],
    this.sectionsPresent = const [],
    this.validationStepsExists = false,
    this.integrationPointsDefined = false,
    this.reversibilityIncluded = false,
    this.hasMetaRules = false,
  });

  final AeContext context;
  final AeAction action;
  final List<AeCreatedFile> filesCreated;
  final List<String> sectionsPresent;
  final bool validationStepsExists;
  final bool integrationPointsDefined;
  final bool reversibilityIncluded;
  final bool hasMetaRules;
}

class EvaluateCheck {
  const EvaluateCheck({
    required this.criterion,
    required this.status,
    required this.details,
    required this.critical,
  });

  final String criterion;
  final String status;
  final String details;
  final bool critical;

  Map<String, dynamic> toJson() => {
        'criterion': criterion,
        'status': status,
        'details': details,
        'critical': critical,
      };
}

class EvaluateOutput {
  const EvaluateOutput({
    required this.overallPass,
    required this.passCount,
    required this.totalChecks,
    required this.passRate,
    required this.checks,
    required this.actionableFixes,
  });

  final bool overallPass;
  final int passCount;
  final int totalChecks;
  final int passRate;
  final List<EvaluateCheck> checks;
  final List<String> actionableFixes;

  Map<String, dynamic> toJson() => {
        'overall_pass': overallPass,
        'pass_count': passCount,
        'total_checks': totalChecks,
        'pass_rate': passRate,
        'checks': checks.map((final e) => e.toJson()).toList(growable: false),
        'actionable_fixes': actionableFixes,
      };
}
