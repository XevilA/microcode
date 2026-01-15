//! Preview Agent - Manages hot reload cycle
//!
//! Responsible for:
//! - Loading dynamic libraries (dlopen)
//! - Swapping function implementations
//! - Rendering preview output
//! - State preservation

use super::state::StateStorage;
use super::thunk::THUNK_TABLE;
use std::collections::HashMap;
use std::ffi::{c_void, CStr, CString};
use std::os::raw::c_char;
use std::path::Path;

// FFI for dynamic loading (Unix)
#[cfg(unix)]
extern "C" {
    fn dlopen(filename: *const c_char, flags: i32) -> *mut c_void;
    fn dlsym(handle: *mut c_void, symbol: *const c_char) -> *mut c_void;
    fn dlclose(handle: *mut c_void) -> i32;
    fn dlerror() -> *const c_char;
}

#[cfg(unix)]
const RTLD_NOW: i32 = 0x2;
#[cfg(unix)]
const RTLD_LOCAL: i32 = 0x4;

/// Loaded module with version tracking
pub struct LoadedModule {
    /// Handle from dlopen
    handle: *mut c_void,
    /// Path to the dylib
    path: String,
    /// Version number
    version: u64,
    /// Symbols exported by this module
    symbols: Vec<String>,
    /// Timestamp of load
    loaded_at: std::time::Instant,
}

unsafe impl Send for LoadedModule {}
unsafe impl Sync for LoadedModule {}

impl LoadedModule {
    /// Get symbol address from this module
    pub unsafe fn get_symbol(&self, name: &str) -> Option<*mut c_void> {
        let cname = CString::new(name).ok()?;
        let ptr = dlsym(self.handle, cname.as_ptr());
        if ptr.is_null() {
            None
        } else {
            Some(ptr)
        }
    }
}

impl Drop for LoadedModule {
    fn drop(&mut self) {
        if !self.handle.is_null() {
            unsafe {
                dlclose(self.handle);
            }
        }
    }
}

/// The Preview Agent - core hot reload engine
pub struct PreviewAgent {
    /// Loaded modules (kept for cleanup)
    modules: Vec<LoadedModule>,
    /// Current version counter
    current_version: u64,
    /// State storage for preservation
    state_storage: StateStorage,
    /// Maximum modules to keep
    max_modules: usize,
}

impl PreviewAgent {
    pub fn new() -> Self {
        Self {
            modules: Vec::new(),
            current_version: 0,
            state_storage: StateStorage::new(),
            max_modules: 5,
        }
    }

    /// Hot reload a dynamic library
    ///
    /// # Safety
    /// Loads and executes code from the specified path.
    pub unsafe fn hot_reload(&mut self, dylib_path: &str) -> Result<ReloadResult, ReloadError> {
        let start_time = std::time::Instant::now();

        // 1. Verify file exists
        if !Path::new(dylib_path).exists() {
            return Err(ReloadError::FileNotFound(dylib_path.to_string()));
        }

        // 2. Capture current state
        self.state_storage.capture();

        // 3. Load the new library
        let path_cstr = CString::new(dylib_path).map_err(|_| ReloadError::InvalidPath)?;
        let handle = dlopen(path_cstr.as_ptr(), RTLD_NOW | RTLD_LOCAL);

        if handle.is_null() {
            let err = CStr::from_ptr(dlerror()).to_string_lossy().to_string();
            return Err(ReloadError::LoadFailed(err));
        }

        // 4. Look for manifest symbol
        let manifest = self.parse_manifest(handle);

        // 5. Swap registered functions
        let swapped_count = self.swap_functions(handle, &manifest)?;

        // 6. Restore state
        self.state_storage.restore();

        // 7. Track module
        self.current_version += 1;
        let module = LoadedModule {
            handle,
            path: dylib_path.to_string(),
            version: self.current_version,
            symbols: manifest.keys().cloned().collect(),
            loaded_at: std::time::Instant::now(),
        };
        self.modules.push(module);

        // 8. Cleanup old modules
        self.cleanup_old_modules();

        let load_time = start_time.elapsed();

        Ok(ReloadResult {
            success: true,
            version: self.current_version,
            swapped_functions: swapped_count,
            load_time_ms: load_time.as_millis() as u64,
        })
    }

