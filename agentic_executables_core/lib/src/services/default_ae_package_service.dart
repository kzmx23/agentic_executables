import 'dart:io';

import 'package:path/path.dart' as path;

import '../models/ae_result.dart';
import 'ae_package_service.dart';

/// Default implementation of [AePackageService].
///
/// Builds a deterministic `ae.v3.package.v1` instruction object from a package
/// id and detects the version from common manifest files when no version is
/// supplied. Validation enforces the same shape rules previously inlined in
/// the CLI's `ae package validate` handler.
class DefaultAePackageService implements AePackageService {
  const DefaultAePackageService();

  @override
  Future<AeResult<Map<String, dynamic>>> resolve(
    final PackageResolveInput input,
  ) async {
    final packageId = input.packageId.trim();
    if (packageId.isEmpty) {
      return AeResult.fail(
        code: 'validation_error',
        message: 'Missing required argument: --package',
      );
    }
    if (input.target != 'linux') {
      return AeResult.fail(
        code: 'validation_error',
        message:
            'Unsupported target "${input.target}"; only linux is supported',
      );
    }
    if (input.format != 'json') {
      return AeResult.fail(
        code: 'validation_error',
        message: 'Unsupported format "${input.format}"; only json is supported',
      );
    }

    final packageRoot =
        input.packageRoot != null && input.packageRoot!.isNotEmpty
            ? Directory(input.packageRoot!)
            : Directory.current;
    final detectedVersion =
        input.version ?? await detectPackageVersion(packageRoot) ?? '1.0.0';

    final slug = packageId
        .replaceAll(RegExp(r'[.:/]'), '-')
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');

    final instructions = <String, dynamic>{
      'contract_version': 'ae.v3.package.v1',
      'package': <String, dynamic>{
        'id': packageId,
        'version': detectedVersion,
      },
      'profile': <String, dynamic>{'id': 'direct', 'major': 1},
      'build': <String, dynamic>{
        'steps': <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'copy',
            'config': <String, dynamic>{'src': '.'},
          },
        ],
      },
      'deploy': <String, dynamic>{
        'plugins': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'systemd_service',
            'version': 1,
            'config': <String, dynamic>{
              'unit_name': 'lythe-$slug.service',
              'exec_start': 'payload/run-gateway.sh',
              'working_dir': 'payload',
              'environment_file': 'payload/gateway.env',
              'port': 8080,
            },
          },
        ],
        'inputs': <String, dynamic>{'required': const <String>[]},
      },
      'domain': <String, dynamic>{
        'capabilities': <String, dynamic>{'wildcard_support_mode': 'none'},
      },
      'safety': <String, dynamic>{
        'constraints': <String, dynamic>{
          'allowed_executors': const <String>['lythe'],
          'forbidden_actions': const <String>[],
        },
      },
    };

    final validationError = validatePackageInstructions(instructions);
    if (validationError != null) {
      return AeResult.fail(
        code: 'validation_error',
        message: validationError,
      );
    }

    return AeResult.ok(<String, dynamic>{
      'instructions': instructions,
      'package': packageId,
      'target': input.target,
      'format': input.format,
    });
  }

  @override
  Future<AeResult<Map<String, dynamic>>> validate(
    final PackageValidateInput input,
  ) async {
    final error = validatePackageInstructions(input.instructions);
    if (error != null) {
      return AeResult.fail(code: 'validation_error', message: error);
    }
    return AeResult.ok(<String, dynamic>{
      'validated': true,
      'contract_version': input.instructions['contract_version'],
    });
  }
}

/// Detect a package version by reading the first-found manifest under [cwd]:
/// pubspec.yaml, package.json, or pyproject.toml. Uses regex parsing — no
/// yaml/toml dependencies are required.
Future<String?> detectPackageVersion(final Directory cwd) async {
  for (final candidate in const [
    'pubspec.yaml',
    'package.json',
    'pyproject.toml',
  ]) {
    final file = File(path.join(cwd.path, candidate));
    if (!await file.exists()) {
      continue;
    }
    final raw = await file.readAsString();
    final match = switch (candidate) {
      'pubspec.yaml' =>
        RegExp(r'^version:\s*([^\s#]+)', multiLine: true).firstMatch(raw),
      'package.json' => RegExp(r'"version"\s*:\s*"([^"]+)"').firstMatch(raw),
      _ => RegExp(r'^version\s*=\s*"([^"]+)"', multiLine: true).firstMatch(raw),
    };
    final version = match?.group(1)?.trim();
    if (version != null && version.isNotEmpty) {
      return version;
    }
  }
  return null;
}

