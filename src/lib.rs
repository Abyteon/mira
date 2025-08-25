//! MIRA记忆系统 - 多语言混合架构
//! My Intelligent Romantic Assistant - 使用最新的Rust 1.82.0特性实现高性能记忆管理

use std::collections::HashMap;
use std::sync::Arc;
use chrono::{DateTime, Utc};
use dashmap::DashMap;
use serde::{Deserialize, Serialize};
use tokio::sync::RwLock;
use uuid::Uuid;

pub mod memory;
pub mod emotion;
pub mod vector_store;
pub mod bridge;

/// 记忆类型枚举
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum MemoryType {
    /// 短期记忆 - 当前对话上下文
    ShortTerm,
    /// 长期记忆 - 重要事件和信息
    LongTerm, 
    /// 情感记忆 - 情感互动历史
    Emotional,
    /// 偏好记忆 - 用户喜好和习惯
    Preference,
    /// 关系记忆 - 关系发展历程
    Relationship,
}

/// 情感状态
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EmotionalState {
    pub happiness: f32,      // 开心程度 0.0-1.0
    pub affection: f32,      // 亲密程度 0.0-1.0
    pub trust: f32,          // 信任程度 0.0-1.0
    pub dependency: f32,     // 依赖程度 0.0-1.0
    pub mood: String,        // 当前心情描述
    pub timestamp: DateTime<Utc>,
}

/// 记忆条目
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MemoryEntry {
    pub id: Uuid,
    pub memory_type: MemoryType,
    pub content: String,
    pub keywords: Vec<String>,
    pub embedding: Option<Vec<f32>>,  // 向量嵌入
    pub emotional_context: Option<EmotionalState>,
    pub importance: f32,     // 重要性评分 0.0-1.0
    pub created_at: DateTime<Utc>,
    pub last_accessed: DateTime<Utc>,
    pub access_count: u32,
    pub metadata: HashMap<String, String>,
}

/// 记忆系统核心结构
#[derive(Debug)]
pub struct MemorySystem {
    /// 内存中的记忆缓存 - 使用DashMap实现并发安全
    memory_cache: DashMap<Uuid, MemoryEntry>,
    /// 向量存储客户端
    vector_store: Arc<dyn vector_store::VectorStore<Error = anyhow::Error>>,
    /// 当前情感状态
    current_emotion: Arc<RwLock<EmotionalState>>,
    /// 用户ID
    user_id: String,
    /// 配置
    config: MemoryConfig,
}

/// 记忆系统配置
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MemoryConfig {
    /// 短期记忆最大条数
    pub short_term_limit: usize,
    /// 长期记忆重要性阈值
    pub long_term_threshold: f32,
    /// 向量相似度阈值
    pub similarity_threshold: f32,
    /// 记忆清理间隔(秒)
    pub cleanup_interval: u64,
}

impl Default for MemoryConfig {
    fn default() -> Self {
        Self {
            short_term_limit: 100,
            long_term_threshold: 0.7,
            similarity_threshold: 0.8,
            cleanup_interval: 3600,
        }
    }
}

impl Default for EmotionalState {
    fn default() -> Self {
        Self {
            happiness: 0.5,
            affection: 0.3,
            trust: 0.3,
            dependency: 0.2,
            mood: "平静".to_string(),
            timestamp: Utc::now(),
        }
    }
}

impl MemoryEntry {
    pub fn new(
        memory_type: MemoryType,
        content: String,
        keywords: Vec<String>,
        importance: f32,
    ) -> Self {
        Self {
            id: Uuid::new_v4(),
            memory_type,
            content,
            keywords,
            embedding: None,
            emotional_context: None,
            importance: importance.clamp(0.0, 1.0),
            created_at: Utc::now(),
            last_accessed: Utc::now(),
            access_count: 0,
            metadata: HashMap::new(),
        }
    }

    /// 标记为已访问
    pub fn mark_accessed(&mut self) {
        self.last_accessed = Utc::now();
        self.access_count += 1;
    }

    /// 更新重要性评分
    pub fn update_importance(&mut self, delta: f32) {
        self.importance = (self.importance + delta).clamp(0.0, 1.0);
    }
}

/// Python绑定模块
#[cfg(feature = "python-bindings")]
pub mod python_bindings {
    use pyo3::prelude::*;
    use super::*;

    #[pyclass]
    #[derive(Clone)]
    pub struct PyMemoryEntry {
        #[pyo3(get, set)]
        pub content: String,
        #[pyo3(get, set)]
        pub importance: f32,
        #[pyo3(get, set)]
        pub keywords: Vec<String>,
    }

    #[pymethods]
    impl PyMemoryEntry {
        #[new]
        pub fn new(content: String, importance: f32, keywords: Vec<String>) -> Self {
            Self { content, importance, keywords }
        }
    }

    #[pyfunction]
    pub fn create_memory_entry(content: String, importance: f32) -> PyResult<PyMemoryEntry> {
        Ok(PyMemoryEntry::new(content, importance, vec![]))
    }

    #[pymodule]
    fn ai_girlfriend_memory(_py: Python, m: &PyModule) -> PyResult<()> {
        m.add_class::<PyMemoryEntry>()?;
        m.add_function(wrap_pyfunction!(create_memory_entry, m)?)?;
        Ok(())
    }
}

/// 错误类型定义
#[derive(thiserror::Error, Debug)]
pub enum MemoryError {
    #[error("记忆条目未找到: {id}")]
    NotFound { id: Uuid },
    #[error("向量存储错误: {message}")]
    VectorStoreError { message: String },
    #[error("序列化错误: {0}")]
    SerializationError(#[from] serde_json::Error),
    #[error("数据库错误: {0}")]
    DatabaseError(String),
}

pub type Result<T> = std::result::Result<T, MemoryError>;
