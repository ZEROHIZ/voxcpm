FROM python:3.10-slim

# 设置工作目录
WORKDIR /app

# 安装系统依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ffmpeg \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# 安装 uv，用于加速依赖安装
RUN pip install --no-cache-dir uv

# 复制依赖定义文件
COPY pyproject.toml uv.lock ./

# 安装项目依赖（包含 PyTorch 等）
RUN uv pip install --system --no-cache .

# 复制项目代码
COPY . .

# 暴露 Gradio Web Demo 的端口
EXPOSE 8808

# 启动 Web Demo
CMD ["python", "app.py", "--port", "8808"]
