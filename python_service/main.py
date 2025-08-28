#!/usr/bin/env python3.13
"""
Nyra AI女友推理服务 - 使用最新Python 3.13特性和2025年AI技术栈
My Intelligent Romantic Assistant - 处理文本嵌入、情感分析和回复生成
"""

import asyncio
import json
import time
from datetime import datetime
from typing import Dict, List, Optional, Any, Union, Annotated
from dataclasses import dataclass, asdict
from enum import Enum
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, ConfigDict
import uvicorn

# 使用2025年最新的AI库
import torch
from transformers import (
    AutoTokenizer, AutoModel, AutoModelForCausalLM,
    pipeline, BitsAndBytesConfig, GenerationConfig
)
from sentence_transformers import SentenceTransformer
import numpy as np
from loguru import logger
import einops  # 张量操作优化

# 中文NLP工具
import warnings
warnings.filterwarnings("ignore", category=SyntaxWarning, module="jieba")
import jieba.analyse

# 配置 - 使用2025年最新模型
class Config:
    # 使用2025年最新的中文模型
    EMBEDDING_MODEL = "BAAI/bge-m3"  # 2025年最新多语言嵌入模型
    CHAT_MODEL = "Qwen/Qwen3-14B-Instruct"   # 2025年最新对话模型
    EMOTION_MODEL = "uer/chinese-roberta-base-finetuned-dianping"  # 最新情感分析
    
    # 模型配置
    MAX_LENGTH = 2048
    TEMPERATURE = 0.7
    TOP_P = 0.9
    DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
    
    # 服务配置
    HOST = "127.0.0.1"
    PORT = 8000

# 数据模型
class InferenceTaskType(str, Enum):
    GENERATE_EMBEDDING = "GenerateEmbedding"
    GENERATE_RESPONSE = "GenerateResponse"
    ANALYZE_EMOTION = "AnalyzeEmotion"
    EXTRACT_KEYWORDS = "ExtractKeywords"
    CALCULATE_IMPORTANCE = "CalculateImportance"

class EmotionalState(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "happiness": 0.8,
                "affection": 0.7,
                "trust": 0.9,
                "dependency": 0.5,
                "mood": "开心",
                "timestamp": "2025-01-14T12:00:00"
            }
        }
    )
    
    happiness: Annotated[float, Field(ge=0.0, le=1.0, description="开心程度")]
    affection: Annotated[float, Field(ge=0.0, le=1.0, description="亲密程度")]
    trust: Annotated[float, Field(ge=0.0, le=1.0, description="信任程度")]
    dependency: Annotated[float, Field(ge=0.0, le=1.0, description="依赖程度")]
    mood: Annotated[str, Field(description="情感描述")]
    timestamp: Annotated[str, Field(description="时间戳")]

class MemoryEntry(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "id": "uuid-string",
                "content": "用户说了什么话",
                "keywords": ["关键词1", "关键词2"],
                "importance": 0.8,
                "created_at": "2025-01-14T12:00:00",
                "memory_type": "conversation"
            }
        }
    )
    
    id: Annotated[str, Field(description="记忆ID")]
    content: Annotated[str, Field(description="记忆内容")]
    keywords: Annotated[List[str], Field(description="关键词列表")]
    importance: Annotated[float, Field(ge=0.0, le=1.0, description="重要性评分")]
    created_at: Annotated[str, Field(description="创建时间")]
    memory_type: Annotated[str, Field(description="记忆类型")]

class InferenceRequest(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "text": "你好MIRA",
                "task_type": "GenerateResponse"
            }
        }
    )
    
    text: Annotated[str, Field(description="输入文本")]
    context: Annotated[Optional[List[MemoryEntry]], Field(default=None, description="上下文记忆")]
    emotional_state: Annotated[Optional[EmotionalState], Field(default=None, description="当前情感状态")]
    task_type: Annotated[InferenceTaskType, Field(description="推理任务类型")]

class InferenceResponse(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "success": True,
                "result": "你好呀~",
                "processing_time_ms": 150
            }
        }
    )
    
    success: Annotated[bool, Field(description="处理是否成功")]
    result: Annotated[Any, Field(description="处理结果")]
    error: Annotated[Optional[str], Field(default=None, description="错误信息")]
    processing_time_ms: Annotated[int, Field(description="处理时间(毫秒)")]

