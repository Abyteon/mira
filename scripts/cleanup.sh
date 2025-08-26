#!/bin/bash

# MIRA项目清理脚本
# 用于删除不必要的文件和目录，瘦身项目

echo "🧹 开始清理MIRA项目..."

# 1. 删除构建缓存
echo "📦 清理构建缓存..."
rm -rf target/ 2>/dev/null || true
rm -rf zig_system/zig-out/ 2>/dev/null || true
rm -rf zig_system/.zig-cache/ 2>/dev/null || true

# 2. 删除Python缓存
echo "🐍 清理Python缓存..."
find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
find . -name "*.pyc" -delete 2>/dev/null || true
find . -name "*.pyo" -delete 2>/dev/null || true

# 3. 删除临时文件
echo "🗑️ 清理临时文件..."
rm -f test_build.zig 2>/dev/null || true
rm -f test.zig 2>/dev/null || true
rm -f interact_with_mira.py 2>/dev/null || true

# 4. 清理日志文件（保留目录）
echo "📝 清理日志文件..."
find logs/ -name "*.log" -delete 2>/dev/null || true

# 5. 清理数据缓存（保留目录结构）
echo "💾 清理数据缓存..."
find data/cache/ -name "*" -delete 2>/dev/null || true

# 6. 清理IDE文件
echo "🔧 清理IDE文件..."
find . -name ".DS_Store" -delete 2>/dev/null || true
find . -name "*.swp" -delete 2>/dev/null || true
find . -name "*.swo" -delete 2>/dev/null || true

echo "✅ 项目清理完成！"
echo ""
echo "📊 清理总结："
echo "  - 删除了构建缓存目录"
echo "  - 删除了Python缓存文件"
echo "  - 删除了临时测试文件"
echo "  - 清理了日志文件"
echo "  - 清理了数据缓存"
echo ""
echo "💡 提示："
echo "  - 运行 'cargo build' 重新构建Rust项目"
echo "  - 运行 'zig build' 重新构建Zig项目"
echo "  - 运行 'pixi install' 重新安装Python依赖"
