#!/bin/bash

# MIRA环境设置脚本

echo "🔧 设置MIRA开发环境..."

# 设置CUDA环境变量
if command -v nvidia-smi &> /dev/null; then
    echo "✅ 检测到NVIDIA GPU，启用CUDA支持"
    export CUDA_VISIBLE_DEVICES=0
    export TORCH_CUDA_ARCH_LIST="8.0;8.6;8.9;9.0"
else
    echo "⚠️  未检测到NVIDIA GPU，使用CPU模式"
    export CUDA_VISIBLE_DEVICES=""
fi

# 设置Python优化
export PYTHONPATH="${PYTHONPATH}:$(pwd)/python_service"
export PYTHONUNBUFFERED=1
export TOKENIZERS_PARALLELISM=false  # 避免tokenizers警告

# 设置Rust环境
export RUST_LOG=info
export RUST_BACKTRACE=1

# 设置Zig环境
export ZIG_CACHE_DIR="$(pwd)/zig_system/zig-cache"

# 创建必要的目录
mkdir -p logs
mkdir -p data/models
mkdir -p data/cache

echo "✅ 环境设置完成！"
echo "💡 提示："
echo "  - 使用 'pixi run dev-python' 启动Python开发服务器"
echo "  - 使用 'pixi run build-all' 构建所有组件"
echo "  - 使用 'pixi run test-all' 运行所有测试"
