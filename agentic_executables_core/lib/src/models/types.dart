enum AeContext {
  library('library'),
  project('project');

  const AeContext(this.value);

  final String value;

  static AeContext fromString(final String value) {
    switch (value.toLowerCase()) {
      case 'library':
        return AeContext.library;
      case 'project':
        return AeContext.project;
      default:
        throw ArgumentError('Invalid context_type: $value');
    }
  }

  static List<String> get validValues =>
      AeContext.values.map((final e) => e.value).toList(growable: false);

  @override
  String toString() => value;
}

enum AeAction {
  bootstrap('bootstrap'),
  install('install'),
  uninstall('uninstall'),
  update('update'),
  use('use');

  const AeAction(this.value);

  final String value;

  static AeAction fromString(final String value) {
    switch (value.toLowerCase()) {
      case 'bootstrap':
        return AeAction.bootstrap;
      case 'install':
        return AeAction.install;
      case 'uninstall':
        return AeAction.uninstall;
      case 'update':
        return AeAction.update;
      case 'use':
        return AeAction.use;
      default:
        throw ArgumentError('Invalid action: $value');
    }
  }

  static List<String> get validValues =>
      AeAction.values.map((final e) => e.value).toList(growable: false);

  static List<String> get registryActions => [
        AeAction.install,
        AeAction.uninstall,
        AeAction.update,
        AeAction.use,
      ].map((final e) => e.value).toList(growable: false);

  bool get isRegistryAction => this != AeAction.bootstrap;

  String get fileName {
    switch (this) {
      case AeAction.bootstrap:
        return 'ae_bootstrap.md';
      case AeAction.install:
        return 'ae_install.md';
      case AeAction.uninstall:
        return 'ae_uninstall.md';
      case AeAction.update:
        return 'ae_update.md';
      case AeAction.use:
        return 'ae_use.md';
    }
  }

  @override
  String toString() => value;
}

enum AeRegistryOperation {
  submitToRegistry('submit_to_registry'),
  getFromRegistry('get_from_registry'),
  bootstrapLocalRegistry('bootstrap_local_registry');

  const AeRegistryOperation(this.value);

  final String value;

  static AeRegistryOperation fromString(final String value) {
    switch (value.toLowerCase()) {
      case 'submit_to_registry':
        return AeRegistryOperation.submitToRegistry;
      case 'get_from_registry':
        return AeRegistryOperation.getFromRegistry;
      case 'bootstrap_local_registry':
        return AeRegistryOperation.bootstrapLocalRegistry;
      default:
        throw ArgumentError('Invalid operation: $value');
    }
  }

  static List<String> get validValues => AeRegistryOperation.values
      .map((final e) => e.value)
      .toList(growable: false);

  @override
  String toString() => value;
}

enum AeGenerationEngineMode {
  auto('auto'),
  codex('codex'),
  template('template');

  const AeGenerationEngineMode(this.value);

  final String value;

  static AeGenerationEngineMode fromString(final String value) {
    switch (value.toLowerCase()) {
      case 'auto':
        return AeGenerationEngineMode.auto;
      case 'codex':
        return AeGenerationEngineMode.codex;
      case 'template':
        return AeGenerationEngineMode.template;
      default:
        throw ArgumentError('Invalid generation engine mode: $value');
    }
  }

  static List<String> get validValues => AeGenerationEngineMode.values
      .map((final e) => e.value)
      .toList(growable: false);

  @override
  String toString() => value;
}

class AeContextAction {
  AeContextAction(this.context, this.action) {
    if (action == AeAction.bootstrap && context != AeContext.library) {
      throw ArgumentError('Bootstrap action is only valid for library context');
    }
  }

  final AeContext context;
  final AeAction action;

  List<String> getDocumentFiles() {
    switch (context) {
      case AeContext.library:
        if (action == AeAction.bootstrap) {
          return ['ae_context.md', 'ae_bootstrap.md'];
        }
        return ['ae_context.md', 'ae_use.md'];
      case AeContext.project:
        return ['ae_context.md', 'ae_use.md'];
    }
  }
}
