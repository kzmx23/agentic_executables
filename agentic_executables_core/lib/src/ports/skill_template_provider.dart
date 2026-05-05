abstract interface class SkillTemplateProvider {
  Future<String> readTemplate();

  Future<String?> readVersion();
}
