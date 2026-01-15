mod ipc;
mod wasm;

use ipc::{read_message, send_response, send_error, send_notification};
use serde_json::json;
use log::{info, error};

fn main() {
    env_logger::init();
    info!("MicroCode Extension Host Starting...");

    loop {
        match read_message() {
            Some(req) => {
                handle_request(req);
            }
            None => {
                info!("Stdin closed, exiting.");
                break;
            }
        }
    }
}

fn handle_request(req: ipc::JsonRpcRequest) {
    match req.method.as_str() {
        "ext/load" => {
            // TODO: Load WASM or prepare compat
            info!("Loading extension: {:?}", req.params);
            send_response(req.id, json!({ "status": "loaded" }));
        }
        "command/execute" => {
            info!("Executing command: {:?}", req.params);
            send_response(req.id, json!(null));
        }
        _ => {
            send_error(req.id, -32601, "Method not found");
        }
    }
}
