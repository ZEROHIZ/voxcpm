# VoxCPM API 接口文档

本项目基于 **Gradio** 框架运行，Gradio 默认提供了一套完整的 REST API 以及 Python/JS 客户端 SDK，允许其他服务以 HTTP 接口的形式调用语音生成功能。

---

## 1. 接口概述

* **接口类型**: REST API / Server-Sent Events (SSE) 或 WebSocket
* **默认基础 URL**: `http://localhost:8808`
* **Gradio API 名**: `generate`

---

## 2. 模型选择 (Model Selection)

在调用接口或启动服务时，可以通过以下方式选择不同的模型：

### A. 容器/命令行启动时选择
在启动容器或运行 `app.py` 时，可以通过 `--model-id` 参数指定主模型：
```bash
python app.py --model-id "openbmb/VoxCPM2" --port 8808
```
**可选主模型模型库 ID**：
- `openbmb/VoxCPM2` (默认)：最新一代的多语言 TTS 模型，支持更逼真的克隆和语音设计。
- `openbmb/VoxCPM`：第一代模型，运行速度可能较快，但克隆表现略逊于 V2。
- **本地路径**：你也可以传入本地已下载好的模型绝对路径，例如 `--model-id "/app/data/my_local_model"`。

### B. 系统辅助模型 (自动加载)
- **ASR 模型 (语音识别)**: 默认固定为 `iic/SenseVoiceSmall`，用于在“极致克隆”模式下自动识别上传的参考音频内容。
- **降噪增强模型**: 默认固定为 `iic/speech_zipenhancer_ans_multiloss_16k_base`。

---

## 3. REST API (HTTP POST) 接口调用方式

在 Gradio 4.x/5.x/6.x 版本中，标准的 HTTP 交互通过两步式请求（异步任务提交 + 状态查询，或直接通过 `/api/predict`）完成。

### 统一端点: `/api/predict` (推荐简单同步调用)

* **请求方式**: `POST`
* **请求 URL**: `http://localhost:8808/api/predict`
* **Content-Type**: `application/json`

#### 请求参数 (Request JSON)

请求体是一个 JSON 对象，包含 `data` 数组，数组里的值按 Gradio 界面组件的定义顺序传入：

```json
{
  "data": [
    "VoxCPM2 is a creative multilingual TTS model.", 
    "年轻女性，温柔甜美",
    null,
    false,
    "",
    2.0,
    true,
    false,
    10
  ],
  "fn_index": 2
}
```

**参数字段映射说明：**

| 索引 | 参数名 | 类型 | 必填 | 默认值 | 描述 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `data[0]` | `text` | String | 是 | - | **Target Text**: 准备合成的目标文本（中英文均可） |
| `data[1]` | `control_instruction` | String | 否 | `""` | **Control Instruction**: 声音描述控制文本。极致克隆模式下此项失效。 |
| `data[2]` | `reference_wav` | Object/Null | 否 | `null` | **Reference Audio**: 参考音频。如果不做声音克隆，传入 `null`；如需克隆，需先上传音频（见下文“音频上传接口”）并传入其 JSON 对象。 |
| `data[3]` | `use_prompt_text` | Boolean | 否 | `false` | **Ultimate Cloning Mode**: 是否开启极致克隆模式（基于参考音频的文字引导进行极致克隆）。 |
| `data[4]` | `prompt_text_value` | String | 否 | `""` | **Transcript**: 参考音频对应的文字内容。`use_prompt_text` 为 `true` 时必填。 |
| `data[5]` | `cfg_value` | Float | 否 | `2.0` | **CFG**: 引导强度。范围 `1.0 ~ 3.0`，数值越高越贴合提示词音色。 |
| `data[6]` | `do_normalize` | Boolean | 否 | `true` | **Text Normalization**: 是否对数字、日期及缩写进行规范化处理。 |
| `data[7]` | `denoise` | Boolean | 否 | `false` | **Denoise**: 克隆前是否对参考音频进行降噪增强。 |
| `data[8]` | `dit_steps` | Integer | 否 | `10` | **LocDiT steps**: 流匹配迭代步数。范围 `1 ~ 50`。步数越多质量可能越好，但速度变慢。 |

