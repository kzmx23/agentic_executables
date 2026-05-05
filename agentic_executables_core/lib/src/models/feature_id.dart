/// Stable, validated feature identifier with namespace support.
///
/// Format: lowercase letters, digits, underscores within segments;
/// dots separate namespace segments. The last segment is the name;
/// everything before is the namespace.
///
/// Examples: `entity.create`, `lights.spot.cone`, `swarm.flocking_movement`.
class FeatureId {
  const FeatureId._(this._raw, this.namespace, this.name);

  static final RegExp _segmentPattern = RegExp(r'^[a-z][a-z0-9_]*$');

  factory FeatureId.parse(final String value) {
    if (value.isEmpty) {
      throw ArgumentError('FeatureId cannot be empty');
    }
    final parts = value.split('.');
    if (parts.length < 2) {
      throw ArgumentError('FeatureId requires at least one dot: "$value"');
    }
    for (final part in parts) {
      if (!_segmentPattern.hasMatch(part)) {
        throw ArgumentError(
          'FeatureId segment "$part" is invalid (must match ${_segmentPattern.pattern})',
        );
      }
    }
    final ns = parts.sublist(0, parts.length - 1).join('.');
    final n = parts.last;
    return FeatureId._(value, ns, n);
  }

  final String _raw;
  final String namespace;
  final String name;

  @override
  String toString() => _raw;

  @override
  bool operator ==(final Object other) =>
      other is FeatureId && other._raw == _raw;

  @override
  int get hashCode => _raw.hashCode;
}
