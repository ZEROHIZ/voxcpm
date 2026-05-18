# VoxCPM2 OpenAI 兼容接口文档 (OpenAI-Compatible API)

为了方便将 **VoxCPM2** 轻松对接至各种现有的 AI Agent 平台（如 Dify、FastGPT、LangChain 等）或各种标准客户端，本项目提供了一个运行在本地原生 Windows 端的轻量级 **OpenAI 兼容语音合成 API 网关**。

该网关运行在本地已有的虚拟环境中，**无需安装 Linux 环境、WSL2 或繁重的 `vllm-omni` 推理框架**，即可让您享受标准的 `/v1/audio/speech` 接口体验。

---

## 🚀 1. 快速启动指南

### 方式 A：双击一键启动（推荐）
在项目根目录中，直接双击运行：
👉 **[run_openai_api.bat](file:///d:/daima/VoxCPM-main/run_openai_api.bat)**

### 方式 B：命令行手动启动
打开终端（如 PowerShell），在根目录下运行以下命令：
```powershell
# 启动 API 服务（自动激活本地虚拟环境 .venv）
.venv\Scripts\python openai_api.py
```

服务启动成功后，默认会监听 **`http://localhost:8089`**，接口端点为 **`http://localhost:8089/v1/audio/speech`**。

---

## 🎛️ 2. 接口参数规范说明

向 `POST /v1/audio/speech` 发送 JSON 请求时，除了支持 OpenAI 官方标准参数外，还针对 VoxCPM2 的“声音设计”与“声音克隆”定制了高阶扩展参数：

### 参数列表
| 参数名称 | 类型 | 必填 | 默认值 | 详细说明 |
| :--- | :--- | :---: | :--- | :--- |
| **`model`** | String | **是** | - | 模型标识符，固定为 `"openbmb/VoxCPM2"`。 |
| **`input`** | String | **是** | - | 目标合成文本（您想要让模型说出的话）。 |
| **`voice`** | String | 否 | `"default"` | 预设说话人角色。 |
| **`speed`** | Float | 否 | `1.0` | 语速倍率（支持 `0.25 ~ 4.0`）。 |
| **`response_format`** | String | 否 | `"mp3"` | 返回的音频格式。支持：`"mp3"`, `"wav"`, `"flac"`, `"opus"`。 |
| **`instructions`** | String | 否 | `""` | **【声音设计 / 风格控制】**<br>描述说话风格、语气、情绪或音色特征（如 `"年轻女性，温柔甜美，语速缓慢"`）。若不提供参考音频，则直接根据该文字凭空生成新音色。 |
| **`ref_audio`** | String | 否 | `null` | **【声音克隆】**<br>参考音频数据。支持：<br>1. **公网音频 URL**（如 `https://.../sample.wav`）<br>2. **Base64 编码的 Data URI**（如 `data:audio/wav;base64,...`）<br>3. **纯 Base64 字符串**。<br>4. **服务器本地文件绝对路径**（如 `D:\audio.wav` 或物理上传后返回的 `temp_upload_xxx.wav` 路径，系统会自动识别本地文件并智能读取）。 |
| **`ref_text`** | String | 否 | `null` | **【极致克隆引导文本】**<br>参考音频 `ref_audio` 所对应的原始说出的话。提供后将开启“极致克隆模式”，完美还原参考音频中的所有情感和音色细节。 |
| **`task_type`** | String | 否 | `"CustomVoice"` | 任务类型：`"Base"` (标准/设计模式)，`"CustomVoice"` (极致克隆模式)。 |
| **`language`** | String | 否 | `"Auto"` | 合成文本的语种（默认自动识别）。 |
| **`cfg_value`** | Float | 否 | `2.0` | **【高级设置：引导强度 (CFG)】**<br>数值越高，声音越贴合参考音色/文字引导词；数值越低，生成风格与情绪起伏更自由。（范围：`1.0 ~ 3.0`） |
| **`do_normalize`** | Boolean | 否 | `false` | **【高级设置：文本规范化】**<br>是否开启文本自动规范化（如将 "100" 自动转为 "一百"），基于 wetext。（默认：`false`，与 WebUI 默认关闭状态保持一致） |
| **`denoise`** | Boolean | 否 | `false` | **【高级设置：降噪增强】**<br>在极致克隆前，是否使用 ZipEnhancer 对参考音频进行高质量降噪预处理。（默认：`false`） |
| **`inference_timesteps`** | Integer | 否 | `20` | **【高级设置：LocDIT 迭代步数】**<br>流匹配迭代步数。步数越多，生成音质越好，但速度会变慢。（默认：`20`，推荐：`10 ~ 50`） |


### 🎙️ 声音克隆参考音频黄金法则 (最佳时长与规范)

对于极致克隆（`CustomVoice`），参考音频的**质量**与**时长**是决定克隆相似度和生成稳定性的关键：

* **🌟 最佳推荐时长**：**5 秒 ~ 10 秒**。这是最完美的甜美区间，能让模型完整捕捉说话人的音色嵌入（Speaker Embedding）与韵律特征，且合成速度最快、显存占用最少。
* **⚠️ 最短时长限制**：**不建议低于 3 秒**。低于 3 秒信息量严重匮乏，极易导致克隆出的声音出现“电音”、沙哑杂音或音色漂移。
* **⛔ 最长时长上限**：**硬性限制 30 秒以内**。超过 30 秒不仅不会提升相似度，反而会因为注意力上下文超长导致 GPU 显存暴涨（带来严重的 OOM 爆显存风险），并成倍拉慢推理时间。
* **📻 音频环境规范**：
  1. **绝对干净无杂音**：录音环境必须安静，不能有背景音乐（BGM）、其他人的说话声、风噪或强烈的房间回音。任何背景杂音都会被模型当作“音色特征的一部分”无情地克隆，导致输出的语音夹杂沙沙声。
  2. **提供 `ref_text`**：在极致克隆时，强烈建议准确提供参考音频中原本说的那句文本。字词精准对齐能激发最完美的还原度和感情起伏。

---

## 📤 3. 物理文件上传接口 (Multipart Upload API)

当您在**跨机器**调用 API，且不想在客户端处理复杂的 Base64 编解码时，可以使用此接口先将客户端本地的音频文件物理上传给服务器，获得服务器的本地路径，再传给 `speech` 接口进行克隆。

### 请求信息
* **接口端点**：`POST http://localhost:8089/v1/audio/upload`
* **内容类型**：`multipart/form-data`
* **支持格式**：`.wav`, `.mp3`, `.flac`, `.ogg`, `.m4a`, `.aac`

### 💻 cURL 上传示例
```bash
curl -X POST http://localhost:8089/v1/audio/upload \
  -F "file=@/path/to/your_voice.wav"
```

#### 接口响应 JSON
```json
{
  "file_path": "D:\\daima\\VoxCPM-main\\data\\uploads\\temp_upload_d6f8e7a0b1c2.wav"
}
```

### 💻 Python 客户端上传与克隆联调示例
```python
import requests

# 1. 物理上传本地音频文件
upload_url = "http://localhost:8089/v1/audio/upload"
files = {"file": open("my_voice.wav", "rb")}
upload_res = requests.post(upload_url, files=files).json()

server_audio_path = upload_res["file_path"]
print(f"服务器缓存路径: {server_audio_path}")

# 2. 将服务器返回的绝对路径传给 OpenAI SDK 进行极致克隆
from openai import OpenAI
client = OpenAI(base_url="http://localhost:8089/v1", api_key="none")

response = client.audio.speech.create(
    model="openbmb/VoxCPM2",
    voice="default",
    input="我已经成功将物理文件上传并完美克隆！",
    response_format="wav",
    extra_body={
        "ref_audio": server_audio_path,  # 直接使用返回的物理路径！
        "ref_text": "参考音频的文字内容",
        "task_type": "CustomVoice"
    }
)
response.stream_to_file("upload_cloned_output.wav")
```

 > [!NOTE]
> **生命周期说明**：通过此接口上传的物理文件会被保存在服务器的 `data/uploads/` 目录下。为了最大化保障隐私与磁盘健康，当对应的 `speech` 合成任务结束（或发生任何运行错误报错）后，**服务器会自动在 1 毫秒内物理删除此缓存文件**，确保不占用磁盘空间。

---

## 💻 4. 多场景客户端调用示例

### 🎨 场景一：极简调用（标准 OpenAI TTS）
使用最基本的参数，系统将使用默认音色直接生成语音。

#### cURL 请求
```bash
curl http://localhost:8089/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{
    "model": "openbmb/VoxCPM2",
    "input": "您好！这是通过本地 API 网关极速合成的标准语音文件。",
    "response_format": "wav"
  }' \
  --output default_tts.wav
```

#### Python SDK 调用
```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8089/v1",
    api_key="none"  # API 密钥可以填任意字符串
)

response = client.audio.speech.create(
    model="openbmb/VoxCPM2",
    voice="default",
    input="您好！这是通过 OpenAI Python SDK 极速合成的标准语音文件。",
    response_format="wav"
)
response.stream_to_file("default_tts.wav")
```

---

### 🎭 场景二：声音设计（Voice Design）
不上传音频，完全通过 `instructions`（控制指令）描述您梦想中的声音。

#### cURL 请求
```bash
curl http://localhost:8089/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{
    "model": "openbmb/VoxCPM2",
    "input": "我是一只傲娇的猫咪，主人，你今天为什么这么晚才回来伺候我？",
    "instructions": "年轻女孩，声音软萌甜美，带着一丝傲娇、嗔怪的语气，语速偏慢。",
    "response_format": "wav"
  }' \
  --output tsundere_cat.wav
```

#### Python SDK 调用
对于自定义的高阶扩展参数（如 `instructions`），您可以通过官方 SDK 的 **`extra_body`** 字段无缝传递：
```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8089/v1",
    api_key="none"
)

response = client.audio.speech.create(
    model="openbmb/VoxCPM2",
    voice="default",
    input="我是一只傲娇的猫咪，主人，你今天为什么这么晚才回来伺候我？",
    response_format="wav",
    extra_body={
        "instructions": "年轻女孩，声音软萌甜美，带着一丝傲娇、嗔怪的语气，语速偏慢。"
    }
)
response.stream_to_file("tsundere_cat.wav")
```

---

### 🎙️ 场景三：极致声音克隆（Voice Cloning）
上传一段您想要模仿的人声，并输入那段人声的转录文字进行“极致克隆”。

#### cURL 请求（支持 Base64 或 URL）
```bash
curl http://localhost:8089/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{
    "model": "openbmb/VoxCPM2",
    "input": "我已经成功克隆了你的声音！接下来，我们将用这个声音进行后续的对话。",
    "ref_audio": "https://your-domain.com/sample.wav",
    "ref_text": "参考音频原作者说出来的原始文本文字",
    "task_type": "CustomVoice",
    "response_format": "wav"
  }' \
  --output cloned_voice.wav
```

#### Python SDK 调用
```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8089/v1",
    api_key="none"
)

# 传入参考音频的公网 URL 或是本地音频转换为 Base64 URI
ref_audio_url = "https://your-domain.com/sample.wav"  

response = client.audio.speech.create(
    model="openbmb/VoxCPM2",
    voice="default",
    input="我已经成功克隆了你的声音！接下来，我们将用这个声音进行后续的对话。",
    response_format="wav",
    extra_body={
        "ref_audio": ref_audio_url,
        "ref_text": "参考音频原作者说出来的原始文本文字",
        "task_type": "CustomVoice"
    }
)
response.stream_to_file("cloned_voice.wav")
```

---

## 🛠️ 5. 第三方平台对接指南

由于本接口完全兼容 OpenAI 的 `/v1/audio/speech` 规范，因此非常容易对接进任何第三方 AI 编排平台：

### 在 Dify / FastGPT 中接入
1. **添加自定义模型供应商**：选择 **OpenAI 兼容**。
2. **API 基础 URL (Base URL)**：填写 `http://localhost:8089/v1` 或 `http://<您的局域网IP>:8089/v1`。
3. **API Key**：可填写任意字符（如 `none`）。
4. **支持模型**：添加 `"openbmb/VoxCPM2"` 到文本转语音 (TTS) 模型列表中。
5. 保存后，即可在工作流或聊天应用中直接启用 VoxCPM2 进行实时语音合成和播报！
