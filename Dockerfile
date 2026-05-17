FROM python:3.10-slim

# 设置工作目录
WORKDIR /app

# 安装必要的系统依赖库
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ffmpeg \
    build-essential \
    curl \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# 安装 uv
RUN pip install --no-cache-dir uv

# 创建并激活虚拟环境 (遵循在虚拟环境安装的规则)
ENV VIRTUAL_ENV=/opt/venv
RUN uv venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# 复制依赖文件
COPY pyproject.toml uv.lock ./

# 在虚拟环境中安装项目依赖
# 添加了 PyTorch 官方源，因为 torchcodec 和 torch 在官方源中编译得更完整，能解决构建失败的问题
RUN uv pip install --no-cache . --extra-index-url https://download.pytorch.org/whl/cu121

# 复制项目代码
COPY . .

# 暴露端口
EXPOSE 8808

# 启动 Web Demo
CMD ["python", "app.py", "--port", "8808"]
