//! Qdrant向量数据库实现
//! 使用最新的Qdrant Rust客户端

use super::VectorStore;
use async_trait::async_trait;
use uuid::Uuid;
use std::collections::HashMap;
use qdrant_client::{
    Qdrant,
    qdrant::{
        CreateCollectionBuilder, Distance, PointStruct, SearchPointsBuilder,
        VectorParamsBuilder, ScoredPoint,
    },
};
use serde_json::Value;

/// Qdrant存储实现
pub struct QdrantStore {
    client: Qdrant,
    collection_name: String,
    vector_size: usize,
}

impl std::fmt::Debug for QdrantStore {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("QdrantStore")
            .field("collection_name", &self.collection_name)
            .field("vector_size", &self.vector_size)
            .finish()
    }
}

#[derive(thiserror::Error, Debug)]
pub enum QdrantError {
    #[error("Qdrant客户端错误: {0}")]
    ClientError(String),
    #[error("集合操作失败: {0}")]
    CollectionError(String),
    #[error("搜索操作失败: {0}")]
    SearchError(String),
    #[error("JSON序列化错误: {0}")]
    JsonError(#[from] serde_json::Error),
}

impl QdrantStore {
    /// 创建新的Qdrant存储实例
    pub async fn new(
        url: &str,
        collection_name: String,
        vector_size: usize,
    ) -> Result<Self, anyhow::Error> {
        let client = Qdrant::from_url(url)
            .build()
            .map_err(|e| anyhow::anyhow!("Qdrant client error: {}", e))?;

        let store = Self {
            client,
            collection_name,
            vector_size,
        };

        // 确保集合存在
        store.ensure_collection_exists().await?;

        Ok(store)
    }

    /// 确保集合存在
    async fn ensure_collection_exists(&self) -> Result<(), anyhow::Error> {
        // 检查集合是否存在
        let collections = self.client.list_collections().await
            .map_err(|e| anyhow::anyhow!("Qdrant client error: {}", e))?;

        let collection_exists = collections.collections.iter()
            .any(|c| c.name == self.collection_name);

        if !collection_exists {
            // 创建集合
            let collection_config = CreateCollectionBuilder::new(&self.collection_name)
                .vectors_config(VectorParamsBuilder::new(
                    self.vector_size as u64,
                    Distance::Cosine
                ));

            self.client.create_collection(collection_config).await
                .map_err(|e| anyhow::anyhow!("Qdrant collection error: {}", e))?;
        }

        Ok(())
    }

    /// 将UUID转换为Qdrant点ID
    fn uuid_to_point_id(&self, uuid: Uuid) -> u64 {
        // 简单的UUID到u64的转换
        // 在生产环境中可能需要更好的映射策略
        let bytes = uuid.as_bytes();
        u64::from_be_bytes([
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
        ])
    }

    /// 将Qdrant点ID转换为UUID
    fn point_id_to_uuid(&self, point_id: u64) -> Uuid {
        let bytes = point_id.to_be_bytes();
        // 使用固定的后8字节创建UUID
        let uuid_bytes = [
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            0, 0, 0, 0, 0, 0, 0, 0,
        ];
        Uuid::from_bytes(uuid_bytes)
    }
}

#[async_trait]
impl VectorStore for QdrantStore {
    type Error = anyhow::Error;

    async fn store_vector(
        &self,
        id: Uuid,
        embedding: Vec<f32>,
        metadata: String,
    ) -> Result<(), Self::Error> {
        let point_id = self.uuid_to_point_id(id);
        
        // 解析metadata为JSON
        let metadata_json: Value = serde_json::from_str(&metadata)?;
        
        // 转换为HashMap
        let payload = if let Value::Object(map) = metadata_json {
            map.into_iter().map(|(k, v)| {
                let qdrant_value = match v {
                    Value::String(s) => qdrant_client::qdrant::Value {
                        kind: Some(qdrant_client::qdrant::value::Kind::StringValue(s)),
                    },
                    Value::Number(n) if n.is_f64() => qdrant_client::qdrant::Value {
                        kind: Some(qdrant_client::qdrant::value::Kind::DoubleValue(n.as_f64().unwrap())),
                    },
                    Value::Number(n) if n.is_i64() => qdrant_client::qdrant::Value {
                        kind: Some(qdrant_client::qdrant::value::Kind::IntegerValue(n.as_i64().unwrap())),
                    },
                    Value::Bool(b) => qdrant_client::qdrant::Value {
                        kind: Some(qdrant_client::qdrant::value::Kind::BoolValue(b)),
                    },
                    _ => qdrant_client::qdrant::Value {
                        kind: Some(qdrant_client::qdrant::value::Kind::StringValue(v.to_string())),
                    },
                };
                (k, qdrant_value)
            }).collect()
        } else {
            std::collections::HashMap::new()
        };
        
        let point = PointStruct::new(
            point_id,
            embedding,
            payload,
        );

        use qdrant_client::qdrant::UpsertPointsBuilder;
        
        let upsert_request = UpsertPointsBuilder::new(&self.collection_name, vec![point]);
        
        self.client.upsert_points(upsert_request).await
            .map_err(|e| anyhow::anyhow!("Qdrant client error: {}", e))?;

        Ok(())
    }

    async fn search_similar(
        &self,
        query_embedding: Vec<f32>,
        limit: usize,
        threshold: f32,
    ) -> Result<Vec<Uuid>, Self::Error> {
        let search_request = SearchPointsBuilder::new(
            &self.collection_name,
            query_embedding,
            limit as u64,
        ).score_threshold(threshold);

        let search_result = self.client.search_points(search_request).await
            .map_err(|e| anyhow::anyhow!("Qdrant search error: {}", e))?;

        let ids = search_result.result.into_iter()
            .map(|scored_point: ScoredPoint| {
                if let Some(point_id) = scored_point.id {
                    if let Some(num) = point_id.point_id_options {
                        match num {
                            qdrant_client::qdrant::point_id::PointIdOptions::Num(n) => {
                                self.point_id_to_uuid(n)
                            }
                            _ => Uuid::nil(), // 处理字符串ID的情况
                        }
                    } else {
                        Uuid::nil()
                    }
                } else {
                    Uuid::nil()
                }
            })
            .filter(|uuid| !uuid.is_nil())
            .collect();

        Ok(ids)
    }

    async fn delete_vector(&self, id: Uuid) -> Result<(), Self::Error> {
        let point_id = self.uuid_to_point_id(id);
        
        // 简化删除操作，直接使用点ID
        
        use qdrant_client::qdrant::DeletePointsBuilder;
        
        let delete_request = DeletePointsBuilder::new(&self.collection_name)
            .points(vec![qdrant_client::qdrant::PointId {
                point_id_options: Some(
                    qdrant_client::qdrant::point_id::PointIdOptions::Num(point_id)
                )
            }]);
        
        self.client.delete_points(delete_request).await
            .map_err(|e| anyhow::anyhow!("Qdrant client error: {}", e))?;

        Ok(())
    }

    async fn get_stats(&self) -> Result<HashMap<String, u64>, Self::Error> {
        let collection_info = self.client.collection_info(&self.collection_name).await
            .map_err(|e| anyhow::anyhow!("Qdrant client error: {}", e))?;

        let mut stats = HashMap::new();
        
        if let Some(result) = collection_info.result {
            stats.insert("points_count".to_string(), result.points_count.unwrap_or(0));
            stats.insert("vectors_count".to_string(), result.vectors_count.unwrap_or(0));
        }

        Ok(stats)
    }
}
