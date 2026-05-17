FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV HF_HOME=/app/data/huggingface
ENV MODELSCOPE_CACHE=/app/data/modelscope

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    python3.10-venv \
    python3.10-dev \
    build-essential \
    cmake \
    ninja-build \
    libsndfile1 \
    ffmpeg \
    git \
    wget \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set python3.10 as default python
RUN ln -s /usr/bin/python3.10 /usr/bin/python

# Install uv for fast package installation
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# Set working directory
WORKDIR /app

# Copy dependency files first for caching
COPY pyproject.toml ./

# Create constraints file to pin PyTorch and Torchaudio to CUDA 11.8 versions (preventing automatic upgrades to newer CUDA versions like 13.0)
RUN echo "torch==2.5.1+cu118" > constraints.txt && \
    echo "torchaudio==2.5.1+cu118" >> constraints.txt

# Compile and install python dependencies using uv (caches layers)
RUN uv pip compile pyproject.toml -c constraints.txt --extra-index-url https://download.pytorch.org/whl/cu118 --index-strategy unsafe-best-match -o requirements.txt
RUN uv pip install --system --no-cache -r requirements.txt --extra-index-url https://download.pytorch.org/whl/cu118 --index-strategy unsafe-best-match

# Copy the rest of the application
COPY . .

# Install the local package without reinstalling dependencies
ENV SETUPTOOLS_SCM_PRETEND_VERSION="0.0.0"
RUN uv pip install --system --no-cache --no-deps .

# Expose the default port
EXPOSE 8808

# Define the default command to run the app
CMD ["python", "app.py", "--port", "8808"]
