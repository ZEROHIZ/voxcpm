FROM python:3.10-slim

# 设置工作目录
WORKDIR /app

# 安装必要的系统依赖库
# 补充了 cmake，很多 Python 音频/文本处理包（如 wetext）在编译时依赖 cmake
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ffmpeg \
    build-essential \
    curl \
    python3-dev \
    cmake \
    && rm -rf /var/lib/apt/lists/*

# 安装 uv
RUN pip install --no-cache-dir uv

# 创建并激活虚拟环境 (遵循在虚拟环境安装的规则)
ENV VIRTUAL_ENV=/opt/venv
RUN uv venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# 复制完整的项目代码
COPY . .

# 设定一个默认的版本号，防止 setuptools_scm 在 Docker 无 git 历史的情况下报错
ENV SETUPTOOLS_SCM_PRETEND_VERSION="1.0.0"

# 在虚拟环境中安装项目依赖，加入 -v 打印详细日志以便排错
RUN uv pip install -v --no-cache . --extra-index-url https://download.pytorch.org/whl/cu121

# 暴露端口
EXPOSE 8808

# 启动 Web Demo
CMD ["python", "app.py", "--port", "8808"]
