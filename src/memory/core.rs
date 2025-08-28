//! MIRA记忆系统核心实现  
//! My Intelligent Romantic Assistant - 使用最新的Rust并发特性和内存池优化

use crate::{MemoryEntry, MemoryType, MemorySystem, MemoryConfig, EmotionalState, Result, MemoryError};
use std::sync::Arc;
use tokio::sync::RwLock;
use dashmap::DashMap;

use uuid::Uuid;
use std::collections::HashMap;

impl MemorySystem {
    /// 创建新的记忆系统实例
    pub async fn new(
        user_id: String,
        vector_store: Arc<dyn crate::vector_store::VectorStore<Error = anyhow::Error>>,
        config: Option<MemoryConfig>,
    ) -> Result<Self> {
        let config = config.unwrap_or_default();
        
        Ok(Self {
            memory_cache: DashMap::new(),
            vector_store,
            current_emotion: Arc::new(RwLock::new(EmotionalState::default())),
            user_id,
            config,
        })
    }

    /// 添加新记忆 - 使用异步并发处理
    pub async fn add_memory(
        &self,
        memory_type: MemoryType,
        content: String,
        keywords: Vec<String>,
        importance: f32,
        emotional_context: Option<EmotionalState>,
    ) -> Result<Uuid> {
        let mut entry = MemoryEntry::new(memory_type.clone(), content.clone(), keywords, importance);
        entry.emotional_context = emotional_context;

        // 并发处理向量嵌入和重要性评估
        let (embedding, adjusted_importance) = tokio::join!(
            self.generate_embedding(&content),
            self.calculate_contextual_importance(&entry)
        );

        entry.embedding = embedding.ok();
        entry.importance = adjusted_importance;

        // 存储到向量数据库
        if let Some(ref embedding) = entry.embedding {
            self.vector_store.store_vector(
                entry.id,
                embedding.clone(),
                serde_json::to_string(&entry).unwrap(),
            ).await.map_err(|e| MemoryError::VectorStoreError { 
                message: e.to_string() 
            })?;
        }

        let memory_id = entry.id;
        
        // 存储到内存缓存
        self.memory_cache.insert(memory_id, entry);

        // 异步清理过期记忆
        if matches!(memory_type, MemoryType::ShortTerm) {
            tokio::spawn({
                let cache = self.memory_cache.clone();
                let limit = self.config.short_term_limit;
                async move {
                    Self::cleanup_short_term_memories(&cache, limit).await;
                }
            });
        }

        Ok(memory_id)
    }

    /// 检索相关记忆 - 使用向量相似度搜索
    pub async fn retrieve_memories(
        &self,
        query: &str,
        memory_types: Option<Vec<MemoryType>>,
        limit: Option<usize>,
    ) -> Result<Vec<MemoryEntry>> {
        let limit = limit.unwrap_or(10);
        
        // 生成查询向量
        let query_embedding = self.generate_embedding(query).await?;
        
        // 向量搜索
        let similar_ids = self.vector_store.search_similar(
            query_embedding,
            limit * 2, // 获取更多候选，后续过滤
            self.config.similarity_threshold,
        ).await.map_err(|e| MemoryError::VectorStoreError { 
            message: e.to_string() 
        })?;

        // 从缓存中获取记忆条目并过滤
        let mut memories = Vec::new();
        for id in similar_ids {
            if let Some(mut entry) = self.memory_cache.get_mut(&id) {
                // 检查类型过滤
                if let Some(ref types) = memory_types {
                    if !types.contains(&entry.memory_type) {
                        continue;
                    }
                }
                
                // 更新访问统计
                entry.mark_accessed();
                memories.push(entry.clone());
                
                if memories.len() >= limit {
                    break;
                }
            }
        }

        // 按重要性和时间排序
        memories.sort_by(|a, b| {
            let importance_cmp = b.importance.partial_cmp(&a.importance)
                .unwrap_or(std::cmp::Ordering::Equal);
            if importance_cmp == std::cmp::Ordering::Equal {
                b.last_accessed.cmp(&a.last_accessed)
            } else {
                importance_cmp
            }
        });

        Ok(memories)
    }

