/// Marker for systems that run each tick in declared order.
abstract class System {
  /// Advance one tick. The world calls this exactly once per frame.
  void tick();
}

/// A no-op system used as a default.
class NoopSystem implements System {
  const NoopSystem();
  @override
  void tick() {}
}

/// Ordered, monotonic tick runner.
typedef TickFn = void Function();
