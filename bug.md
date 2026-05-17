# Bug 修复与经验总结

## 1. Dockerfile 依赖缺失导致编译失败
- **问题描述**：在 Docker 构建过程中，执行 `pip install .` 时报 `exit code: 1` 错误。
- **根本原因**：
  - 项目依赖的某些音频和机器学习库（如 `wetext`、`soundfile`）需要底层 C++ 编译环境。
  - 基础镜像 `nvidia/cuda` 或 `python:slim` 默认没有安装 `build-essential`（包含 gcc/g++）、`cmake`、`ninja-build` 和 `libsndfile1` 动态链接库。
- **解决方法**：
  - 在 `Dockerfile` 中，通过 `apt-get` 安装了 `build-essential`, `cmake`, `ninja-build`, `libsndfile1`, `python3.10-dev` 和 `curl`。
- **预防经验**：对于复杂的深度学习或音频处理项目，Dockerfile 中必须预装编译工具链和常见的音频系统库。

## 2. setuptools-scm 无法在 Docker 隔离环境中检测版本
- **问题描述**：在 `Dockerfile` 构建时，`pip install .` 提示 `LookupError: setuptools-scm was unable to detect version for /app`。
- **根本原因**：
  - `pyproject.toml` 配置了 `setuptools_scm` 动态获取 Git 提交记录来计算版本号。
  - Docker 构建早期阶段为了利用缓存，仅拷贝了 `pyproject.toml`，此时既没有 `.git` 文件夹，也没有其他源码。导致 `setuptools-scm` 检测不到 Git 历史，直接报错中断构建。
- **解决方法**：
  1. 使用 `uv pip compile pyproject.toml -o requirements.txt` 将依赖提前编译成 `requirements.txt`。
  2. 使用 `uv pip install -r requirements.txt` 安装所有第三方依赖（此步不需要项目源码，完美利用缓存层）。
  3. 拷贝源码后，在正式安装本项目前，设置环境变量 `ENV SETUPTOOLS_SCM_PRETEND_VERSION="0.0.0"`，强行指定虚拟版本号，再通过 `--no-deps` 快速安装项目本身：`RUN uv pip install --no-deps .`。
- **预防经验**：在 Docker 中打包包含 `setuptools-scm` 的 Python 项目时，必须伪装版本号环境变量（例如 `SETUPTOOLS_SCM_PRETEND_VERSION`），或者将依赖安装与项目自身构建完全解耦。

## 3. GitHub Actions 构建内存不足/速度慢
- **问题描述**：GitHub Actions Runner 内存有限（7GB），用 `pip` 安装大型依赖（如 PyTorch、Transformers）极易触发 OOM 并返回 `exit code 1`。
- **解决方法**：
  - 引入了 Rust 编写的超高速包管理工具 `uv`。在 Dockerfile 中通过 `uv pip install` 代替传统 `pip`，既加快了构建速度，又显著降低了内存使用，避免了 OOM 问题。

## 4. TTS主模型启动后默认运行在 CPU，未利用 GPU 加速
- **问题描述**：在容器启动时，控制台输出 `Running on device: cpu, dtype: bfloat16`，尽管使用的是 GPU 容器并且 CUDA 硬件加速正常可用，主合成模型仍然在 CPU 上缓慢推理。
- **根本原因**：
  - 在 `app.py` 中，调用 `voxcpm.VoxCPM.from_pretrained(self._model_id, optimize=True)` 时没有显式传入 `device` 参数。
  - 模型加载器 `from_pretrained` 收到 `device=None` 时，会自动解析 Hugging Face 模型的 `config.json` 配置文件。
  - 最新模型 `openbmb/VoxCPM2` 的 `config.json` 中配置的默认设备是 `"device": "cpu"`，这导致在没有显式指定设备的情况下，程序直接降级到 `cpu` 设备运行。
- **解决方法**：
  - 修改 `app.py`，在 `VoxCPMDemo.get_or_load_voxcpm()` 方法中，调用 `from_pretrained` 时显式传入 `device=self.device`（即当前检测到的 `"cuda"` 还是 `"cpu"`）。
- **预防经验**：在使用第三方深度学习加载器时，必须显式传入检测到或指定的 `device` 参数，绝对不能完全依赖其默认值，防止其静默回退到 `cpu` 或硬编码配置设备。

## 5. Host 宿主机未配置 NVIDIA Container Toolkit 导致容器内无法检测到 GPU 显卡
- **问题描述**：在运行带有 `--gpus all` 参数的 Docker 容器时，控制台输出 `WARNING: The NVIDIA Driver was not detected. GPU functionality will not be available. Use the NVIDIA Container Toolkit to start this container with GPU support`，导致容器退回到 CPU 运行模式。
- **根本原因**：
  - Docker 容器是高度隔离的，CUDA 库虽然已经完整安装在镜像中（`CUDA Version 12.1.1` 正常显示，证明镜像无误），但容器无法直接穿透并调用宿主机的物理 GPU。
  - 宿主机没有正确安装或配置 **NVIDIA Container Toolkit**（或在 Windows WSL2 下 Docker Desktop 的 GPU 加速支持没有生效），导致 Docker 守护进程（Daemon）无法将宿主机的 GPU 驱动和硬件资源映射进容器。
- **解决方法**：
  - **Linux 宿主机**：需要在宿主机安装 NVIDIA 官方驱动，并配置 NVIDIA Container Toolkit。
  - **Windows 宿主机**：
    1. 确保 Windows 宿主机安装了 NVIDIA 最新官方显卡驱动。
    2. 确保 Docker Desktop 设置中启用了 **WSL 2 based engine**。
    3. 在 Windows 终端中运行 `wsl --update` 将 WSL2 升级到支持 GPU 虚拟化的最新版本，并通过在 Windows PowerShell 运行 `nvidia-smi` 确认显卡可以被 WSL2 读取。
  - **显卡驱动版本过旧限制**：
    - 若容器内 PyTorch 报 `The NVIDIA driver on your system is too old (found version 12090)`，说明宿主机的物理 NVIDIA 显卡驱动版本低于当前 PyTorch 镜像编译时要求的 CUDA 最低驱动门槛（例如，Windows GPU 显卡驱动必须升级到 531.14 或更高版本以支持 CUDA 12.1+）。必须通过 NVIDIA 官方 GeForce/Studio 工具更新 Windows 主机的物理显卡驱动。
- **预防经验**：深度学习容器（如搭载 PyTorch CUDA 的镜像）在任何机器上运行时，必须首先确保**宿主机**配置好了 Docker GPU 硬件穿透桥梁且**驱动版本符合镜像内 PyTorch/CUDA 软件库的最低要求**，否则即使镜像内 CUDA 完美，也只能静默退回到 CPU 上。
