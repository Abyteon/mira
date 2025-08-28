# MIRA 项目概览

## 📋 项目基本信息

**项目名称**: MIRA (My Intelligent Romantic Assistant)  
**AI女友**: Nyra (奈拉) - 源自希腊神话夜之女神  
**项目定位**: 企业级多语言混合架构AI女友系统  
**开发时间**: 2025年8月  
**技术栈**: Rust 2024 Edition + Python 3.13+ + Zig 0.15.1 + Qdrant + Docker + Kubernetes  

## 🏗️ 架构概览

### 三层架构设计
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Python Layer  │    │   Rust Layer    │    │   Zig Layer     │
│   (AI推理层)     │◄──►│   (核心逻辑层)   │◄──►│   (系统优化层)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   FastAPI       │    │   Memory System │    │   Memory Pool   │
│   AI Models     │    │   Emotion Engine│    │   System Monitor│
│   Vector Store  │    │   Bridge Layer  │    │   SIMD Vector   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### 语言分工
- **Python**: AI模型推理和Web服务
- **Rust**: 核心逻辑和并发安全
- **Zig**: 系统级性能优化

## 🎯 核心功能

### 1. 智能对话系统
- 自然语言理解和生成
- 上下文记忆管理
- 个性化回复生成

### 2. 情感引擎
- 情感状态管理 (happiness, affection, trust, dependency)
- 个性化性格塑造
- 关系发展模拟

### 3. 记忆系统
- 短期记忆 (对话上下文)
- 长期记忆 (重要事件)
- 情感记忆 (情感历史)
- 偏好记忆 (用户喜好)
- 关系记忆 (关系发展历程)

### 4. 高性能计算
- 向量相似度计算 (768维嵌入向量)
- 内存池管理 (自定义分配器)
- 系统性能监控 (macOS系统调用)

## 🚀 技术特色

### 2025年最新技术栈
- **Rust 2024 Edition**: 内存安全和零成本抽象，支持async closures
- **Python 3.13+**: 最新AI模型和推理能力
- **Zig 0.15.1**: 系统级性能优化，SIMD向量运算
- **Apple Silicon优化**: ARM NEON SIMD加速

### 企业级特性
- **容器化部署**: Docker + Kubernetes
- **监控告警**: Prometheus + Grafana
- **高可用设计**: 微服务架构
- **性能优化**: 多层级缓存策略

## 📊 性能指标

### 当前性能基准 (2025.8.28)
- **向量运算**: 0.53ns/op (5K维余弦相似度)
- **内存分配**: 28.58ns/op
- **系统监控**: 1,006.15ns/op
- **并发处理**: 支持百万级用户

### 目标性能
- **向量运算**: 0.1ns/op (提升430%)
- **内存管理**: 300ns/op (提升231%)
- **监控开销**: 100ns/op (提升906%)

## 🛠️ 开发环境

### 环境管理
- **pixi**: Python环境管理 (Python 3.13)
- **Cargo**: Rust包管理 (Rust 2024 Edition)
- **Zig**: Zig包管理 (Zig 0.15.1)

### 构建命令
```bash
# 完整构建
pixi run build-all

# 分层构建
pixi run build-rust    # Rust层
pixi run build-zig     # Zig层
pixi run dev-python    # Python层开发

# 测试
pixi run test-all      # 全层测试
```

## 📁 项目结构

```
mira/
├── 📁 src/                    # Rust核心代码
│   ├── bridge/               # 多语言桥接
│   ├── emotion/              # 情感系统
│   ├── memory/               # 记忆系统
│   └── vector_store/         # 向量存储
├── 📁 python_service/         # Python推理服务
│   ├── main.py              # 主服务文件
│   ├── requirements.txt     # Python依赖
│   └── tests/               # Python测试
├── 📁 zig_system/            # Zig系统层
│   ├── src/                 # Zig源代码
│   ├── tests/               # Zig测试
│   ├── bench/               # Zig基准测试
│   └── build.zig            # Zig构建配置
├── 📁 examples/              # 示例代码
├── 📁 docs/                  # 项目文档
├── 📁 scripts/               # 工具脚本
└── 📁 monitoring/            # 监控配置
```

## 🚀 快速开始

### 1. 环境准备
```bash
# 安装pixi
curl -fsSL https://pixi.sh/install.sh | bash

# 安装依赖
pixi install
```

### 2. 启动服务
```bash
# 启动Python推理服务
pixi run dev-python

# 启动Rust核心服务
pixi run build-rust
cargo run --example main
```

### 3. 运行测试
```bash
# 全层测试
pixi run test-all

# 分层测试
pixi run test-python
pixi run test-rust
pixi run test-zig
```

## 📚 相关文档

- [详细架构设计](PROJECT_ARCHITECTURE.md) - 完整的技术架构设计
- [部署指南](DEPLOYMENT.md) - 生产环境部署说明
- [Nyra档案](NYRA_PROFILE.md) - AI女友详细档案
- [API文档](API.md) - 接口使用说明

## 🤝 贡献指南

### 开发流程
1. Fork项目
2. 创建功能分支
3. 提交代码
4. 创建Pull Request

### 代码规范
- **Rust**: 遵循Rust官方编码规范
- **Python**: 使用black和ruff格式化
- **Zig**: 遵循Zig官方编码规范

## 📄 许可证

本项目采用MIT许可证，详见LICENSE文件。

---

*最后更新: 2025年8月28日*
