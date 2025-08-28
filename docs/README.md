# MIRA 项目文档

## 📚 文档导航

欢迎来到MIRA项目文档中心！这里提供了完整的项目文档，帮助您快速了解和使用MIRA系统。

## 🚀 快速开始

### 新用户必读
1. **[项目概览](PROJECT_OVERVIEW.md)** - 项目基本信息和快速开始指南
2. **[详细架构](PROJECT_ARCHITECTURE.md)** - 完整的技术架构设计
3. **[部署指南](DEPLOYMENT.md)** - 生产环境部署说明

### 开发者指南
1. **[API文档](API.md)** - 接口使用说明
2. **[开发环境](PROJECT_OVERVIEW.md#开发环境)** - 环境搭建和构建命令
3. **[测试指南](PROJECT_OVERVIEW.md#测试)** - 运行测试和基准测试

## 📖 文档分类

### 🎯 项目文档
| 文档 | 描述 | 适用人群 |
|------|------|----------|
| [项目概览](PROJECT_OVERVIEW.md) | 项目基本信息、架构概览、快速开始 | 所有用户 |
| [详细架构](PROJECT_ARCHITECTURE.md) | 完整的技术架构设计和实现细节 | 开发者、架构师 |
| [部署指南](DEPLOYMENT.md) | 生产环境部署和运维指南 | 运维工程师、DevOps |
| [Nyra档案](NYRA_PROFILE.md) | AI女友Nyra的详细档案和个性设定 | 产品经理、用户 |

### 🔧 技术文档
| 文档 | 描述 | 适用人群 |
|------|------|----------|
| [API文档](API.md) | RESTful API接口文档 | 前端开发者、集成商 |
| [性能测试](PROJECT_ARCHITECTURE.md#测试覆盖) | 性能测试和基准测试结果 | 性能工程师、QA |
| [监控配置](monitoring/) | 监控和告警配置 | 运维工程师 |

## 🏗️ 架构概览

MIRA采用多语言混合架构，包含三个核心层：

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Python Layer  │    │   Rust Layer    │    │   Zig Layer     │
│   (AI推理层)     │◄──►│   (核心逻辑层)   │◄──►│   (系统优化层)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### 各层职责
- **Python层**: AI模型推理、Web API服务
- **Rust层**: 记忆系统、情感引擎、业务逻辑
- **Zig层**: 高性能内存池、系统监控、SIMD优化

## 🛠️ 技术栈

### 核心语言
- **Rust 2024 Edition**: 内存安全和零成本抽象，支持async closures
- **Python 3.13+**: 最新AI模型和推理能力
- **Zig 0.15.1**: 系统级性能优化，SIMD向量运算

### 基础设施
- **Qdrant**: 向量数据库
- **Docker + Kubernetes**: 容器化部署
- **Prometheus + Grafana**: 监控告警

## 📈 性能指标

### 当前性能基准 (2025.8.28)
- **向量运算**: 0.53ns/op (5K维余弦相似度)
- **内存分配**: 28.58ns/op
- **系统监控**: 1,006.15ns/op
- **并发处理**: 支持百万级用户

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
```

## 📁 项目结构

```
mira/
├── 📁 src/                    # Rust核心代码
├── 📁 python_service/         # Python推理服务
├── 📁 zig_system/            # Zig系统层
├── 📁 examples/              # 示例代码
├── 📁 docs/                  # 项目文档
├── 📁 scripts/               # 工具脚本
└── 📁 monitoring/            # 监控配置
```

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

## 📞 支持与反馈

### 问题反馈
- **GitHub Issues**: 报告bug和功能请求
- **Discussions**: 技术讨论和问题解答

### 社区资源
- **官方文档**: 本文档中心
- **示例代码**: `examples/` 目录
- **测试用例**: 各层的测试文件

## 📄 许可证

本项目采用MIT许可证，详见LICENSE文件。

---

*最后更新: 2025年8月28日*
