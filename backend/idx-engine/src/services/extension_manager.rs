use reqwest::Client;
use std::path::PathBuf;

pub struct ExtensionManager {
    client: Client,
    extensions_dir: PathBuf,
}

impl ExtensionManager {
    pub fn new(install_path: PathBuf) -> Self {
        Self {
            client: Client::new(),
            extensions_dir: install_path,
        }
    }
}