    /// 更新情感状态
    pub async fn update_emotional_state(&self, new_state: EmotionalState) {
        let mut current = self.current_emotion.write().await;
        *current = new_state;
    }

    /// 获取当前情感状态
    pub async fn get_emotional_state(&self) -> EmotionalState {
        self.current_emotion.read().await.clone()
    }

    /// 获取记忆统计信息
    pub async fn get_memory_stats(&self) -> HashMap<String, u64> {
        let mut stats = HashMap::new();
        
        for entry in self.memory_cache.iter() {
            let type_name = format!("{:?}", entry.memory_type);
            *stats.entry(type_name).or_insert(0) += 1;
        }
        
        stats.insert("total".to_string(), self.memory_cache.len() as u64);
        stats
    }

    /// 生成向量嵌入 - 优化版本，增加CPU密集型计算
    async fn generate_embedding(&self, text: &str) -> Result<Vec<f32>> {
        use rayon::prelude::*;
        
        // 复杂的文本特征提取
        let chars: Vec<char> = text.chars().collect();
        let embedding_size = 768;
        
        // 并行计算字符级别的特征 - 优化版本
        let char_features: Vec<f32> = chars.par_iter()
            .enumerate()
            .map(|(i, &ch)| {
                let mut feature = 0.0f32;
                
                // 适度的字符特征计算
                let char_code = ch as u32 as f32;
                feature += char_code * (i as f32).sin() * 0.001;
                feature += (char_code * (i as f32).cos()).sqrt() * 0.1;
                
                // 基于位置的权重
                let position_weight = 1.0 / (i + 1) as f32;
                feature *= position_weight;
                
                feature
            })
            .collect();
        
        // 生成完整的嵌入向量
        let mut embedding = vec![0.0f32; embedding_size];
        
        // 并行填充嵌入向量
        embedding.par_iter_mut()
            .enumerate()
            .for_each(|(i, val)| {
                let mut sum = 0.0f32;
                
                // 适度的向量生成算法
                for (j, &char_feature) in char_features.iter().enumerate() {
                    if j < 100 { // 限制计算量
                        let weight = ((i + j) as f32).sin() * char_feature;
                        sum += weight * (j as f32).sqrt() * 0.1;
                    }
                }
                
                // 添加随机性
                let random_factor = ((i * 7 + 13) % 100) as f32 * 0.01;
                *val = sum + random_factor;
            });
        
        // 向量归一化
        let norm: f32 = embedding.par_iter().map(|x| x * x).sum::<f32>().sqrt();
        if norm > 0.0 {
            embedding.par_iter_mut().for_each(|x| *x /= norm);
        }
        
        Ok(embedding)
    }

    /// 计算上下文重要性 - 优化版本，增加CPU密集型计算
    async fn calculate_contextual_importance(&self, entry: &MemoryEntry) -> f32 {
        use rayon::prelude::*;
        
        let mut importance = entry.importance;
        
        // 基于情感上下文调整重要性
        if let Some(ref emotion) = entry.emotional_context {
            // 复杂的情绪强度计算
            let emotional_factors = vec![
                emotion.happiness,
                emotion.affection,
                emotion.trust,
                emotion.dependency,
            ];
            
            // 并行计算情绪统计
            let emotional_intensity = emotional_factors.par_iter()
                .map(|&factor| {
                    let mut intensity = factor;
                    
                    // 复杂的情绪处理算法
                    for i in 0..100 {
                        intensity += (factor * i as f32).sin() * (i as f32).sqrt() * 0.001;
                    }
                    
                    intensity
                })
                .sum::<f32>() / emotional_factors.len() as f32;
            
            importance = (importance + emotional_intensity * 0.3).clamp(0.0, 1.0);
        }
        
        // 基于关键词的复杂重要性计算
        let keyword_importance: f32 = entry.keywords.par_iter()
            .map(|keyword| {
                let mut score = 0.0f32;
                
                // 复杂的词汇分析
                for (i, ch) in keyword.chars().enumerate() {
                    let char_value = ch as u32 as f32;
                    score += char_value * (i as f32).sin() * 0.001;
                    score += (char_value * (i as f32).cos()).sqrt() * 0.0001;
                }
                
                // 词汇长度权重
                score *= (keyword.len() as f32).sqrt();
                
                score
            })
            .sum();
        
        importance = (importance + keyword_importance * 0.1).clamp(0.0, 1.0);
        
        // 基于记忆类型调整
        match entry.memory_type {
            MemoryType::Emotional | MemoryType::Relationship => {
                importance = (importance + 0.2).clamp(0.0, 1.0);
            }
            MemoryType::ShortTerm => {
                importance = (importance - 0.1).clamp(0.0, 1.0);
            }
            _ => {}
        }
        
        // 最终的重要性优化
        let mut final_importance = importance;
        for i in 0..50 {
            final_importance += (importance * i as f32).sin() * 0.001;
        }
        
        final_importance.clamp(0.0, 1.0)
    }

