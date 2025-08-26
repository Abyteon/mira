# 📁 MIRA项目结构说明

## 🎯 项目概述

MIRA (My Intelligent Romantic Assistant) 是一个多语言混合架构的AI女友系统，包含Rust核心、Python推理、Zig系统层等多个组件。

## 📂 核心目录结构

```
mira/
├── 📁 src/                    # Rust核心代码 (必需)
│   ├── bridge/               # 多语言桥接
│   ├── emotion/              # 情感系统
│   ├── memory/               # 记忆系统
│   └── vector_store/         # 向量存储
├── 📁 python_service/         # Python推理服务 (必需)
│   ├── main.py              # 主服务文件
│   ├── requirements.txt     # Python依赖
│   └── tests/               # Python测试
├── 📁 zig_system/            # Zig系统层 (必需)
│   ├── src/                 # Zig源代码
│   ├── tests/               # Zig测试
│   ├── bench/               # Zig基准测试
│   └── build.zig            # Zig构建配置
├── 📁 docs/                  # 项目文档 (必需)
│   ├── NYRA_PROFILE.md      # Nyra档案
│   ├── PROJECT_SUMMARY.md   # 项目总结
│   └── DEPLOYMENT.md        # 部署指南
├── 📁 examples/              # 示例代码 (必需)
├── 📁 scripts/               # 工具脚本 (必需)
├── 📁 monitoring/            # 监控配置 (可选)
└── 📁 .github/               # CI/CD配置 (可选)
```

## ✅ 必需文件

### 🔧 配置文件
- `Cargo.toml` - Rust项目配置
- `pixi.toml` - 环境管理配置
- `docker-compose.yml` - 容器编排
- `Makefile` - 构建脚本
- `build.rs` - Rust构建脚本
- `env.example` - 环境变量模板

### 📚 文档文件
- `README.md` - 项目主文档
- `docs/NYRA_PROFILE.md` - Nyra AI女友档案
- `docs/PROJECT_SUMMARY.md` - 项目开发历程
- `docs/DEPLOYMENT.md` - 部署指南
- `docs/PROJECT_STRUCTURE.md` - 项目结构说明

### 🛠️ 工具脚本
- `scripts/cleanup.sh` - 项目清理脚本
- `scripts/setup.sh` - 环境设置脚本

## 🗑️ 可删除文件

### 📦 构建缓存
- `target/` - Rust构建输出 (可重新生成)
- `zig_system/zig-out/` - Zig构建输出 (可重新生成)
- `zig_system/.zig-cache/` - Zig缓存 (可重新生成)

### 🐍 Python缓存
- `__pycache__/` - Python字节码缓存
- `*.pyc` - Python编译文件
- `*.pyo` - Python优化文件

### 📝 临时文件
- `test_build.zig` - 临时测试文件
- `test.zig` - 临时测试文件
- `interact_with_mira.py` - 临时交互脚本

### 💾 数据文件
- `data/cache/` - 模型缓存 (可重新下载)
- `data/models/` - 模型文件 (可重新下载)
- `logs/*.log` - 日志文件 (可重新生成)

## 🔄 重新生成方法

### Rust项目
```bash
cargo build          # 重新构建
cargo test           # 运行测试
```

### Zig项目
```bash
cd zig_system
zig build           # 重新构建
zig build test      # 运行测试
```

### Python项目
```bash
pixi install        # 重新安装依赖
cd python_service
python main.py      # 运行服务
```

## 🧹 清理建议

### 定期清理
```bash
# 使用清理脚本
./scripts/cleanup.sh

# 或手动清理
rm -rf target/
rm -rf zig_system/zig-out/
rm -rf zig_system/.zig-cache/
find . -name "__pycache__" -type d -exec rm -rf {} +
```

### 提交前清理
```bash
# 确保不提交不必要的文件
git status
git add .
git commit -m "更新项目"
```

## 📊 项目大小优化

### 清理前
- 总大小: ~500MB
- 主要占用: 构建缓存、模型文件

### 清理后
- 总大小: ~50MB
- 主要占用: 源代码、文档

### 进一步优化
- 使用 `.gitignore` 避免提交缓存文件
- 定期运行清理脚本
- 使用 Docker 多阶段构建减少镜像大小

---

*保持项目整洁，提高开发效率！* 🧹✨
