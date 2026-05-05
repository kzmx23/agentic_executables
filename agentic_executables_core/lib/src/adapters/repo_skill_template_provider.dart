import 'dart:io';

import 'package:path/path.dart' as path;

import '../ports/skill_template_provider.dart';

class RepoSkillTemplateProvider implements SkillTemplateProvider {
  RepoSkillTemplateProvider({
    required this.repoRoot,
    this.relativeTemplatePath = 'skills/ae-cli/SKILL.md',
  });

  final String repoRoot;
  final String relativeTemplatePath;

  @override
  Future<String> readTemplate() async {
    final file = File(path.join(repoRoot, relativeTemplatePath));
    if (!await file.exists()) {
      throw FileSystemException('Skill template not found', file.path);
    }
    return file.readAsString();
  }

  @override
  Future<String?> readVersion() async {
    final template = await readTemplate();
    final lines = template.split('\n');
    for (final line in lines) {
      final normalized = line.trim();
      if (normalized.startsWith('<!-- ae-cli-skill-version:')) {
        final value = normalized
            .replaceFirst('<!-- ae-cli-skill-version:', '')
            .replaceFirst('-->', '')
            .trim();
        if (value.isNotEmpty) {
          return value;
        }
      }
    }
    return null;
  }
}
