use axum::{Json, extract::State};
use std::sync::Arc;
use tokio::sync::RwLock;
use crate::state::AppState;
use super::{CompletionRequest, CompletionResponse};

pub async fn handle_completion(
    State(state): State<Arc<RwLock<AppState>>>,
    Json(req): Json<CompletionRequest>,
) -> Json<Result<CompletionResponse, String>> {
    let start_time = std::time::Instant::now();
    
    // Access AppState -> fast_tier
    let fast_tier_arc = {
        let st = state.read().await;
        st.fast_tier.clone()
    };
    
    let mut guard = fast_tier_arc.lock().await;
    
    if let Some(engine) = guard.as_mut() {
        match engine.complete(&req.context_before) {
            Ok(completion) => {
                let latency = start_time.elapsed().as_millis() as u64;
                Json(Ok(CompletionResponse {
                    completion,
                    latency_ms: latency,
                }))
            },
            Err(e) => Json(Err(e.to_string())),
        }
    } else {
        Json(Err("AI Engine not initialized yet. Downloading model...".to_string()))
    }
}
