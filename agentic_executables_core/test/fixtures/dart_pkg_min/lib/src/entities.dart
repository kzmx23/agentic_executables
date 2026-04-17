/// An opaque, non-reusable entity handle.
class Entity {
  const Entity(this.id);
  final int id;
}

/// Creates entities with monotonic ids.
class EntityManager {
  int _next = 0;

  /// Allocate a new entity handle.
  Entity create() => Entity(_next++);

  /// Internal helper; not part of the public API.
  void _reset() => _next = 0;
}

/// Errors raised for invalid entity operations.
class EntityError extends Error {
  EntityError(this.message);
  final String message;
}
