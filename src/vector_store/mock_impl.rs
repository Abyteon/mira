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

    /// 计算余弦相似度 - 优化版本，增加CPU密集型计算
    fn cosine_similarity(a: &[f32], b: &[f32]) -> f32 {
        if a.len() != b.len() {
            return 0.0;
        }

        // 使用rayon进行并行计算
        use rayon::prelude::*;
        
        // 并行计算点积
        let dot_product: f32 = a.par_iter()
            .zip(b.par_iter())
            .map(|(x, y)| x * y)
            .sum();
        
        // 并行计算向量范数
        let norm_a: f32 = a.par_iter()
            .map(|x| x * x)
            .sum::<f32>()
            .sqrt();
        
        let norm_b: f32 = b.par_iter()
            .map(|x| x * x)
            .sum::<f32>()
            .sqrt();

        if norm_a == 0.0 || norm_b == 0.0 {
            0.0
        } else {
            dot_product / (norm_a * norm_b)
        }
    }
    
    /// 高级向量运算 - 增加CPU密集型计算
    fn advanced_vector_operations(vectors: &[Vec<f32>]) -> Vec<f32> {
        use rayon::prelude::*;
        
        vectors.par_iter()
            .map(|vec| {
                // 进行复杂的向量运算
                let mut result = 0.0f32;
                
                // 计算多个统计量
                let mean = vec.iter().sum::<f32>() / vec.len() as f32;
                let variance = vec.iter()
                    .map(|x| (x - mean).powi(2))
                    .sum::<f32>() / vec.len() as f32;
                
                // 进行复杂的数学运算
                for i in 0..vec.len() {
                    let x = vec[i];
                    result += (x - mean).abs() * variance.sqrt() * (i as f32).sin();
                }
                
                result
            })
            .collect()
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
        
        // 使用rayon进行并行相似度计算
        use rayon::prelude::*;
        
        let mut similarities: Vec<(Uuid, f32)> = data.values()
            .collect::<Vec<_>>()
            .par_iter()
            .map(|vector_data| {
                let similarity = Self::cosine_similarity(&query_embedding, &vector_data.embedding);
                (vector_data.id, similarity)
            })
            .filter(|(_, similarity)| *similarity >= threshold)
            .collect();

        // 并行排序
        similarities.par_sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));

        // 进行额外的CPU密集型计算
        if !similarities.is_empty() {
            let vectors: Vec<Vec<f32>> = data.values()
                .map(|v| v.embedding.clone())
                .collect();
            
            // 执行高级向量运算
            let _advanced_results = Self::advanced_vector_operations(&vectors);
        }

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