    /// 清理短期记忆
    async fn cleanup_short_term_memories(cache: &DashMap<Uuid, MemoryEntry>, limit: usize) {
        let short_term_count = cache.iter()
            .filter(|entry| matches!(entry.memory_type, MemoryType::ShortTerm))
            .count();
            
        if short_term_count > limit {
            let mut short_term_entries: Vec<_> = cache.iter()
                .filter(|entry| matches!(entry.memory_type, MemoryType::ShortTerm))
                .map(|entry| (entry.key().clone(), entry.last_accessed, entry.importance))
                .collect();
                
            // 按访问时间和重要性排序，移除最老的和最不重要的
            short_term_entries.sort_by(|a, b| {
                let importance_cmp = a.2.partial_cmp(&b.2).unwrap_or(std::cmp::Ordering::Equal);
                if importance_cmp == std::cmp::Ordering::Equal {
                    a.1.cmp(&b.1)
                } else {
                    importance_cmp
                }
            });
            
            let to_remove = short_term_count - limit;
            for (id, _, _) in short_term_entries.iter().take(to_remove) {
                cache.remove(id);
            }
        }
    }

    /// 启动后台清理任务
    pub fn start_background_cleanup(&self) -> tokio::task::JoinHandle<()> {
        let cache = self.memory_cache.clone();
        let interval = self.config.cleanup_interval;
        let limit = self.config.short_term_limit;
        
        tokio::spawn(async move {
            let mut cleanup_interval = tokio::time::interval(
                tokio::time::Duration::from_secs(interval)
            );
            
            loop {
                cleanup_interval.tick().await;
                Self::cleanup_short_term_memories(&cache, limit).await;
            }
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::vector_store::MockVectorStore;

    #[tokio::test]
    async fn test_memory_system_creation() {
        let vector_store = Arc::new(MockVectorStore::new());
        let memory_system = MemorySystem::new(
            "test_user".to_string(),
            vector_store,
            None,
        ).await.unwrap();
        
        assert_eq!(memory_system.user_id, "test_user");
    }

    #[tokio::test]
    async fn test_add_and_retrieve_memory() {
        let vector_store = Arc::new(MockVectorStore::new());
        let memory_system = MemorySystem::new(
            "test_user".to_string(),
            vector_store,
            None,
        ).await.unwrap();
        
        let memory_id = memory_system.add_memory(
            MemoryType::LongTerm,
            "用户喜欢猫咪".to_string(),
            vec!["猫咪".to_string(), "喜欢".to_string()],
            0.8,
            None,
        ).await.unwrap();
        
        let memories = memory_system.retrieve_memories(
            "猫咪",
            Some(vec![MemoryType::LongTerm]),
            Some(5),
        ).await.unwrap();
        
        assert!(!memories.is_empty());
        assert_eq!(memories[0].id, memory_id);
    }
}
