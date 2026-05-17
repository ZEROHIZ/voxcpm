FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV HF_HOME=/app/data/huggingface
ENV MODELSCOPE_CACHE=/app/data/modelscope
ENV SETUPTOOLS_SCM_PRETEND_VERSION="0.0.0"

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

# Set working directory
WORKDIR /app

# Copy the entire application code
COPY . .

# Make entrypoint script executable
RUN chmod +x entrypoint.sh

# Expose the default port
EXPOSE 8808

# Define the entrypoint to run our self-adaptive bootstrap script
ENTRYPOINT ["./entrypoint.sh"]
