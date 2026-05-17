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
