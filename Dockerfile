FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

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
    libsndfile1 \
    ffmpeg \
    git \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Set python3.10 as default python
RUN ln -s /usr/bin/python3.10 /usr/bin/python

# Set working directory
WORKDIR /app

# Copy dependency files first for caching
COPY pyproject.toml ./

# Install python dependencies
RUN pip install --no-cache-dir build setuptools wheel
RUN pip install --no-cache-dir .

# Copy the rest of the application
COPY . .

# Expose the default port
EXPOSE 8808

# Define the default command to run the app
CMD ["python", "app.py", "--port", "8808"]
