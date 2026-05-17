import os
import sys
import io
import uuid
import base64
import urllib.request
import logging
from typing import Optional
from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import soundfile as sf
import torch

# Configure HF/ModelScope cache directories to match app.py
os.environ["HF_HOME"] = os.path.abspath(os.path.join(os.path.dirname(__file__), "data", "huggingface"))
os.environ["MODELSCOPE_CACHE"] = os.path.abspath(os.path.join(os.path.dirname(__file__), "data", "modelscope"))
os.environ["TOKENIZERS_PARALLELISM"] = "false"

# Limit CPU threads to prevent system lag
torch.set_num_threads(4)
torch.set_num_interop_threads(4)

# Set logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

# Import the existing robust VoxCPMDemo model wrapper from app.py
try:
    from app import VoxCPMDemo
except ImportError:
    logger.error("Failed to import VoxCPMDemo from app.py. Please ensure you are running this script in the root directory.")
    sys.exit(1)

app = FastAPI(
    title="VoxCPM2 OpenAI-Compatible API Gateway",
    description="A lightweight native Windows adapter for the OpenAI Speech API format."
)

# Enable CORS for cross-origin client apps
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize the VoxCPM demo model wrapper
demo = VoxCPMDemo()

class SpeechRequest(BaseModel):
    model: str
    input: str
    voice: Optional[str] = "default"
    speed: Optional[float] = 1.0
    response_format: Optional[str] = "mp3"
    instructions: Optional[str] = ""
    ref_audio: Optional[str] = None
    ref_text: Optional[str] = None
    task_type: Optional[str] = "CustomVoice"

@app.post("/v1/audio/speech")
async def text_to_speech(req: SpeechRequest):
    logger.info(f"Received Speech request for input: '{req.input[:50]}...'")
    temp_wav_path = None
    try:
        # 1. Resolve reference audio if provided (URL or Base64)
        if req.ref_audio:
            if req.ref_audio.startswith("http://") or req.ref_audio.startswith("https://"):
                logger.info(f"Downloading reference audio from URL...")
                temp_wav_path = f"temp_ref_{uuid.uuid4().hex}.wav"
                urllib.request.urlretrieve(req.ref_audio, temp_wav_path)
            elif req.ref_audio.startswith("data:audio/"):
                logger.info(f"Decoding reference audio from Base64 Data URI...")
                header, data = req.ref_audio.split(",", 1)
                audio_data = base64.b64decode(data)
                temp_wav_path = f"temp_ref_{uuid.uuid4().hex}.wav"
                with open(temp_wav_path, "wb") as f:
                    f.write(audio_data)
            else:
                logger.info(f"Decoding reference audio from plain Base64 string...")
                try:
                    audio_data = base64.b64decode(req.ref_audio)
                    temp_wav_path = f"temp_ref_{uuid.uuid4().hex}.wav"
                    with open(temp_wav_path, "wb") as f:
                        f.write(audio_data)
                except Exception:
                    raise HTTPException(status_code=400, detail="Invalid ref_audio format. Must be URL, Base64 Data URI, or plain Base64 string.")

        # 2. Call the pre-configured generate_tts_audio from app.py
        # It handles model loading, device placement, zip-enhancement, text-normalization, and CPU unloading.
        prompt_text = req.ref_text or ""
        
        sample_rate, wav_data = demo.generate_tts_audio(
            text_input=req.input,
            control_instruction=req.instructions or "",
            reference_wav_path_input=temp_wav_path,
            prompt_text=prompt_text,
            cfg_value_input=2.0,
            do_normalize=True,
            denoise=True,
            inference_timesteps=10
        )

        # 3. Write audio to an in-memory buffer
        out_buf = io.BytesIO()
        # Save as WAV format to ensure fast, lossless native compatibility
        sf.write(out_buf, wav_data, sample_rate, format="WAV")
        out_buf.seek(0)

        # 4. Map media type
        media_type = "audio/wav"
        if req.response_format == "mp3":
            media_type = "audio/mpeg"
        elif req.response_format == "flac":
            media_type = "audio/flac"
        elif req.response_format == "opus":
            media_type = "audio/ogg"

        logger.info("Speech generation successful. Sending streaming response.")
        return StreamingResponse(out_buf, media_type=media_type)

    except Exception as e:
        logger.error(f"Error during TTS generation: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        # Clean up the temporary reference wav file
        if temp_wav_path and os.path.exists(temp_wav_path):
            try:
                os.remove(temp_wav_path)
                logger.info("Cleaned up temporary reference audio file.")
            except Exception as cleanup_err:
                logger.warning(f"Failed to clean up temporary file {temp_wav_path}: {str(cleanup_err)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("openai_api:app", host="0.0.0.0", port=8000, reload=False)