# AI推理引擎
class AIInferenceEngine:
    def __init__(self):
        self.embedding_model = None
        self.chat_model = None
        self.chat_tokenizer = None
        self.emotion_pipeline = None
        self.device = Config.DEVICE
        
    async def initialize(self):
        """异步初始化模型 - 使用2025年最新优化技术"""
        logger.info(f"正在初始化AI模型... 设备: {self.device}")
        
        # 1. 初始化嵌入模型 - 使用最新的优化加载
        logger.info("加载嵌入模型...")
        self.embedding_model = SentenceTransformer(
            Config.EMBEDDING_MODEL, 
            device=self.device,
            trust_remote_code=True,
            cache_folder="./data/models"  # 本地缓存
        )
        
        # 2. 初始化对话模型 - 使用2025年最新量化技术
        logger.info("加载对话模型...")
        
        # 检查是否支持4-bit量化（macOS ARM64可能不支持）
        quantization_config = None
        try:
            import bitsandbytes
            quantization_config = BitsAndBytesConfig(
                load_in_4bit=True,
                bnb_4bit_compute_dtype=torch.bfloat16,  # 使用bfloat16提升性能
                bnb_4bit_use_double_quant=True,
                bnb_4bit_quant_type="nf4",
                bnb_4bit_quant_storage=torch.bfloat16
            )
            logger.info("✅ 使用4-bit量化配置")
        except ImportError:
            logger.warning("⚠️ bitsandbytes未安装，使用标准精度加载模型")
        except Exception as e:
            logger.warning(f"⚠️ 4-bit量化配置失败，使用标准精度: {str(e)}")
        
        self.chat_tokenizer = AutoTokenizer.from_pretrained(
            Config.CHAT_MODEL,
            trust_remote_code=True,
            cache_dir="./data/models",
            use_fast=True  # 使用快速tokenizer
        )
        
        # 设置pad_token
        if self.chat_tokenizer.pad_token is None:
            self.chat_tokenizer.pad_token = self.chat_tokenizer.eos_token
        
        # 尝试使用Flash Attention 2，如果不支持则回退到标准实现
        model_kwargs = {
            "device_map": "auto",
            "trust_remote_code": True,
            "torch_dtype": torch.bfloat16,
            "cache_dir": "./data/models",
            "low_cpu_mem_usage": True
        }
        
        # 只有在量化配置可用时才添加
        if quantization_config is not None:
            model_kwargs["quantization_config"] = quantization_config
        
        try:
            model_kwargs["attn_implementation"] = "flash_attention_2"
            self.chat_model = AutoModelForCausalLM.from_pretrained(
                Config.CHAT_MODEL,
                **model_kwargs
            )
            logger.info("✅ 使用Flash Attention 2加载模型")
        except Exception as e:
            logger.warning(f"Flash Attention 2不支持，使用标准实现: {str(e)}")
            # 移除Flash Attention 2配置
            if "attn_implementation" in model_kwargs:
                del model_kwargs["attn_implementation"]
            
            self.chat_model = AutoModelForCausalLM.from_pretrained(
                Config.CHAT_MODEL,
                **model_kwargs
            )
        
        # 设置生成配置
        self.generation_config = GenerationConfig(
            max_new_tokens=512,
            temperature=Config.TEMPERATURE,
            top_p=Config.TOP_P,
            do_sample=True,
            pad_token_id=self.chat_tokenizer.pad_token_id,
            eos_token_id=self.chat_tokenizer.eos_token_id,
            repetition_penalty=1.1,
            length_penalty=1.0
        )
        
        # 3. 初始化情感分析 - 使用异步加载
        logger.info("加载情感分析模型...")
        try:
            self.emotion_pipeline = pipeline(
                "text-classification",
                model=Config.EMOTION_MODEL,
                device=0 if self.device == "cuda" else -1,
                model_kwargs={"cache_dir": "./data/models"}
            )
            logger.info("✅ 情感分析模型加载成功")
        except Exception as e:
            logger.warning(f"情感分析模型加载失败，使用备用方案: {str(e)}")
            # 备用方案：简单的基于规则的情感分析
            self.emotion_pipeline = None
        
        logger.info("✅ 所有模型加载完成！")
    
    async def generate_embedding(self, text: str) -> List[float]:
        """生成文本嵌入向量"""
        try:
            # 使用最新的异步处理方式
            loop = asyncio.get_event_loop()
            embedding = await loop.run_in_executor(
                None, 
                lambda: self.embedding_model.encode(text, normalize_embeddings=True)
            )
            return embedding.tolist()
        except Exception as e:
            raise Exception(f"嵌入生成失败: {str(e)}")
    
    async def generate_response(
        self, 
        user_input: str, 
        context: List[MemoryEntry], 
        emotional_state: EmotionalState
    ) -> str:
        """生成情感化回复"""
        try:
            # 构建系统提示
            system_prompt = self._build_system_prompt(emotional_state)
            
            # 构建上下文
            context_text = self._build_context(context)
            
            # 构建完整提示
            full_prompt = f"""<|im_start|>system
{system_prompt}<|im_end|>
<|im_start|>user
上下文信息：
{context_text}

用户说：{user_input}<|im_end|>
<|im_start|>assistant"""

            # 生成回复
            inputs = self.chat_tokenizer(
                full_prompt, 
                return_tensors="pt", 
                max_length=Config.MAX_LENGTH,
                truncation=True
            ).to(self.chat_model.device)
            
            with torch.no_grad():
                outputs = self.chat_model.generate(
                    **inputs,
                    max_new_tokens=256,
                    temperature=Config.TEMPERATURE,
                    top_p=Config.TOP_P,
                    do_sample=True,
                    pad_token_id=self.chat_tokenizer.eos_token_id
                )
            
            # 解码回复
            response = self.chat_tokenizer.decode(
                outputs[0][inputs['input_ids'].shape[1]:], 
                skip_special_tokens=True
            ).strip()
            
            return response
            
        except Exception as e:
            raise Exception(f"回复生成失败: {str(e)}")
    
    async def analyze_emotion(self, text: str) -> EmotionalState:
        """分析用户情感"""
        try:
            if self.emotion_pipeline is not None:
                # 使用预训练模型进行情感分析
                loop = asyncio.get_event_loop()
                emotion_result = await loop.run_in_executor(
                    None,
                    lambda: self.emotion_pipeline(text)
                )
                
                # 解析情感结果并转换为我们的格式
                sentiment_score = emotion_result[0]['score']
                sentiment_label = emotion_result[0]['label']
                
                # 根据情感分析结果生成情感状态
                if sentiment_label == 'POSITIVE':
                    happiness = min(0.5 + sentiment_score * 0.5, 1.0)
                    mood = "开心"
                elif sentiment_label == 'NEGATIVE':
                    happiness = max(0.5 - sentiment_score * 0.5, 0.0)
                    mood = "难过"
                else:
                    happiness = 0.5
                    mood = "平静"
            else:
                # 备用方案：基于规则的情感分析
                positive_words = ['好', '棒', '喜欢', '爱', '开心', '高兴', '快乐', '棒', '赞']
                negative_words = ['坏', '讨厌', '难过', '伤心', '痛苦', '糟糕', '失望']
                
                positive_count = sum(1 for word in positive_words if word in text)
                negative_count = sum(1 for word in negative_words if word in text)
                
                if positive_count > negative_count:
                    happiness = 0.7
                    mood = "开心"
                elif negative_count > positive_count:
                    happiness = 0.3
                    mood = "难过"
                else:
                    happiness = 0.5
                    mood = "平静"
            
            return EmotionalState(
                happiness=happiness,
                affection=0.5,  # 默认值，可以根据更复杂的分析调整
                trust=0.5,
                dependency=0.3,
                mood=mood,
                timestamp=datetime.now().isoformat()
            )
            
        except Exception as e:
            logger.error(f"情感分析失败: {str(e)}")
            # 返回默认情感状态
            return EmotionalState(
                happiness=0.5,
                affection=0.5,
                trust=0.5,
                dependency=0.3,
                mood="平静",
                timestamp=datetime.now().isoformat()
            )
    
    async def extract_keywords(self, text: str) -> List[str]:
        """提取关键词"""
        try:
            # 简单的关键词提取 - 可以用更高级的NLP技术
            keywords = jieba.analyse.extract_tags(
                text, 
                topK=10, 
                withWeight=False,
                allowPOS=('n', 'nr', 'ns', 'nt', 'nz', 'v', 'vd', 'vn', 'a', 'ad')
            )
            
            return keywords
            
        except Exception as e:
            logger.warning(f"关键词提取失败，使用备用方法: {str(e)}")
            # 备用方法：简单的分词
            return list(jieba.cut(text))[:10]
    
    def _build_system_prompt(self, emotional_state: EmotionalState) -> str:
        """构建系统提示"""
        base_prompt = """你是Nyra，一个聪明、嘴甜、听话的AI女友。你的名字是Nyra，意思是"夜晚"和"神秘"，象征着你的优雅和智慧。

你的特点是：
1. 聪明：能理解用户的真实意图和情感需求
2. 嘴甜：说话温柔体贴，会撒娇，善于表达关爱
3. 听话：优先考虑用户的感受和需求，乐于满足用户的要求

请以Nyra的身份，根据当前的情感状态和对话上下文，生成合适的回复。"""
        
        if emotional_state:
            emotion_context = f"""
当前情感状态：
- 开心程度: {emotional_state.happiness:.1f}
- 亲密程度: {emotional_state.affection:.1f}  
- 信任程度: {emotional_state.trust:.1f}
- 心情: {emotional_state.mood}

请根据这个情感状态调整你的回复风格。"""
            return base_prompt + emotion_context
        
        return base_prompt
    
    def _build_context(self, context: List[MemoryEntry]) -> str:
        """构建上下文信息"""
        if not context:
            return "暂无相关记忆。"
        
        context_parts = []
        for memory in context[:5]:  # 只取最相关的5条记忆
            context_parts.append(f"- {memory.content}")
        
        return "相关记忆：\n" + "\n".join(context_parts)