    /// Parse the hot reload manifest from a module
    unsafe fn parse_manifest(&self, handle: *mut c_void) -> HashMap<String, String> {
        let mut manifest = HashMap::new();

        // Look for __hot_reload_manifest
        let manifest_sym = CString::new("__hot_reload_manifest").unwrap();
        let manifest_ptr = dlsym(handle, manifest_sym.as_ptr());

        if manifest_ptr.is_null() {
            // No manifest - try to find functions with known pattern
            // Look for functions starting with "_preview_" or "_hot_"
            return manifest;
        }

        // Manifest format: null-terminated list of "old_name\0new_name\0"
        let mut ptr = manifest_ptr as *const c_char;
        loop {
            if *ptr == 0 {
                break;
            }

            let old_name = CStr::from_ptr(ptr).to_string_lossy().to_string();
            ptr = ptr.add(old_name.len() + 1);

            if *ptr == 0 {
                break;
            }

            let new_name = CStr::from_ptr(ptr).to_string_lossy().to_string();
            ptr = ptr.add(new_name.len() + 1);

            manifest.insert(old_name, new_name);
        }

        manifest
    }

    /// Swap functions according to manifest
    unsafe fn swap_functions(
        &self,
        handle: *mut c_void,
        manifest: &HashMap<String, String>,
    ) -> Result<usize, ReloadError> {
        let mut swapped = 0;

        for (old_name, new_name) in manifest {
            // Get new function address
            let new_sym = CString::new(new_name.as_str()).unwrap();
            let new_fn = dlsym(handle, new_sym.as_ptr());

            if new_fn.is_null() {
                continue;
            }

            // Swap in thunk table
            if let Ok(mut table) = THUNK_TABLE.write() {
                if (*table).swap(old_name, new_fn as *const c_void).is_some() {
                    swapped += 1;
                }
            }
        }

        Ok(swapped)
    }

    /// Cleanup old modules, keeping most recent N
    fn cleanup_old_modules(&mut self) {
        while self.modules.len() > self.max_modules {
            // Remove oldest (first)
            self.modules.remove(0);
        }
    }

    /// Rollback to previous version
    pub fn rollback(&mut self) -> Result<(), ReloadError> {
        if self.modules.len() < 2 {
            return Err(ReloadError::NoPreviousVersion);
        }

        // Remove current
        self.modules.pop();

        // Restore from previous module
        if let Some(prev) = self.modules.last() {
            // Re-swap from previous module manifest
            // (simplified - in practice we'd store the manifest)
            self.current_version = prev.version;
        }

        Ok(())
    }

    /// Get current version
    pub fn version(&self) -> u64 {
        self.current_version
    }

    /// Get loaded module count
    pub fn module_count(&self) -> usize {
        self.modules.len()
    }
}

/// Result of a hot reload operation
#[derive(Debug, Clone)]
pub struct ReloadResult {
    pub success: bool,
    pub version: u64,
    pub swapped_functions: usize,
    pub load_time_ms: u64,
}

/// Hot reload errors
#[derive(Debug, Clone)]
pub enum ReloadError {
    FileNotFound(String),
    InvalidPath,
    LoadFailed(String),
    SwapFailed(String),
    NoPreviousVersion,
}

impl std::fmt::Display for ReloadError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ReloadError::FileNotFound(p) => write!(f, "File not found: {}", p),
            ReloadError::InvalidPath => write!(f, "Invalid path encoding"),
            ReloadError::LoadFailed(e) => write!(f, "dlopen failed: {}", e),
            ReloadError::SwapFailed(e) => write!(f, "Function swap failed: {}", e),
            ReloadError::NoPreviousVersion => write!(f, "No previous version to rollback to"),
        }
    }
}

impl std::error::Error for ReloadError {}
