use serde::{Deserialize, Serialize};
use std::io::{self, BufRead, Write};

#[derive(Serialize, Deserialize, Debug)]
pub struct JsonRpcRequest {
    pub jsonrpc: String,
    pub method: String,
    pub params: serde_json::Value,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub id: Option<u64>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct JsonRpcResponse {
    pub jsonrpc: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub result: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<JsonRpcError>,
    pub id: Option<u64>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct JsonRpcError {
    pub code: i32,
    pub message: String,
}

pub fn read_message() -> Option<JsonRpcRequest> {
    let stdin = io::stdin();
    let mut handle = stdin.lock();
    let mut line = String::new();

    match handle.read_line(&mut line) {
        Ok(0) => None, // EOF
        Ok(_) => {
            let line = line.trim();
            if line.is_empty() { return read_message(); }
            serde_json::from_str(line).ok()
        }
        Err(_) => None,
    }
}

pub fn send_response(id: Option<u64>, result: serde_json::Value) {
    if let Some(id) = id {
        let response = JsonRpcResponse {
            jsonrpc: "2.0".to_string(),
            result: Some(result),
            error: None,
            id: Some(id),
        };
        let json = serde_json::to_string(&response).unwrap();
        println!("{}", json);
    }
}

pub fn send_error(id: Option<u64>, code: i32, message: &str) {
    if let Some(id) = id {
        let response = JsonRpcResponse {
            jsonrpc: "2.0".to_string(),
            result: None,
            error: Some(JsonRpcError {
                code,
                message: message.to_string(),
            }),
            id: Some(id),
        };
        let json = serde_json::to_string(&response).unwrap();
        println!("{}", json);
    }
}

pub fn send_notification(method: &str, params: serde_json::Value) {
    let request = JsonRpcRequest {
        jsonrpc: "2.0".to_string(),
        method: method.to_string(),
        params,
        id: None,
    };
    let json = serde_json::to_string(&request).unwrap();
    println!("{}", json);
}
