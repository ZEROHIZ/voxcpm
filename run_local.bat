@echo off
title VoxCPM2 Local Service Launcher

echo ==================================================================
echo     🚀 VoxCPM2 Local Service Launcher 🚀
echo ==================================================================

:: 1. Define paths
set VENV_DIR=.venv
set MARKER_FILE=.venv\.setup_complete

:: 2. Limit CPU threads to prevent CPU spikes and Windows host lag
set OMP_NUM_THREADS=4
set MKL_NUM_THREADS=4
set OPENBLAS_NUM_THREADS=4
set VECLIB_MAXIMUM_THREADS=4
set NUMEXPR_NUM_THREADS=4

:: 3. Set setuptools-scm pretend version to bypass git metadata lookup error
set SETUPTOOLS_SCM_PRETEND_VERSION=0.0.0

:: 4. Check if uv is installed
where uv >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] uv tool was not found in your system PATH!
    echo Please install uv first. In PowerShell run:
    echo     irm astral.sh/uv ^| iex
    echo After installation is complete, restart this terminal.
    pause
    exit /b 1
)

:: 5. Check if virtual environment exists, if not create it
if not exist "%VENV_DIR%" (
    echo [*] Creating isolated virtual environment (.venv)...
    uv venv %VENV_DIR%
)

:: 6. Install dependencies if not set up
if not exist "%MARKER_FILE%" (
    echo [*] Installing CUDA 11.8 compatible PyTorch and Torchaudio...
    uv pip install torch==2.5.1 torchaudio==2.5.1 --index-url https://download.pytorch.org/whl/cu118
    
    echo [*] Installing remaining project dependencies via high-speed Alibaba mirror...
    uv pip install -e . -i https://mirrors.aliyun.com/pypi/simple
    
    echo setup_complete > "%MARKER_FILE%"
    echo [SUCCESS] Local virtual environment successfully configured!
)

echo ==================================================================
echo     🚀 Launching VoxCPM2 Service...
echo ==================================================================

:: 7. Launch the app using uv
uv run python app.py --port 8808

pause
