//! Mock向量存储实现（用于测试）

use super::VectorStore;
use async_trait::async_trait;
use uuid::Uuid;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;

/// 存储的向量数据
#[derive(Debug, Clone)]
struct VectorData {
    id: Uuid,
    embedding: Vec<f32>,
    metadata: String,
}

/// Mock向量存储
#[derive(Debug)]
pub struct MockVectorStore {
    data: Arc<RwLock<HashMap<Uuid, VectorData>>>,
}

#[derive(thiserror::Error, Debug)]
pub enum MockError {
    #[error("向量未找到: {id}")]
    NotFound { id: Uuid },
    #[error("操作失败: {message}")]
    OperationFailed { message: String },
}

impl MockVectorStore {
    /// 创建新的Mock存储实例
    pub fn new() -> Self {
        Self {
            data: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    /// 计算余弦相似度
    fn cosine_similarity(a: &[f32], b: &[f32]) -> f32 {
        if a.len() != b.len() {
            return 0.0;
        }

        let dot_product: f32 = a.iter().zip(b.iter()).map(|(x, y)| x * y).sum();
        let norm_a: f32 = a.iter().map(|x| x * x).sum::<f32>().sqrt();
        let norm_b: f32 = b.iter().map(|x| x * x).sum::<f32>().sqrt();

        if norm_a == 0.0 || norm_b == 0.0 {
            0.0
        } else {
            dot_product / (norm_a * norm_b)
        }
    }
}

#[async_trait]
impl VectorStore for MockVectorStore {
    type Error = anyhow::Error;

    async fn store_vector(
        &self,
        id: Uuid,
        embedding: Vec<f32>,
        metadata: String,
    ) -> Result<(), Self::Error> {
        let vector_data = VectorData {
            id,
            embedding,
            metadata,
        };

        self.data.write().await.insert(id, vector_data);
        Ok(())
    }

    async fn search_similar(
        &self,
        query_embedding: Vec<f32>,
        limit: usize,
        threshold: f32,
    ) -> Result<Vec<Uuid>, Self::Error> {
        let data = self.data.read().await;
        
        let mut similarities: Vec<(Uuid, f32)> = data.values()
            .map(|vector_data| {
                let similarity = Self::cosine_similarity(&query_embedding, &vector_data.embedding);
                (vector_data.id, similarity)
            })
            .filter(|(_, similarity)| *similarity >= threshold)
            .collect();

        // 按相似度排序（降序）
        similarities.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));

        // 取前limit个结果
        let result = similarities.into_iter()
            .take(limit)
            .map(|(id, _)| id)
            .collect();

        Ok(result)
    }

    async fn delete_vector(&self, id: Uuid) -> Result<(), Self::Error> {
        let mut data = self.data.write().await;
        
        if data.remove(&id).is_some() {
            Ok(())
        } else {
            Err(anyhow::anyhow!("Vector not found: {}", id))
        }
    }

    async fn get_stats(&self) -> Result<HashMap<String, u64>, Self::Error> {
        let data = self.data.read().await;
        let mut stats = HashMap::new();
        
        stats.insert("total_vectors".to_string(), data.len() as u64);
        stats.insert("total_dimensions".to_string(), 
            data.values().next().map(|v| v.embedding.len() as u64).unwrap_or(0));

        Ok(stats)
    }
}

impl Default for MockVectorStore {
    fn default() -> Self {
        Self::new()
    }
}
