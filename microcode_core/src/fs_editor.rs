//! File Editor Module - The Tools of MicroCode
//!
//! Provides safe file editing with search-and-replace block logic.
//! Validates that search blocks are unique before replacement.

use std::fs;
use std::path::{Path, PathBuf};

use crate::{CoreError, EditResult};

/// File editor for safe code modifications
pub struct FileEditor {
    workspace: PathBuf,
}

impl FileEditor {
    /// Create a new file editor
    pub fn new(workspace: PathBuf) -> Self {
        Self { workspace }
    }

    /// Apply a search-and-replace edit to a file
    ///
    /// # Arguments
    /// * `file_path` - Absolute or relative path to the file
    /// * `search_block` - Exact text to find (must be unique in file)
    /// * `replace_block` - Text to replace with
    ///
    /// # Safety
    /// Returns error if search_block appears more than once (ambiguous edit)
    pub fn apply_edit(
        &self,
        file_path: &str,
        search_block: &str,
        replace_block: &str,
    ) -> Result<EditResult, CoreError> {
        let path = self.resolve_path(file_path);

        // Read file contents
        let content = fs::read_to_string(&path).map_err(|e| CoreError::Io {
            msg: format!("Failed to read {}: {}", file_path, e),
        })?;

        // Validate: search block must exist
        if !content.contains(search_block) {
            return Err(CoreError::EditValidation {
                msg: format!("Search block not found in file: {}", file_path),
            });
        }

        // Validate: search block must be unique
        let occurrences = content.matches(search_block).count();
        if occurrences > 1 {
            return Err(CoreError::EditValidation {
                msg: format!(
                    "Search block appears {} times in {}. Must be unique for safe replacement.",
                    occurrences, file_path
                ),
            });
        }

        // Perform replacement
        let new_content = content.replacen(search_block, replace_block, 1);

        // Write back
        fs::write(&path, &new_content).map_err(|e| CoreError::Io {
            msg: format!("Failed to write {}: {}", file_path, e),
        })?;

        Ok(EditResult {
            success: true,
            message: format!("Successfully edited {}", file_path),
            replacements: 1,
        })
    }

    /// Read file contents
    pub fn read_file(&self, file_path: &str) -> Result<String, CoreError> {
        let path = self.resolve_path(file_path);

        fs::read_to_string(&path).map_err(|e| CoreError::Io {
            msg: format!("Failed to read {}: {}", file_path, e),
        })
    }

    /// Write file contents (creates parent directories if needed)
    pub fn write_file(&self, file_path: &str, content: &str) -> Result<(), CoreError> {
        let path = self.resolve_path(file_path);

        // Create parent directories if needed
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).map_err(|e| CoreError::Io {
                msg: format!("Failed to create directories: {}", e),
            })?;
        }

        fs::write(&path, content).map_err(|e| CoreError::Io {
            msg: format!("Failed to write {}: {}", file_path, e),
        })
    }

    /// Resolve path (relative to workspace or absolute)
    fn resolve_path(&self, file_path: &str) -> PathBuf {
        let path = Path::new(file_path);
        if path.is_absolute() {
            path.to_path_buf()
        } else {
            self.workspace.join(path)
        }
    }
}
