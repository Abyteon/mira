//! 向量存储抽象层和实现

use async_trait::async_trait;
use uuid::Uuid;
use std::collections::HashMap;

/// 向量存储特征
#[async_trait]
pub trait VectorStore: std::fmt::Debug + Send + Sync {
    type Error: Send + Sync + 'static;

    /// 存储向量
    async fn store_vector(
        &self,
        id: Uuid,
        embedding: Vec<f32>,
        metadata: String,
    ) -> Result<(), Self::Error>;

    /// 搜索相似向量
    async fn search_similar(
        &self,
        query_embedding: Vec<f32>,
        limit: usize,
        threshold: f32,
    ) -> Result<Vec<Uuid>, Self::Error>;

    /// 删除向量
    async fn delete_vector(&self, id: Uuid) -> Result<(), Self::Error>;

    /// 获取向量统计信息
    async fn get_stats(&self) -> Result<HashMap<String, u64>, Self::Error>;
}

/// Qdrant实现
pub mod qdrant_impl;

/// Mock实现（用于测试）
pub mod mock_impl;

pub use qdrant_impl::QdrantStore;
pub use mock_impl::MockVectorStore;
