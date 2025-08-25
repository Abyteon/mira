# 🚀 MIRA项目部署指南

## 部署方式概览

MIRA支持多种部署方式，从开发环境到生产环境：

- **本地开发**: 使用pixi管理环境
- **容器化部署**: Docker Compose
- **云原生部署**: Kubernetes
- **混合部署**: 部分组件云端，部分本地

## 📋 部署前准备

### 系统要求

#### 最低配置
- **CPU**: 4核心 
- **内存**: 8GB RAM
- **存储**: 50GB 可用空间
- **网络**: 稳定的互联网连接

#### 推荐配置
- **CPU**: 8核心+ (Intel/AMD)
- **内存**: 16GB+ RAM
- **存储**: 100GB+ NVMe SSD
- **GPU**: NVIDIA GPU (8GB+ VRAM) - 可选但推荐

### 软件依赖
```bash
# 必需
Docker 24.0+
Docker Compose 2.0+

# 可选 (本地开发)
Rust 1.82+
Python 3.13+
Zig 0.15.1+
```

## 🐳 Docker Compose部署 (推荐)

### 1. 快速启动

```bash
# 克隆项目
git clone https://github.com/your-org/mira.git
cd mira

# 配置环境变量
cp env.example .env
# 编辑 .env 文件配置必要参数

# 启动所有服务
docker-compose up -d
```

### 2. 服务访问

启动后可访问以下服务：

- **Python推理API**: http://localhost:8000
  - Swagger文档: http://localhost:8000/docs
  - 健康检查: http://localhost:8000/health

- **Qdrant向量数据库**: http://localhost:6333
  - Web界面: http://localhost:6333/dashboard

- **Grafana监控**: http://localhost:3001
  - 用户名: admin
  - 密码: admin (首次登录需修改)

- **Prometheus**: http://localhost:9090

### 3. 验证部署

```bash
# 检查所有服务状态
docker-compose ps

# 查看服务日志
docker-compose logs -f python_inference

# 健康检查
curl http://localhost:8000/health
curl http://localhost:6333/health
```

## 🔧 生产环境部署

### 1. 环境配置

创建生产环境配置文件 `.env.production`:

```bash
# 基础配置
ENVIRONMENT=production
DEBUG=false

# 安全配置
API_KEY=your_production_api_key
JWT_SECRET=your_production_jwt_secret
ALLOWED_ORIGINS=https://your-domain.com

# 数据库配置
POSTGRES_PASSWORD=your_secure_password
REDIS_PASSWORD=your_redis_password

# 模型配置
MODEL_CACHE_DIR=/opt/mira/models
CUDA_VISIBLE_DEVICES=0
```

### 2. 生产部署命令

```bash
# 使用生产配置启动
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# 或者使用制作好的生产镜像
docker-compose -f docker-compose.prod.yml up -d
```

### 3. 负载均衡配置

创建 `nginx.conf`:

```nginx
upstream mira_python {
    server localhost:8000;
    # 可以添加多个实例实现负载均衡
    # server localhost:8001;
}

upstream mira_rust {
    server localhost:3000;
}

server {
    listen 80;
    server_name your-domain.com;

    # Python推理服务
    location /api/ {
        proxy_pass http://mira_python;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Rust核心服务
    location /core/ {
        proxy_pass http://mira_rust;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # 静态文件 (如果有前端)
    location / {
        root /var/www/html;
        try_files $uri $uri/ =404;
    }
}
```

## ☸️ Kubernetes部署

### 1. 命名空间

```yaml
# namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: mira
```

### 2. 配置映射

```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mira-config
  namespace: mira
data:
  ENVIRONMENT: "production"
  RUST_LOG: "info"
  PYTHON_HOST: "0.0.0.0"
  PYTHON_PORT: "8000"
  QDRANT_URL: "http://qdrant-service:6333"
```

### 3. 密钥

```yaml
# secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: mira-secrets
  namespace: mira
type: Opaque
stringData:
  API_KEY: "your_production_api_key"
  JWT_SECRET: "your_jwt_secret"
  POSTGRES_PASSWORD: "your_db_password"
```

### 4. 持久化存储

```yaml
# pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mira-models-pvc
  namespace: mira
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
  storageClassName: fast-ssd
```

### 5. Python推理服务部署

