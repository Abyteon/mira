//! MIRA Python推理层桥接
//! My Intelligent Romantic Assistant - 调用Python的AI推理服务

use crate::{MemoryEntry, EmotionalState, Result, MemoryError};
use serde::{Deserialize, Serialize};
use tokio::process::Command as AsyncCommand;

/// Python推理请求
#[derive(Debug, Serialize)]
pub struct InferenceRequest {
    pub text: String,
    pub context: Option<Vec<MemoryEntry>>,
    pub emotional_state: Option<EmotionalState>,
    pub task_type: InferenceTaskType,
}

/// 推理任务类型
#[derive(Debug, Serialize)]
pub enum InferenceTaskType {
    GenerateEmbedding,
    GenerateResponse,
    AnalyzeEmotion,
    ExtractKeywords,
    CalculateImportance,
}

/// Python推理响应
#[derive(Debug, Deserialize)]
pub struct InferenceResponse {
    pub success: bool,
    pub result: serde_json::Value,
    pub error: Option<String>,
    pub processing_time_ms: u64,
}

/// Python推理客户端
#[derive(Debug)]
pub struct PythonInferenceClient {
    python_service_url: String,
    timeout_seconds: u64,
}

impl PythonInferenceClient {
    /// 创建新的Python推理客户端
    pub fn new(service_url: String, timeout_seconds: u64) -> Self {
        Self {
            python_service_url: service_url,
            timeout_seconds,
        }
    }

    /// 生成文本嵌入向量
    pub async fn generate_embedding(&self, text: &str) -> Result<Vec<f32>> {
        let request = InferenceRequest {
            text: text.to_string(),
            context: None,
            emotional_state: None,
            task_type: InferenceTaskType::GenerateEmbedding,
        };

        let response = self.call_python_service(request).await?;
        
        if response.success {
            let embedding: Vec<f32> = serde_json::from_value(response.result)
                .map_err(|e| MemoryError::SerializationError(e))?;
            Ok(embedding)
        } else {
            Err(MemoryError::DatabaseError(
                response.error.unwrap_or("Python推理服务错误".to_string())
            ))
        }
    }

    /// 生成情感化回复
    pub async fn generate_response(
        &self,
        user_input: &str,
        context: Vec<MemoryEntry>,
        emotional_state: EmotionalState,
    ) -> Result<String> {
        let request = InferenceRequest {
            text: user_input.to_string(),
            context: Some(context),
            emotional_state: Some(emotional_state),
            task_type: InferenceTaskType::GenerateResponse,
        };

        let response = self.call_python_service(request).await?;
        
        if response.success {
            let response_text: String = serde_json::from_value(response.result)
                .map_err(|e| MemoryError::SerializationError(e))?;
            Ok(response_text)
        } else {
            Err(MemoryError::DatabaseError(
                response.error.unwrap_or("回复生成失败".to_string())
            ))
        }
    }

    /// 分析用户情感
    pub async fn analyze_emotion(&self, text: &str) -> Result<EmotionalState> {
        let request = InferenceRequest {
            text: text.to_string(),
            context: None,
            emotional_state: None,
            task_type: InferenceTaskType::AnalyzeEmotion,
        };

        let response = self.call_python_service(request).await?;
        
        if response.success {
            let emotion: EmotionalState = serde_json::from_value(response.result)
                .map_err(|e| MemoryError::SerializationError(e))?;
            Ok(emotion)
        } else {
            Err(MemoryError::DatabaseError(
                response.error.unwrap_or("情感分析失败".to_string())
            ))
        }
    }

    /// 提取关键词
    pub async fn extract_keywords(&self, text: &str) -> Result<Vec<String>> {
        let request = InferenceRequest {
            text: text.to_string(),
            context: None,
            emotional_state: None,
            task_type: InferenceTaskType::ExtractKeywords,
        };

        let response = self.call_python_service(request).await?;
        
        if response.success {
            let keywords: Vec<String> = serde_json::from_value(response.result)
                .map_err(|e| MemoryError::SerializationError(e))?;
            Ok(keywords)
        } else {
            Err(MemoryError::DatabaseError(
                response.error.unwrap_or("关键词提取失败".to_string())
            ))
        }
    }

    /// 调用Python推理服务
    async fn call_python_service(&self, request: InferenceRequest) -> Result<InferenceResponse> {
        let client = reqwest::Client::new();
        let url = format!("{}/inference", self.python_service_url);
        
        let response = client
            .post(&url)
            .timeout(std::time::Duration::from_secs(self.timeout_seconds))
            .json(&request)
            .send()
            .await
            .map_err(|e| MemoryError::DatabaseError(format!("HTTP请求失败: {}", e)))?;

        let inference_response: InferenceResponse = response
            .json()
            .await
            .map_err(|e| MemoryError::DatabaseError(format!("响应解析失败: {}", e)))?;

        Ok(inference_response)
    }

    /// 启动Python推理服务
    pub async fn start_python_service(&self, script_path: &str) -> Result<()> {
        let _output = AsyncCommand::new("python3.14")  // 使用最新Python版本
            .arg(script_path)
            .arg("--port")
            .arg("8000")
            .arg("--host")
            .arg("127.0.0.1")
            .spawn()
            .map_err(|e| MemoryError::DatabaseError(format!("Python服务启动失败: {}", e)))?;

        // 等待服务启动
        tokio::time::sleep(tokio::time::Duration::from_secs(3)).await;
        
        Ok(())
    }

    /// 检查Python服务健康状态
    pub async fn health_check(&self) -> bool {
        let client = reqwest::Client::new();
        let url = format!("{}/health", self.python_service_url);
        
        if let Ok(response) = client.get(&url).send().await {
            response.status().is_success()
        } else {
            false
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_python_client_creation() {
        let client = PythonInferenceClient::new(
            "http://localhost:8000".to_string(),
            30,
        );
        
        assert_eq!(client.python_service_url, "http://localhost:8000");
        assert_eq!(client.timeout_seconds, 30);
    }
}
