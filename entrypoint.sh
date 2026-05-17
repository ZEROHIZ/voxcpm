#!/bin/bash
set -e

# Limit CPU threads to prevent CPU exhaustion and container crashes under WSL2 / Docker
export OMP_NUM_THREADS=4
export MKL_NUM_THREADS=4
export OPENBLAS_NUM_THREADS=4
export VECLIB_MAXIMUM_THREADS=4
export NUMEXPR_NUM_THREADS=4

# Path to the persistent virtual environment and setup marker
VENV_DIR="/app/data/venv"
MARKER_FILE="$VENV_DIR/.setup_complete"

echo "=================================================================="
echo "    📦 VoxCPM Container Self-Adaptive Bootstrap / 自适应引导启动 📦   "
echo "=================================================================="

# Check if venv exists, if not, create it
if [ ! -d "$VENV_DIR" ]; then
    echo " 🔹 Creating persistent Python virtual environment at: $VENV_DIR"
    python3 -m venv "$VENV_DIR"
fi

# Activate the persistent venv
echo " 🔹 Activating virtual environment..."
source "$VENV_DIR/bin/activate"

# Ensure pip is up to date inside the venv using domestic mirror
pip install --upgrade pip -i https://mirrors.aliyun.com/pypi/simple --quiet

# Function to detect CUDA version supported by host driver
detect_cuda_version() {
    # Check if nvidia-smi exists and is working
    if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
        # Extract maximum supported CUDA version from nvidia-smi output
        local ver
        ver=$(nvidia-smi | grep -oP "CUDA Version:\s*\K[\d\.]+")
        if [ -n "$ver" ]; then
            echo "$ver"
            return 0
        fi
    fi
    # If nvidia-smi fails, check if the NVIDIA kernel modules are loaded
    if [ -d "/proc/driver/nvidia" ]; then
        # Try to read driver version
        local drv_ver
        drv_ver=$(cat /proc/driver/nvidia/version 2>/dev/null | grep -oP "Kernel Module\s+\K[\d\.]+")
        if [ -n "$drv_ver" ]; then
            # Check the major version of the driver to infer CUDA compatibility
            local major
            major=$(echo "$drv_ver" | cut -d. -f1)
            if [ "$major" -ge 525 ]; then
                echo "12.0"
                return 0
            elif [ "$major" -ge 515 ]; then
                echo "11.8"
                return 0
            fi
        fi
    fi
    echo "cpu"
    return 1
}

# Run GPU detection
echo " 🔍 Checking GPU and NVIDIA host driver status..."
CUDA_SUPPORTED=$(detect_cuda_version)

echo " 🔹 Maximum supported CUDA version by host driver: $CUDA_SUPPORTED"

# Decide which index URL to use based on supported CUDA version
INDEX_URL="https://pypi.org/simple"
PYTORCH_INDEX_URL=""

if [ "$CUDA_SUPPORTED" = "cpu" ]; then
    echo " 🟢 Target Build: CPU-only fallback mode"
    PYTORCH_INDEX_URL="https://download.pytorch.org/whl/cpu"
    TARGET_CUDA="cpu"
else
    # Check if CUDA version is >= 12.1
    # Bash doesn't do float compare natively, so we do it via python which is already installed
    IS_GE_12_1=$(python3 -c "
import sys
ver = '$CUDA_SUPPORTED'
try:
    v_parts = [int(x) for x in ver.split('.')]
    print('true' if v_parts >= [12, 1] else 'false')
except Exception:
    print('false')
")

    if [ "$IS_GE_12_1" = "true" ]; then
        echo " 🟢 Target Build: CUDA 12.1+ GPU acceleration mode"
        # PyTorch 2.5 has extremely stable wheels for cu121
        PYTORCH_INDEX_URL="https://download.pytorch.org/whl/cu121"
        TARGET_CUDA="12.1"
    else
        echo " 🟢 Target Build: CUDA 11.8 GPU compatibility mode"
        PYTORCH_INDEX_URL="https://download.pytorch.org/whl/cu118"
        TARGET_CUDA="11.8"
    fi
fi

# Determine if we need to perform dependency setup
SHOULD_SETUP=true
if [ -f "$MARKER_FILE" ]; then
    RECORDED_CUDA=$(cat "$MARKER_FILE")
    if [ "$RECORDED_CUDA" = "$TARGET_CUDA" ]; then
        # Check if torch is actually working
        if python3 -c "import torch; import torchaudio" &>/dev/null; then
            echo " 🟢 Perfect Match! Persistent virtual environment is fully initialized ($TARGET_CUDA)."
            SHOULD_SETUP=false
        else
            echo " ⚠️  Persistent virtual environment exists but PyTorch is broken. Re-running setup..."
        fi
    else
        echo " ⚠️  Host GPU hardware/driver changes detected (Prev: $RECORDED_CUDA, Current: $TARGET_CUDA). Re-running setup..."
    fi
fi

if [ "$SHOULD_SETUP" = "true" ]; then
    echo " 🔹 Setting up persistent virtual environment..."
    echo " 📥 Downloading and installing PyTorch/Torchaudio tailored to your GPU ($TARGET_CUDA)..."
    
    # Install torch & torchaudio from targeted PyTorch wheel repository
    pip install --no-cache-dir \
        torch==2.5.1 torchaudio==2.5.1 \
        --index-url "$PYTORCH_INDEX_URL"
        
    echo " 📥 Installing remaining python dependencies from pyproject.toml..."
    # Install the project and all other dependencies in editable mode using high-speed Alibaba Cloud mirror
    # Since torch/torchaudio are already installed in the virtual environment, they will be skipped.
    pip install --no-cache-dir -e . -i https://mirrors.aliyun.com/pypi/simple
    
    # Write setup complete marker file
    echo "$TARGET_CUDA" > "$MARKER_FILE"
    echo " 🟢 Persistent virtual environment successfully configured ($TARGET_CUDA)!"
fi

echo "=================================================================="
echo "    🚀 Launching VoxCPM App Service / 启动语音服务 🚀   "
echo "=================================================================="

# Run the app in a loop to handle forced restarts (exit code 3)
while true; do
    python app.py "$@"
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 3 ]; then
        echo "=================================================================="
        echo "    [RESTART] Force restart signal detected (exit code 3)."
        echo "              Re-launching application now..."
        echo "=================================================================="
        sleep 2
    else
        exit $EXIT_CODE
    fi
done