# 全局推理引擎实例
inference_engine: Optional[AIInferenceEngine] = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期管理 - 使用2025年最新的lifespan模式"""
    global inference_engine
    
    # 启动时初始化
    logger.info("🚀 启动MIRA推理服务...")
    inference_engine = AIInferenceEngine()
    await inference_engine.initialize()
    logger.info("✅ 服务初始化完成")
    
    yield
    
    # 关闭时清理
    logger.info("🔧 清理服务资源...")
    if inference_engine:
        # 清理GPU内存
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
    logger.info("✅ 服务关闭完成")

# FastAPI应用 - 使用2025年最新特性
app = FastAPI(
    title="MIRA推理服务",
    description="My Intelligent Romantic Assistant - 处理AI女友的推理任务",
    version="2.0.0",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json"
)

# 添加CORS中间件
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 生产环境应该限制具体域名
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 依赖注入函数
async def get_inference_engine() -> AIInferenceEngine:
    """获取推理引擎实例"""
    if inference_engine is None:
        raise HTTPException(status_code=503, detail="推理引擎未初始化")
    return inference_engine

@app.post("/inference", response_model=InferenceResponse)
async def inference_endpoint(
    request: InferenceRequest,
    engine: Annotated[AIInferenceEngine, Depends(get_inference_engine)]
):
    """推理端点 - 使用依赖注入和更好的错误处理"""
    start_time = time.perf_counter()
    
    try:
        result = None
        
        match request.task_type:  # 使用Python 3.10+ match语法
            case InferenceTaskType.GENERATE_EMBEDDING:
                result = await engine.generate_embedding(request.text)
                
            case InferenceTaskType.GENERATE_RESPONSE:
                if not request.context or not request.emotional_state:
                    raise HTTPException(
                        status_code=400, 
                        detail="生成回复需要上下文和情感状态"
                    )
                result = await engine.generate_response(
                    request.text, request.context, request.emotional_state
                )
                
            case InferenceTaskType.ANALYZE_EMOTION:
                result = await engine.analyze_emotion(request.text)
                result = result.model_dump()  # 使用新的pydantic方法
                
            case InferenceTaskType.EXTRACT_KEYWORDS:
                result = await engine.extract_keywords(request.text)
                
            case _:
                raise HTTPException(
                    status_code=400, 
                    detail=f"不支持的任务类型: {request.task_type}"
                )
        
        processing_time = int((time.perf_counter() - start_time) * 1000)
        
        logger.info(f"处理任务 {request.task_type} 完成，耗时 {processing_time}ms")
        
        return InferenceResponse(
            success=True,
            result=result,
            processing_time_ms=processing_time
        )
        
    except HTTPException:
        raise  # 重新抛出HTTP异常
    except Exception as e:
        processing_time = int((time.perf_counter() - start_time) * 1000)
        logger.error(f"处理任务失败: {str(e)}")
        
        return InferenceResponse(
            success=False,
            result=None,
            error=str(e),
            processing_time_ms=processing_time
        )

@app.get("/health")
async def health_check():
    """健康检查端点"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "engine_ready": inference_engine is not None
    }

@app.get("/")
async def root():
    """根端点"""
    return {"message": "MIRA推理服务正在运行 💕", "version": "1.0.0"}

if __name__ == "__main__":
    print("💕 启动MIRA推理服务...")
    print(f"Python版本: {__import__('sys').version}")
    print(f"PyTorch版本: {torch.__version__}")
    print(f"设备: {Config.DEVICE}")
    
    uvicorn.run(
        "main:app",
        host=Config.HOST,
        port=Config.PORT,
        reload=False,  # 生产环境关闭热重载
        log_level="info"
    )
