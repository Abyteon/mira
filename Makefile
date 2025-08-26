# MIRA项目 Makefile - 统一构建和测试
# My Intelligent Romantic Assistant

.PHONY: all build test clean run install-deps bench format lint

# 默认目标
all: build

# 构建所有组件
build: build-rust build-python build-zig

# 构建Rust核心
build-rust:
	@echo "🦀 构建Rust核心..."
	cargo build --release

# 构建Python推理层  
build-python:
	@echo "🐍 设置Python推理层..."
	cd python_service && \
	python3.13 -m venv venv && \
	. venv/bin/activate && \
	pip install -r requirements.txt

# 构建Zig系统层 (0.15.1)
build-zig:
	@echo "⚡ 构建Zig系统层 (v0.15.1)..."
	cd zig_system && zig build

# 运行所有测试
test: test-rust test-python test-zig

test-rust:
	@echo "🧪 运行Rust测试..."
	cargo test

test-python:
	@echo "🧪 运行Python测试..."
	cd python_service && \
	. venv/bin/activate && \
	pytest

test-zig:
	@echo "🧪 运行Zig测试 (v0.15.1)..."
	cd zig_system && zig build test
	cd zig_system && zig build integration-test

# 性能基准测试
bench:
	@echo "📊 运行性能基准测试..."
	cargo bench
	cd zig_system && zig build bench

# 代码格式化
format:
	@echo "🎨 格式化代码..."
	cargo fmt
	cd python_service && black . && isort .
	cd zig_system && zig fmt src/

# 代码检查
lint:
	@echo "🔍 代码检查..."
	cargo clippy -- -D warnings
	cd python_service && flake8 .

# 运行主示例
run:
	@echo "🚀 运行AI女友演示..."
	cargo run --example main

# 启动Python推理服务
run-python:
	@echo "🐍 启动Python推理服务..."
	cd python_service && \
	. venv/bin/activate && \
	python main.py

# 启动Qdrant向量数据库
run-qdrant:
	@echo "🗄️ 启动Qdrant向量数据库..."
	docker run -p 6333:6333 -v $(PWD)/qdrant_data:/qdrant/storage qdrant/qdrant

# 安装系统依赖
install-deps:
	@echo "📦 安装系统依赖..."
	# Rust
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
	# Python 3.13 (需要手动安装或从源码编译)
	# Zig 0.15.1
	curl -O https://ziglang.org/download/0.15.1/zig-macos-aarch64-0.15.1.tar.xz
	tar -xf zig-macos-aarch64-0.15.1.tar.xz

# 清理构建文件
clean:
	@echo "🧹 清理构建文件..."
	cargo clean
	rm -rf python_service/venv
	rm -rf python_service/__pycache__
	cd zig_system && rm -rf zig-out zig-cache

# 完整的CI/CD流程
ci: format lint test bench
	@echo "✅ CI/CD流程完成"

# 开发环境设置
dev-setup: install-deps build
	@echo "🛠️ 开发环境设置完成"
	@echo "请运行以下命令启动服务："
	@echo "  make run-qdrant  # 启动向量数据库"
	@echo "  make run-python  # 启动Python推理服务"  
	@echo "  make run         # 运行演示程序"

# 性能监控
monitor:
	@echo "📊 启动性能监控..."
	# 这里可以添加性能监控工具

# 帮助信息
help:
	@echo "AI女友项目构建系统"
	@echo ""
	@echo "主要命令:"
	@echo "  make build      - 构建所有组件"
	@echo "  make test       - 运行所有测试"
	@echo "  make run        - 运行演示程序"
	@echo "  make format     - 格式化代码"
	@echo "  make lint       - 代码检查"
	@echo "  make clean      - 清理构建文件"
	@echo "  make dev-setup  - 设置开发环境"
	@echo ""
	@echo "服务命令:"
	@echo "  make run-python  - 启动Python推理服务"
	@echo "  make run-qdrant  - 启动向量数据库"
	@echo ""
	@echo "高级命令:"
	@echo "  make bench      - 性能基准测试"
	@echo "  make ci         - 完整CI/CD流程"
