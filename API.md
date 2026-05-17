# VoxCPM API 接口文档与模型说明

本文档详细介绍了 VoxCPM (v2) 的 API 接口使用方法，包含标准的 HTTP (JSON) 接口定义、客户端 SDK 调用示例（Python & JavaScript），以及模型选择说明。

---

## 1. 模型选择说明 (Model Selection)

在启动 VoxCPM 容器或本地服务时，你可以通过 `--model-id` 命令行参数指定主模型。项目在启动或被首次调用时，会根据你的选择**全自动从云端下载（首次）**并在本地的 `data` 目录缓存。

### A. 主模型（TTS / 语音合成）
| 模型 ID | 模型大小/架构 | 语言支持 | 特点与适用场景 |
| :--- | :--- | :--- | :--- |
| **`openbmb/VoxCPM2`** *(默认)* | 750M / LocDiT | 中、英、粤、日等多语言 | **最新二代模型**。支持“极致克隆”（仅需参考音频与文字即可完美还原节奏、语气、音色）、“可控克隆”（通过文本提示词控制音色与情感）、“声音设计”（无需参考音频，直接从零用文字描述声音）。效果极佳，强烈推荐。 |
| **`openbmb/VoxCPM`** | 450M / Base | 中、英文为主 | **一代基础模型**。推理速度较快，对硬件配置要求稍低，但声音细节和控制力没有二代强。 |

### B. 辅助模型（自动加载）
项目运行中还会自动加载并选用以下辅助模型，它们也默认缓存至 `data` 目录下：
- **ASR 自动语音识别模型**: `iic/SenseVoiceSmall` (阿里通义实验室出品，用于在“极致克隆模式”下自动将你上传的参考音频转化为文本，高精度、极速)。
- **音频降噪增强模型**: `iic/speech_zipenhancer_ans_multiloss_16k_base` (阿里 ZipEnhancer 降噪模型，在高级设置中开启“降噪”后，用于清洗你的参考音频以消除杂音)。

---

## 2. API 接口规范 (HTTP REST API)

通过 Docker 或本地启动服务后，你可以直接使用标准的 HTTP POST 协议向服务发送请求。

### 请求地址
- **POST** `http://<your-ip>:8808/api/predict`
- **Headers**: `Content-Type: application/json`

### 请求数据格式 (JSON)
```json
{
  "data": [
    "VoxCPM2 is a creative multilingual TTS model from ModelBest.", 
    "A soft, sweet girl speaks slowly.", 
    null, 
    false, 
    "", 
    2.0, 
    false, 
    false, 
    10
  ],
  "event_data": null,
  "fn_index": 0,
  "trigger_id": null
}
```

#### 请求参数 `data` 数组说明：
| 数组索引 | 参数名称 | 类型 | 是否必填 | 默认值 | 详细说明与取值范围 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `[0]` | `text` | String | **是** | - | **目标文本**：需要合成语音的文字内容。 |
| `[1]` | `control_instruction` | String | 否 | `""` | **控制指令**：用文字描述想要的说话风格（如 `"年轻女性，温柔甜美"` 或 `"A lazy drawl"`）。使用极致克隆模式时将被忽略。 |
| `[2]` | `reference_wav` | Object/Null | 否 | `null` | **参考音频**：用于克隆的参考音频文件。如果为空表示进行“声音设计”；如果不为空，传入格式为 `{"path": "/tmp/xxx.wav"}` (上传到服务器上的文件路径)。 |
| `[3]` | `show_prompt_text` | Boolean | 否 | `false` | **极致克隆模式开关**：`true` 表示开启“极致克隆模式”；`false` 为普通模式。 |
| `[4]` | `prompt_text` | String | 否 | `""` | **参考音频文本内容**：仅在 `show_prompt_text` 为 `true` 时有效。输入参考音频中说出的文字。 |
| `[5]` | `cfg_value` | Float | 否 | `2.0` | **CFG 引导强度**：取值范围 `1.0 ~ 3.0`。数值越高，越贴合参考音色/指令；数值越低，生成的声音更有创造力与多样性。 |
| `[6]` | `DoNormalizeText` | Boolean | 否 | `false` | **文本规范化开关**：`true` 会自动将数字、日期及缩写（如 "2026" 变为 "二零二六"）规范化后再进行合成。 |
| `[7]` | `DoDenoisePromptAudio`| Boolean | 否 | `false` | **参考音频降噪增强**：`true` 表示克隆前自动使用 ZipEnhancer 进行背景降噪。 |
| `[8]` | `dit_steps` | Integer | 否 | `10` | **流匹配迭代步数**：取值 `1 ~ 50`。步数越多音频质量越细腻，但生成速度会变慢。通常默认 10 步已足够好。 |

