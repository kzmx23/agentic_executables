//! Minimal ECS used as fixture content.

/// An opaque, non-reusable entity handle.
pub struct Entity(pub u64);

/// Allocator for monotonic Entity ids.
pub struct EntityManager {
    next: u64,
}

impl EntityManager {
    /// Make a new manager.
    pub fn new() -> Self {
        Self { next: 0 }
    }

    /// Allocate a new entity.
    pub fn create(&mut self) -> Entity {
        let id = self.next;
        self.next += 1;
        Entity(id)
    }

    fn _reset(&mut self) {
        self.next = 0;
    }
}

/// Marker trait for systems that tick once per frame.
pub trait System {
    fn tick(&mut self);
}

/// Possible errors when operating on entities.
pub enum EntityError {
    InvalidHandle,
}
