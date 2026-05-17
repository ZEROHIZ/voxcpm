@echo off
title VoxCPM2 Local Service Launcher

echo ==================================================================
echo     VoxCPM2 Local Service Launcher / Local Adaptive Bootstrapper
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

:: 3. Set version environment variable to prevent setuptools-scm build errors
set SETUPTOOLS_SCM_PRETEND_VERSION=0.0.0

:: 4. Check if uv is installed
where uv >nul 2>nul
if %errorlevel% neq 0 goto ERROR_NO_UV

:: 5. Check if virtual environment exists, if not create it
if not exist "%VENV_DIR%" goto CREATE_VENV

:CHECK_MARKER
:: 6. Install dependencies if not set up
if not exist "%MARKER_FILE%" goto INSTALL_DEPS

:: Self-healing: Check if PyTorch is actually working with CUDA inside the venv
%VENV_DIR%\Scripts\python -c "import torch; assert torch.cuda.is_available()" >nul 2>nul
if %errorlevel% neq 0 (
    echo [WARNING] PyTorch CUDA is not working in your local .venv. Reinstalling...
    del "%MARKER_FILE%" >nul 2>nul
    goto INSTALL_DEPS
)

:LAUNCH_APP
echo ==================================================================
echo     Starting speech service in local virtual environment...
echo ==================================================================
%VENV_DIR%\Scripts\python app.py --port 8808
goto END

:CREATE_VENV
echo [STATUS] Creating local isolated virtual environment (.venv)...
uv venv %VENV_DIR%
goto CHECK_MARKER

:INSTALL_DEPS
echo [STATUS] Installing CUDA 11.8 compatible PyTorch and Torchaudio...
uv pip install torch==2.5.1 torchaudio==2.5.1 --index-url https://download.pytorch.org/whl/cu118
if %errorlevel% neq 0 goto ERROR_INSTALL

echo [STATUS] Installing remaining project dependencies...
uv pip install -e . -i https://mirrors.aliyun.com/pypi/simple
if %errorlevel% neq 0 goto ERROR_INSTALL

echo setup_complete > "%MARKER_FILE%"
echo [SUCCESS] Local virtual environment successfully configured!
goto LAUNCH_APP

:ERROR_NO_UV
echo [ERROR] uv tool not found!
echo Please install uv first by running this in PowerShell:
echo   irm astral.sh/uv ^| iex
echo After installation, please restart your terminal or computer.
pause
exit /b 1

:ERROR_INSTALL
echo [ERROR] Dependency installation failed! Please check the output above.
pause
exit /b 1

:END
pause
