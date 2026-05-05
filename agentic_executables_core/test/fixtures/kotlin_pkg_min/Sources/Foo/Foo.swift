/// A tiny opaque entity handle.
public struct Entity {
  public let id: UInt64
}

/// Allocator for monotonic Entity ids.
public class EntityManager {
  private var next: UInt64 = 0

  public init() {}

  public func create() -> Entity {
    let id = next
    next += 1
    return Entity(id: id)
  }
}

/// Marker protocol for systems that tick once per frame.
public protocol System {
  func tick()
}

private struct InternalCounter {
  var value: Int
}