#### 响应格式 (Response JSON)

成功时，接口将返回生成的音频临时文件路径。

```json
{
  "data": [
    {
      "name": "/tmp/gradio/abcde12345.wav",
      "data": null,
      "is_file": true,
      "orig_name": "audio.wav",
      "mime_type": "audio/wav"
    }
  ],
  "duration": 2.45,
  "average_duration": 2.45
}
```

你可以通过 `http://localhost:8808/file=/tmp/gradio/abcde12345.wav` 路径直接下载生成的音频文件。

---

## 4. 上传参考音频文件接口

如果你需要调用“声音克隆”功能，必须先通过 Gradio 的文件上传接口，把本地音频上传到服务器，获取服务器上的临时路径。

* **请求方式**: `POST`
* **请求 URL**: `http://localhost:8808/upload`
* **Content-Type**: `multipart/form-data`

#### 请求示例 (curl)
```bash
curl -X POST -F "files=@/path/to/my_voice.wav" http://localhost:8808/upload
```

#### 响应示例 (JSON)
```json
[
  "C:\\Users\\Admin\\AppData\\Local\\Temp\\gradio\\my_voice.wav"
]
```
获取到此路径后，将其填入上方合成请求中的 `data[2]` (即 `reference_wav`) 位置即可。

---

## 5. SDK 调用方式 (极力推荐，最简单)

除了手动构造 HTTP POST 请求外，Gradio 官方提供了 **Python** 和 **JavaScript** 的极简轻量级 SDK，推荐使用它们来调用接口：

### A. Python 调用示例

首先安装客户端 SDK（无需安装 PyTorch 等重度依赖）：
```bash
pip install gradio_client
```

然后编写调用代码：
```python
from gradio_client import Client, handle_file

# 初始化客户端，连接到你的 VoxCPM 服务
client = Client("http://localhost:8808")

# 1. 声音设计 (Voice Design) 模式调用示例
result_audio_path = client.predict(
    text="你好，这是一段使用 API 生成的声音设计演示。",   # data[0] - Target Text
    control_instruction="年轻女性，温柔甜美，充满活力",        # data[1] - Control Instruction
    reference_wav_path=None,                             # data[2] - 无参考音频
    use_prompt_text=False,                               # data[3] - 不使用极致克隆
    prompt_text_value="",                                # data[4] - 无参考文字
    cfg_value_input=2.0,                                 # data[5] - CFG
    do_normalize=True,                                   # data[6] - 文本规范化
    denoise=False,                                       # data[7] - 降噪
    dit_steps=10,                                        # data[8] - 迭代步数
    api_name="/generate"                                 # 指定调用的 API 名称
)

print(f"生成的音频保存在: {result_audio_path}")

# 2. 极致克隆 (Ultimate Cloning) 模式调用示例
# 传入本地参考音频文件
ref_audio = handle_file("D:/voices/my_voice.wav")

result_clone_path = client.predict(
    text="你好，这是极致克隆的声音，听起来是不是很像你？",
    control_instruction="",                              # 极致克隆模式下此项无效
    reference_wav_path=ref_audio,                        # 传入参考音频
    use_prompt_text=True,                                # 开启极致克隆模式
    prompt_text_value="这是我录制的一段原始参考声音。",   # 传入参考音频对应的文字内容
    cfg_value_input=2.0,
    do_normalize=True,
    denoise=True,                                        # 开启参考音频降噪
    dit_steps=15,
    api_name="/generate"
)

print(f"克隆 of 音频保存在: {result_clone_path}")
```

### B. JavaScript / Node.js 调用示例

首先安装包：
```bash
npm install @gradio/client
```

代码示例：
```javascript
import { Client } from "@gradio/client";

const client = await Client.connect("http://localhost:8808");

const response = await client.predict("/generate", {
    text_input: "Hello world from JavaScript API!",
    control_instruction: "A mature gentleman with a deep, soothing voice.",
    reference_wav_path: null,
    show_prompt_text: false,
    prompt_text: "",
    cfg_value_input: 2.0,
    do_normalize: true,
    denoise: false,
    inference_timesteps: 10
});

console.log("Generated audio file URL:", response.data[0]);
```