---

### 响应数据格式 (JSON)
当请求成功时，API 会返回包含生成的音频文件信息的 JSON 数据。

```json
{
  "data": [
    {
      "name": "/tmp/gradio/7a9f82bc72ea13bd94f8da.wav",
      "data": null,
      "size": 182390,
      "is_file": true,
      "orig_name": "audio.wav",
      "mime_type": "audio/wav"
    }
  ],
  "duration": 1.25,
  "average_duration": 1.25
}
```

#### 响应字段说明：
- `data[0].name`: 生成的 `.wav` 音频文件在服务器/容器内的临时路径。你可以通过 `http://<your-ip>:8808/file=/tmp/gradio/7a9f82bc72ea13bd94f8da.wav` 路径将其直接下载或播放。
- `size`: 生成的音频大小（字节数）。
- `mime_type`: 音频的 MIME 类型，默认为 `audio/wav`。

---

## 3. 客户端调用示例 (Client SDK Examples)

最方便的集成方式是直接使用 Gradio 官方的轻量级客户端 SDK。

### A. Python 调用示例

首先安装依赖：
```bash
pip install gradio_client
```

编写调用代码：
```python
from gradio_client import Client, handle_file

# 1. 连接服务（本地启动或容器 IP）
client = Client("http://localhost:8808")

# 场景一：纯声音设计（不上传参考音频，完全由文字描述生成新声音）
result_design_path = client.predict(
    text="你好，这是一段完全通过文字描述定制生成的新声音。",
    control_instruction="温文尔雅的中年男子，语气缓慢深沉。",
    reference_wav_path=None,
    show_prompt_text=False,
    prompt_text="",
    cfg_value_input=2.0,
    do_normalize=True,
    denoise=False,
    dit_steps=10,
    api_name="/generate"
)
print(f"声音设计生成的音频保存在: {result_design_path}")

# 场景二：极致克隆（基于文本引导克隆，完美还原所有呼吸、节奏细节）
result_clone_path = client.predict(
    text="这是要合成的目标文本：人类的科技真是不堪一击。",
    control_instruction="",                              # 极致克隆会禁用该参数
    reference_wav_path=handle_file("my_voice_ref.wav"),  # 你的本地参考音频
    show_prompt_text=True,                               # 开启极致克隆模式
    prompt_text="这是我录制的一段原始参考声音。",         # 传入参考音频对应的文字内容
    cfg_value_input=2.0,
    do_normalize=True,
    denoise=True,                                        # 开启参考音频降噪
    dit_steps=15,
    api_name="/generate"
)
print(f"声音克隆生成的音频保存在: {result_clone_path}")
```

---

### B. JavaScript / Node.js 调用示例

首先在你的 Node.js 项目中安装 SDK：
```bash
npm install @gradio/client
```

使用以下代码进行异步调用：
```javascript
import { Client } from "@gradio/client";

// 1. 连接客户端
const client = await Client.connect("http://localhost:8808");

// 2. 发起请求
const response = await client.predict("/generate", {
    text_input: "Hello world! This is a voice cloned from a short audio clip.",
    control_instruction: "",                              // 极致克隆下置空
    reference_wav_path: {
        "path": "https://example.com/assets/sample.wav"   // 或者已经上传的文件对象
    },
    show_prompt_text: true,                               // 启用极致克隆
    prompt_text: "Hi, this is my original voice snippet.", // 参考音频的内容
    cfg_value_input: 2.0,
    do_normalize: true,
    denoise: true,
    dit_steps: 10
});

console.log("生成的音频临时地址:", response.data[0].name);
```
