#!/bin/bash

# Docker配置验证脚本
echo "🔍 验证Docker配置..."

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    echo "❌ Docker未安装"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose未安装"
    exit 1
fi

echo "✅ Docker和Docker Compose已安装"

# 检查配置文件
echo "📋 检查配置文件..."

if [ ! -f "docker-compose.yml" ]; then
    echo "❌ docker-compose.yml不存在"
    exit 1
fi

if [ ! -f "python_service/Dockerfile" ]; then
    echo "❌ python_service/Dockerfile不存在"
    exit 1
fi

if [ ! -f "Dockerfile.rust" ]; then
    echo "❌ Dockerfile.rust不存在"
    exit 1
fi

echo "✅ 所有Docker配置文件存在"

# 验证docker-compose语法
echo "🔧 验证docker-compose语法..."
if docker-compose config > /dev/null 2>&1; then
    echo "✅ docker-compose.yml语法正确"
else
    echo "❌ docker-compose.yml语法错误"
    docker-compose config
    exit 1
fi

# 检查端口冲突
echo "🔌 检查端口冲突..."
ports=("6333" "6334" "8000" "3000" "6379" "5432" "3001" "9090")
for port in "${ports[@]}"; do
    if lsof -i :$port > /dev/null 2>&1; then
        echo "⚠️  端口 $port 已被占用"
    else
        echo "✅ 端口 $port 可用"
    fi
done

# 检查必要的目录
echo "📁 检查必要目录..."
directories=("data/models" "logs" "monitoring")
for dir in "${directories[@]}"; do
    if [ ! -d "$dir" ]; then
        echo "📁 创建目录: $dir"
        mkdir -p "$dir"
    else
        echo "✅ 目录存在: $dir"
    fi
done

echo ""
echo "🎉 Docker配置验证完成！"
echo ""
echo "📋 下一步："
echo "  1. 运行 'docker-compose up -d' 启动服务"
echo "  2. 运行 'docker-compose logs -f' 查看日志"
echo "  3. 访问 http://localhost:8000/docs 查看API文档"
echo "  4. 访问 http://localhost:3001 查看Grafana监控"
