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

# ！！！将完整的项目代码（包括 src 源码和 .git）复制进来！！！
# 因为 uv pip install . 需要读取完整的项目源码才能完成自身包 (voxcpm) 的构建。
COPY . .

# 在虚拟环境中安装项目依赖，加入 -v 打印详细日志以便排错
RUN uv pip install -v --no-cache . --extra-index-url https://download.pytorch.org/whl/cu121

# 暴露端口
EXPOSE 8808

# 启动 Web Demo
CMD ["python", "app.py", "--port", "8808"]
