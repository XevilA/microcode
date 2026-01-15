//! Hot Reload Engine - Xcode-like Dynamic Replacement System
//! 
//! This module implements:
//! - Thunk table for function pointer indirection
//! - Runtime swizzling for memory-level patching
//! - Preview agent for isolated rendering
//! - High-performance IPC (Unix sockets + shared memory)
//! - State preservation across reloads

pub mod thunk;
pub mod swizzle;
pub mod agent;
pub mod ipc;
pub mod state;

pub use thunk::ThunkTable;
pub use swizzle::Swizzler;
pub use agent::PreviewAgent;
pub use ipc::{IPCServer, IPCMessage};
pub use state::StateStorage;
