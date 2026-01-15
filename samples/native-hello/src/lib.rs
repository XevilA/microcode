// Basic Rust Wasm Extension Stub
#[no_mangle]
pub extern "C" fn activate() {
    // In real implementation, we'd call host functions to register
    // register_command("demo.hello", on_hello);
}

fn on_hello() {
    // show_message("Hello from WASM!");
}
