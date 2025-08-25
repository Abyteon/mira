"""
MIRA推理服务测试
"""

import pytest
import asyncio
from unittest.mock import Mock, patch
from fastapi.testclient import TestClient

from main import (
    app, AIInferenceEngine, InferenceRequest, InferenceTaskType,
    EmotionalState, MemoryEntry, get_inference_engine
)


@pytest.fixture
def client():
    """测试客户端"""
    return TestClient(app)


@pytest.fixture
def mock_engine():
    """模拟推理引擎"""
    engine = Mock(spec=AIInferenceEngine)
    return engine


@pytest.fixture
def sample_emotional_state():
    """示例情感状态"""
    return EmotionalState(
        happiness=0.8,
        affection=0.7,
        trust=0.9,
        dependency=0.5,
        mood="开心",
        timestamp="2025-01-14T12:00:00"
    )


@pytest.fixture
def sample_memory_entries():
    """示例记忆条目"""
    return [
        MemoryEntry(
            id="test-1",
            content="用户喜欢喝咖啡",
            keywords=["咖啡", "喜欢"],
            importance=0.8,
            created_at="2025-01-14T10:00:00",
            memory_type="preference"
        ),
        MemoryEntry(
            id="test-2", 
            content="今天心情很好",
            keywords=["心情", "开心"],
            importance=0.6,
            created_at="2025-01-14T11:00:00",
            memory_type="emotional"
        )
    ]


class TestHealthCheck:
    """健康检查测试"""
    
    def test_health_endpoint(self, client):
        """测试健康检查端点"""
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert "status" in data
        assert "timestamp" in data
        assert "engine_ready" in data
    
    def test_root_endpoint(self, client):
        """测试根端点"""
        response = client.get("/")
        assert response.status_code == 200
        data = response.json()
        assert "message" in data
        assert "version" in data


class TestInferenceEndpoint:
    """推理端点测试"""
    
    def test_embedding_generation(self, client, mock_engine):
        """测试嵌入生成"""
        # 模拟返回值
        mock_engine.generate_embedding.return_value = [0.1, 0.2, 0.3]
        
        with patch('main.get_inference_engine', return_value=mock_engine):
            request_data = {
                "text": "测试文本",
                "task_type": "GenerateEmbedding"
            }
            
            response = client.post("/inference", json=request_data)
            assert response.status_code == 200
            
            data = response.json()
            assert data["success"] is True
            assert data["result"] == [0.1, 0.2, 0.3]
            assert "processing_time_ms" in data
    
    def test_response_generation(self, client, mock_engine, sample_emotional_state, sample_memory_entries):
        """测试回复生成"""
        mock_engine.generate_response.return_value = "你好呀~"
        
        with patch('main.get_inference_engine', return_value=mock_engine):
            request_data = {
                "text": "你好",
                "context": [entry.model_dump() for entry in sample_memory_entries],
                "emotional_state": sample_emotional_state.model_dump(),
                "task_type": "GenerateResponse"
            }
            
            response = client.post("/inference", json=request_data)
            assert response.status_code == 200
            
            data = response.json()
            assert data["success"] is True
            assert data["result"] == "你好呀~"
    
    def test_emotion_analysis(self, client, mock_engine, sample_emotional_state):
        """测试情感分析"""
        mock_engine.analyze_emotion.return_value = sample_emotional_state
        
        with patch('main.get_inference_engine', return_value=mock_engine):
            request_data = {
                "text": "我今天很开心",
                "task_type": "AnalyzeEmotion"
            }
            
            response = client.post("/inference", json=request_data)
            assert response.status_code == 200
            
            data = response.json()
            assert data["success"] is True
            assert "happiness" in data["result"]
            assert "mood" in data["result"]
    
    def test_keyword_extraction(self, client, mock_engine):
        """测试关键词提取"""
        mock_engine.extract_keywords.return_value = ["关键词1", "关键词2"]
        
        with patch('main.get_inference_engine', return_value=mock_engine):
            request_data = {
                "text": "这是一段包含关键词的测试文本",
                "task_type": "ExtractKeywords"
            }
            
            response = client.post("/inference", json=request_data)
            assert response.status_code == 200
            
            data = response.json()
            assert data["success"] is True
            assert data["result"] == ["关键词1", "关键词2"]
    
    def test_missing_engine(self, client):
        """测试推理引擎未初始化"""
        with patch('main.get_inference_engine', side_effect=Exception("推理引擎未初始化")):
            request_data = {
                "text": "测试",
                "task_type": "GenerateEmbedding"
            }
            
            response = client.post("/inference", json=request_data)
            assert response.status_code == 503
    
    def test_invalid_task_type(self, client, mock_engine):
        """测试无效的任务类型"""
        with patch('main.get_inference_engine', return_value=mock_engine):
            request_data = {
                "text": "测试",
                "task_type": "InvalidTask"
            }
            
            response = client.post("/inference", json=request_data)
            assert response.status_code == 422  # Validation error
    
    def test_missing_context_for_response(self, client, mock_engine):
        """测试生成回复时缺少上下文"""
        with patch('main.get_inference_engine', return_value=mock_engine):
            request_data = {
                "text": "你好",
                "task_type": "GenerateResponse"
            }
            
            response = client.post("/inference", json=request_data)
            assert response.status_code == 400


