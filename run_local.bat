@echo off
chcp 65001 >nul
title VoxCPM2 Local Service Launcher / 本地极速自适应启动器

echo ==================================================================
echo     🚀 VoxCPM2 Local Service Launcher / 本地极速自适应启动器 🚀
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

:: 3. Check if uv is installed
where uv >nul 2>nul
if %errorlevel% neq 0 (
    echo [错误] 未在系统环境变量中检测到 uv 工具！
    echo 请先安装 uv（打开 PowerShell 并运行: irm astral.sh/uv ^| iex ）
    echo 安装完成后请重启此终端再运行。
    pause
    exit /b 1
)

:: 4. Check if virtual environment exists, if not create it
if not exist "%VENV_DIR%" (
    echo 🔹 正在创建本地隔离虚拟环境 (.venv)...
    uv venv %VENV_DIR%
)

:: 5. Install dependencies if not set up
if not exist "%MARKER_FILE%" (
    echo 🔹 正在通过 uv 高速安装 CUDA 11.8 兼容版 PyTorch 与 Torchaudio...
    uv pip install torch==2.5.1 torchaudio==2.5.1 --index-url https://download.pytorch.org/whl/cu118
    
    echo 🔹 正在通过阿里云高速镜像源安装项目其他全部依赖...
    uv pip install -e . -i https://mirrors.aliyun.com/pypi/simple
    
    echo setup_complete > "%MARKER_FILE%"
    echo 🟢 本地虚拟环境及依赖配置成功！
)

echo ==================================================================
echo     🚀 正在使用本地虚拟环境极速拉起语音服务...
echo ==================================================================

:: 6. Launch the app using uv
uv run python app.py --port 8808

pause
