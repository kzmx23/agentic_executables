import 'dart:io';

import 'package:agentic_executables_core/agentic_executables_core.dart';

import 'embedded_cli_resources.dart';

class EmbeddedSkillTemplateProvider implements SkillTemplateProvider {
  const EmbeddedSkillTemplateProvider();

  @override
  Future<String> readTemplate() async => EmbeddedCliResources.skillTemplate;

  @override
  Future<String?> readVersion() async => EmbeddedCliResources.skillVersion;
}

class FileSkillTemplateProvider implements SkillTemplateProvider {
  const FileSkillTemplateProvider(this.templatePath);

  final String templatePath;

  @override
  Future<String> readTemplate() async {
    final file = File(templatePath);
    if (!await file.exists()) {
      throw FileSystemException('Skill template not found', templatePath);
    }
    return file.readAsString();
  }

  @override
  Future<String?> readVersion() async {
    final template = await readTemplate();
    for (final line in template.split('\n')) {
      final normalized = line.trim();
      if (!normalized.startsWith('<!-- ae-cli-skill-version:')) {
        continue;
      }
      final value = normalized
          .replaceFirst('<!-- ae-cli-skill-version:', '')
          .replaceFirst('-->', '')
          .trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }
}
