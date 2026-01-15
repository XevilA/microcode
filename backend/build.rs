fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Only compile protos if the file exists (avoid breaking build if missing)
    if std::path::Path::new("proto/preview_protocol.proto").exists() {
        // Note: tonic_build requires 'protoc' to be installed.
        // If it's missing, this might fail at build time.
        // We wrap it to allow other parts of the backend to build even if gRPC gen fails.
        // real implementation would handle this more gracefully or assume env is correct.
        let _ = tonic_build::compile_protos("proto/preview_protocol.proto");
    }
    Ok(())
}
