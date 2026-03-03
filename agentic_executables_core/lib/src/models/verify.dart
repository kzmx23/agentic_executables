import 'types.dart';

class AeModifiedFile {
  const AeModifiedFile({
    required this.path,
    required this.loc,
    this.sections = const [],
  });

  final String path;
  final int loc;
  final List<String> sections;

  factory AeModifiedFile.fromJson(final Map<String, dynamic> json) =>
      AeModifiedFile(
        path: (json['path'] ?? '').toString(),
        loc: json['loc'] is int
            ? json['loc'] as int
            : int.tryParse(json['loc']?.toString() ?? '') ?? 0,
        sections: (json['sections'] is List)
            ? (json['sections'] as List)
                .map((final e) => e.toString())
                .toList(growable: false)
            : const [],
      );

  Map<String, dynamic> toJson() => {
        'path': path,
        'loc': loc,
        'sections': sections,
      };
}

class VerifyInput {
  const VerifyInput({
    required this.context,
    required this.action,
    this.filesModified = const [],
    this.checklistCompleted = const {},
  });

  final AeContext context;
  final AeAction action;
  final List<AeModifiedFile> filesModified;
  final Map<String, bool> checklistCompleted;
}

class VerifyCheck {
  const VerifyCheck({
    required this.item,
    required this.key,
    required this.status,
    required this.critical,
    required this.details,
  });

  final String item;
  final String key;
  final String status;
  final bool critical;
  final String details;

  Map<String, dynamic> toJson() => {
        'item': item,
        'key': key,
        'status': status,
        'critical': critical,
        'details': details,
      };
}

class VerifyOutput {
  const VerifyOutput({
    required this.overallPass,
    required this.passCount,
    required this.totalChecks,
    required this.passRate,
    required this.checks,
    required this.missingItems,
    required this.warnings,
  });

  final bool overallPass;
  final int passCount;
  final int totalChecks;
  final int passRate;
  final List<VerifyCheck> checks;
  final List<String> missingItems;
  final List<String> warnings;

  Map<String, dynamic> toJson() => {
        'overall_pass': overallPass,
        'pass_count': passCount,
        'total_checks': totalChecks,
        'pass_rate': passRate,
        'checks': checks.map((final e) => e.toJson()).toList(growable: false),
        'missing_items': missingItems,
        'warnings': warnings,
      };
}
