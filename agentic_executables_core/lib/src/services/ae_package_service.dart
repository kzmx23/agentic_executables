import '../models/ae_result.dart';

/// Inputs for [AePackageService.resolve].
///
/// Resolves Lythe-compatible package instructions for a given package id and
/// runtime target. The hub is intentionally not consulted; resolve is purely a
/// function of the input package metadata (so it can run in CI before any
/// `.ae_hub` exists).
class PackageResolveInput {
  const PackageResolveInput({
    required this.packageId,
    this.target = 'linux',
    this.format = 'json',
    this.packageRoot,
    this.version,
  });

  final String packageId;
  final String target;
  final String format;

  /// Filesystem path used to detect the package version when [version] is null.
  /// Falls back to the working directory if null at the call site.
  final String? packageRoot;

  /// Pinned version override; when null the service tries to detect from
  /// `pubspec.yaml` / `package.json` / `pyproject.toml` under [packageRoot].
  final String? version;
}

/// Inputs for [AePackageService.validate].
///
/// [instructions] is the already-decoded JSON object. Callers (CLI / MCP) own
/// the I/O for reading from a file path, stdin, or an inline JSON string.
class PackageValidateInput {
  const PackageValidateInput({required this.instructions});

  final Map<String, dynamic> instructions;
}

/// Resolve / validate Lythe-compatible package instructions
/// (`ae.v3.package.v1`). Spec §13 (`ae_package`).
abstract interface class AePackageService {
  Future<AeResult<Map<String, dynamic>>> resolve(
    final PackageResolveInput input,
  );

  Future<AeResult<Map<String, dynamic>>> validate(
    final PackageValidateInput input,
  );
}