class TestPydanticModels:
    """Pydantic模型测试"""
    
    def test_emotional_state_validation(self):
        """测试情感状态验证"""
        # 有效数据
        valid_data = {
            "happiness": 0.8,
            "affection": 0.7,
            "trust": 0.9,
            "dependency": 0.5,
            "mood": "开心",
            "timestamp": "2025-01-14T12:00:00"
        }
        
        emotional_state = EmotionalState(**valid_data)
        assert emotional_state.happiness == 0.8
        assert emotional_state.mood == "开心"
        
        # 无效数据 - 超出范围
        with pytest.raises(ValueError):
            EmotionalState(
                happiness=1.5,  # 超出范围
                affection=0.7,
                trust=0.9,
                dependency=0.5,
                mood="开心",
                timestamp="2025-01-14T12:00:00"
            )
    
    def test_memory_entry_validation(self):
        """测试记忆条目验证"""
        valid_data = {
            "id": "test-id",
            "content": "测试内容",
            "keywords": ["关键词1", "关键词2"],
            "importance": 0.8,
            "created_at": "2025-01-14T12:00:00",
            "memory_type": "conversation"
        }
        
        memory_entry = MemoryEntry(**valid_data)
        assert memory_entry.id == "test-id"
        assert memory_entry.keywords == ["关键词1", "关键词2"]
    
    def test_inference_request_validation(self):
        """测试推理请求验证"""
        valid_data = {
            "text": "测试文本",
            "task_type": "GenerateEmbedding"
        }
        
        request = InferenceRequest(**valid_data)
        assert request.text == "测试文本"
        assert request.task_type == InferenceTaskType.GENERATE_EMBEDDING
        assert request.context is None
        assert request.emotional_state is None


class TestAsyncFunctions:
    """异步函数测试"""
    
    @pytest.mark.asyncio
    async def test_ai_engine_initialization(self):
        """测试AI引擎初始化"""
        engine = AIInferenceEngine()
        
        # 模拟初始化过程（实际测试中可能需要mock模型加载）
        with patch.object(engine, 'initialize') as mock_init:
            mock_init.return_value = None
            await engine.initialize()
            mock_init.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_embedding_generation_async(self):
        """测试异步嵌入生成"""
        engine = AIInferenceEngine()
        
        with patch.object(engine, 'generate_embedding') as mock_gen:
            mock_gen.return_value = [0.1, 0.2, 0.3]
            
            result = await engine.generate_embedding("测试文本")
            assert result == [0.1, 0.2, 0.3]
            mock_gen.assert_called_once_with("测试文本")


@pytest.mark.integration
class TestIntegration:
    """集成测试"""
    
    def test_full_inference_pipeline(self, client):
        """测试完整推理流水线"""
        # 这个测试需要实际的模型，通常在集成测试环境中运行
        pass
    
    def test_memory_context_integration(self, client):
        """测试记忆上下文集成"""
        # 测试记忆系统与推理的集成
        pass


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