```yaml
# python-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mira-python
  namespace: mira
spec:
  replicas: 2
  selector:
    matchLabels:
      app: mira-python
  template:
    metadata:
      labels:
        app: mira-python
    spec:
      containers:
      - name: python-inference
        image: your-registry/mira-python:latest
        ports:
        - containerPort: 8000
        env:
        - name: ENVIRONMENT
          valueFrom:
            configMapKeyRef:
              name: mira-config
              key: ENVIRONMENT
        - name: API_KEY
          valueFrom:
            secretKeyRef:
              name: mira-secrets
              key: API_KEY
        volumeMounts:
        - name: models-storage
          mountPath: /app/data/models
        resources:
          requests:
            memory: "4Gi"
            cpu: "1000m"
          limits:
            memory: "8Gi"
            cpu: "2000m"
            nvidia.com/gpu: 1
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 60
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
      volumes:
      - name: models-storage
        persistentVolumeClaim:
          claimName: mira-models-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: mira-python-service
  namespace: mira
spec:
  selector:
    app: mira-python
  ports:
    - protocol: TCP
      port: 8000
      targetPort: 8000
  type: ClusterIP
```

### 6. 部署命令

```bash
# 应用所有配置
kubectl apply -f k8s/

# 检查部署状态
kubectl get pods -n mira
kubectl get services -n mira

# 查看日志
kubectl logs -f deployment/mira-python -n mira
```

## 🔍 监控和日志

### 1. Prometheus监控

监控指标包括：
- **系统指标**: CPU、内存、磁盘使用率
- **应用指标**: 请求数量、响应时间、错误率
- **业务指标**: 推理请求数、记忆存储量、情感状态变化

### 2. 日志聚合

```yaml
# 使用ELK或EFK栈
logging:
  driver: "fluentd"
  options:
    fluentd-address: localhost:24224
    tag: mira.{{.Name}}
```

### 3. 告警配置

```yaml
# prometheus-alerts.yml
groups:
- name: mira.rules
  rules:
  - alert: PythonServiceDown
    expr: up{job="mira-python"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "MIRA Python服务不可用"
      
  - alert: HighMemoryUsage
    expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes > 0.9
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "内存使用率过高"
```

## 🔐 安全配置

### 1. 网络安全

```bash
# 防火墙配置
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw deny 6333/tcp   # 禁止外部访问Qdrant
ufw deny 5432/tcp   # 禁止外部访问PostgreSQL
```

### 2. SSL证书

```bash
# 使用Let's Encrypt
certbot --nginx -d your-domain.com
```

### 3. 访问控制

```yaml
# 添加到docker-compose.yml
networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true  # 内部网络，不可从外部访问
```

## 📈 性能优化

### 1. GPU优化

```yaml
# docker-compose.yml
services:
  python_inference:
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```

### 2. 缓存优化

```yaml
# Redis缓存配置
redis:
  image: redis:7-alpine
  command: redis-server --maxmemory 2gb --maxmemory-policy allkeys-lru
```

### 3. 数据库优化

```yaml
# PostgreSQL调优
postgres:
  environment:
    - POSTGRES_SHARED_PRELOAD_LIBRARIES=pg_stat_statements
    - POSTGRES_MAX_CONNECTIONS=200
    - POSTGRES_SHARED_BUFFERS=256MB
```

## 🔄 更新和回滚

### 1. 滚动更新

```bash
# 更新Python服务
docker-compose pull python_inference
docker-compose up -d python_inference

# Kubernetes滚动更新
kubectl set image deployment/mira-python python-inference=your-registry/mira-python:v2.0.0 -n mira
```

### 2. 回滚

```bash
# Docker回滚
docker-compose down
docker-compose up -d

# Kubernetes回滚
kubectl rollout undo deployment/mira-python -n mira
```

## 🆘 故障排除

### 常见问题

1. **Python服务启动失败**
   ```bash
   # 检查GPU可用性
   docker run --rm --gpus all nvidia/cuda:11.8-base-ubuntu20.04 nvidia-smi
   
   # 检查模型下载
   docker-compose logs python_inference | grep -i "model"
   ```

2. **Qdrant连接失败**
   ```bash
   # 检查网络连通性
   docker-compose exec python_inference curl -f http://qdrant:6333/health
   ```

3. **内存不足**
   ```bash
   # 启用swap
   sudo swapon --show
   sudo fallocate -l 8G /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile
   ```

### 日志查看

```bash
# 查看所有服务日志
docker-compose logs -f

# 查看特定服务日志
docker-compose logs -f python_inference
docker-compose logs -f qdrant

# 查看最近日志
docker-compose logs --tail=100 -f
```

这份部署指南涵盖了从开发到生产的完整部署流程，根据您的具体需求选择合适的部署方式。