/// Validates a Lythe `ae.v3.package.v1` instruction payload. Returns the first
/// failing message or null when the payload is well-formed.
String? validatePackageInstructions(final Map<String, dynamic> payload) {
  const requiredTopLevel = <String>{
    'contract_version',
    'package',
    'profile',
    'build',
    'deploy',
    'domain',
    'safety',
  };
  for (final key in requiredTopLevel) {
    if (!payload.containsKey(key)) {
      return 'Missing required field: $key';
    }
  }

  if (payload['contract_version'] != 'ae.v3.package.v1') {
    return 'contract_version must equal ae.v3.package.v1';
  }
  final package = payload['package'];
  if (package is! Map ||
      !_nonEmptyString(package['id']) ||
      !_nonEmptyString(package['version'])) {
    return 'package.id and package.version are required';
  }
  final profile = payload['profile'];
  final profileMajor = profile is Map ? profile['major'] : null;
  if (profile is! Map ||
      !_nonEmptyString(profile['id']) ||
      profileMajor is! int ||
      profileMajor < 1) {
    return 'profile.id and profile.major are required';
  }
  final build = payload['build'];
  if (build is! Map ||
      build['steps'] is! List ||
      (build['steps'] as List).isEmpty) {
    return 'build.steps must contain at least one step';
  }
  final steps = build['steps'] as List;
  for (var i = 0; i < steps.length; i += 1) {
    final step = steps[i];
    if (step is! Map) {
      return 'build.steps[$i] must be an object';
    }
    if (!_nonEmptyString(step['type'])) {
      return 'build.steps[$i].type must be a non-empty string';
    }
    if (step['config'] is! Map) {
      return 'build.steps[$i].config must be an object';
    }
  }

  final deploy = payload['deploy'];
  if (deploy is! Map ||
      deploy['plugins'] is! List ||
      (deploy['plugins'] as List).isEmpty) {
    return 'deploy.plugins must contain at least one plugin';
  }
  if (deploy['inputs'] is! Map ||
      (deploy['inputs'] as Map)['required'] is! List) {
    return 'deploy.inputs.required must be present';
  }
  final plugins = deploy['plugins'] as List;
  for (var i = 0; i < plugins.length; i += 1) {
    final plugin = plugins[i];
    if (plugin is! Map) {
      return 'deploy.plugins[$i] must be an object';
    }
    if (!_nonEmptyString(plugin['name'])) {
      return 'deploy.plugins[$i].name must be a non-empty string';
    }
    final version = plugin['version'];
    if (version is! int || version < 1) {
      return 'deploy.plugins[$i].version must be an integer >= 1';
    }
    if (plugin['config'] is! Map) {
      return 'deploy.plugins[$i].config must be an object';
    }
  }
  final requiredInputs = (deploy['inputs'] as Map)['required'] as List;
  if (requiredInputs.any((final entry) => !_nonEmptyString(entry))) {
    return 'deploy.inputs.required must contain only non-empty strings';
  }

  final domain = payload['domain'];
  final capabilities = domain is Map ? domain['capabilities'] : null;
  final wildcard = capabilities is Map
      ? capabilities['wildcard_support_mode']?.toString()
      : null;
  const validWildcardModes = <String>{
    'none',
    'dns01_cloudflare',
    'dns01_route53',
    'dns01_any',
  };
  if (wildcard == null || !validWildcardModes.contains(wildcard)) {
    return 'domain.capabilities.wildcard_support_mode is invalid';
  }
  final safety = payload['safety'];
  final constraints = safety is Map ? safety['constraints'] : null;
  if (constraints is! Map) {
    return 'safety.constraints is required';
  }
  final allowedExecutors = constraints['allowed_executors'];
  if (allowedExecutors is! List || allowedExecutors.isEmpty) {
    return 'safety.constraints.allowed_executors must be a non-empty array';
  }
  if (allowedExecutors.any((final entry) => !_nonEmptyString(entry))) {
    return 'safety.constraints.allowed_executors must contain only non-empty strings';
  }
  if (allowedExecutors.any(
    (final entry) => entry != 'lythe' && entry != 'rust',
  )) {
    return 'safety.constraints.allowed_executors may contain only lythe or rust';
  }
  final forbiddenActions = constraints['forbidden_actions'];
  if (forbiddenActions is! List) {
    return 'safety.constraints.forbidden_actions must be an array';
  }
  for (final action in forbiddenActions) {
    if (!_nonEmptyString(action)) {
      return 'safety.constraints.forbidden_actions must contain only non-empty strings';
    }
    final value = action.toString().toLowerCase();
    if (value.contains('ssh') ||
        value.contains('shell') ||
        value.contains('remote_exec') ||
        value.contains('exec')) {
      return 'safety.constraints.forbidden_actions contains a forbidden runtime action';
    }
  }
  return null;
}

bool _nonEmptyString(final Object? value) =>
    value is String && value.trim().isNotEmpty;
