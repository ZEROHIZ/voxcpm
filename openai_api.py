import os
import sys
import io
import uuid
import base64
import shutil
import urllib.request
import logging
from typing import Optional
from fastapi import FastAPI, HTTPException, UploadFile, File
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
try:
    torch.set_num_threads(4)
    torch.set_num_interop_threads(4)
except RuntimeError:
    pass

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
    description="A lightweight native Windows adapter for the OpenAI Speech API format with 4-way adaptive audio resolution."
)

# Enable CORS for cross-origin client apps
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configure the uploads directory
UPLOAD_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "data", "uploads"))
os.makedirs(UPLOAD_DIR, exist_ok=True)

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
    # 高级设置参数兼容 (CFG, 文本规范化, 降噪, LocDIT 步数)
    cfg_value: Optional[float] = 2.0
    do_normalize: Optional[bool] = False
    denoise: Optional[bool] = False
    inference_timesteps: Optional[int] = 20

def validate_audio_content(file_bytes: bytes, extension: str) -> bool:
    """
    Validates that the file's magic bytes (binary file signature) match its declared extension.
    Supported strictly: .wav, .mp3, .mp4
    """
    if len(file_bytes) < 4:
        return False
        
    ext = extension.lower()
    
    if ext == ".wav":
        # WAV files start with 'RIFF' (bytes 0-3) and have 'WAVE' at offset 8 (bytes 8-11)
        if len(file_bytes) < 12:
            return False
        return file_bytes[0:4] == b"RIFF" and file_bytes[8:12] == b"WAVE"
        
    elif ext == ".mp3":
        # MP3 files usually start with 'ID3' (ID3v2) or MPEG frame sync (0xFF 0xFB, 0xFF 0xF3, etc.)
        is_id3 = file_bytes[0:3] == b"ID3"
        is_frame_sync = file_bytes[0] == 0xFF and (file_bytes[1] & 0xE0) == 0xE0
        return is_id3 or is_frame_sync
        
    elif ext == ".mp4":
        # MP4 files typically have 'ftyp' starting at index 4 (bytes 4-7)
        if len(file_bytes) < 8:
            return False
        return file_bytes[4:8] == b"ftyp"
        
    return False


@app.post("/v1/audio/upload")
async def upload_audio(file: UploadFile = File(...)):
    """
    Physical file upload endpoint (Multipart Form) with binary-level signature validation.
    Receives an audio file, checks extension & magic bytes, and saves it.
    """
    logger.info(f"Received file upload request: {file.filename}")
    try:
        # 1. Validate file extension (Strict: only .wav, .mp3, .mp4 allowed)
        ext = os.path.splitext(file.filename)[1].lower()
        if ext not in [".wav", ".mp3", ".mp4"]:
            raise HTTPException(
                status_code=400,
                detail="Unsupported audio format. Only .wav, .mp3, and .mp4 are allowed for security."
            )

        # 2. Read the first 16 bytes to check the magic bytes (binary signature)
        first_bytes = await file.read(16)
        # Seek back to the beginning so that shutil.copyfileobj reads the entire file
        await file.seek(0)

        # 3. Perform binary-level file signature matching to block disguised script files
        if not validate_audio_content(first_bytes, ext):
            logger.warning(f"Security Alert: File '{file.filename}' signature mismatch. Declared extension: '{ext}' but binary signature does not match.")
            raise HTTPException(
                status_code=400,
                detail="Security check failed: The file's binary content does not match its declared extension. Upload rejected."
            )

        # 4. Generate a unique secure filename and path on the server
        unique_filename = f"temp_upload_{uuid.uuid4().hex}{ext}"
        file_path = os.path.join(UPLOAD_DIR, unique_filename)

        # Save the validated uploaded file to disk
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        logger.info(f"Successfully saved validated uploaded file to: {file_path}")
        return {"file_path": file_path}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to upload audio: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")


@app.post("/v1/audio/speech")
async def text_to_speech(req: SpeechRequest):
    logger.info(f"Received Speech request for input: '{req.input[:50]}...'")
    temp_wav_path = None
    is_temporary_file = False
    
    try:
        # 1. Resolve reference audio if provided (URL, Local Path, Upload Cache, or Base64)
        if req.ref_audio:
            ref = req.ref_audio.strip()
            
            # --- Check A: Local Path on Server Disk ---
            if os.path.exists(ref):
                temp_wav_path = ref
                # Determine if this file is a temporary upload inside data/uploads/
                if os.path.abspath(ref).startswith(UPLOAD_DIR):
                    logger.info(f"Resolved from temporary uploaded file path: {ref}")
                    is_temporary_file = True  # It is a temporary uploaded file, so clean it up later!
                else:
                    logger.info(f"Resolved from existing local host file path: {ref}")
                    is_temporary_file = False # It is a pre-existing developer local file, DO NOT delete!
            
            # --- Check B: URL Link ---
            elif ref.startswith("http://") or ref.startswith("https://"):
                logger.info(f"Downloading reference audio from URL...")
                temp_wav_path = os.path.join(UPLOAD_DIR, f"temp_download_{uuid.uuid4().hex}.wav")
                urllib.request.urlretrieve(ref, temp_wav_path)
                is_temporary_file = True
                
            # --- Check C: Base64 Data URI ---
            elif ref.startswith("data:audio/"):
                logger.info(f"Decoding reference audio from Base64 Data URI...")
                header, data = ref.split(",", 1)
                audio_data = base64.b64decode(data)
                temp_wav_path = os.path.join(UPLOAD_DIR, f"temp_decode_{uuid.uuid4().hex}.wav")
                with open(temp_wav_path, "wb") as f:
                    f.write(audio_data)
                is_temporary_file = True
                
            # --- Check D: Plain Base64 String ---
            else:
                logger.info(f"Checking if input is plain Base64 string...")
                try:
                    audio_data = base64.b64decode(ref)
                    if len(audio_data) > 100:
                        temp_wav_path = os.path.join(UPLOAD_DIR, f"temp_decode_{uuid.uuid4().hex}.wav")
                        with open(temp_wav_path, "wb") as f:
                            f.write(audio_data)
                        is_temporary_file = True
                        logger.info("Successfully decoded from plain Base64 string.")
                    else:
                        raise ValueError("Decoded data too short to be a valid audio file.")
                except Exception:
                    # If decoding fails, and it didn't exist locally, it means it is an invalid local path or bad base64
                    logger.error(f"Reference audio path not found locally, and not valid Base64/URL.")
                    raise HTTPException(
                        status_code=400,
                        detail="Reference audio file not found on the server filesystem. "
                               "If calling from a remote machine, please use File Upload API (POST /v1/audio/upload) "
                               "or Base64 encoding."
                    )

        # 2. Call the pre-configured generate_tts_audio from app.py
        # It handles model loading, device placement, zip-enhancement, text-normalization, and CPU unloading.
        prompt_text = req.ref_text or ""
        
        cfg_val = req.cfg_value if req.cfg_value is not None else 2.0
        norm_val = req.do_normalize if req.do_normalize is not None else False
        denoise_val = req.denoise if req.denoise is not None else False
        steps_val = req.inference_timesteps if req.inference_timesteps is not None else 20

        sample_rate, wav_data = demo.generate_tts_audio(
            text_input=req.input,
            control_instruction=req.instructions or "",
            reference_wav_path_input=temp_wav_path,
            prompt_text=prompt_text,
            cfg_value_input=cfg_val,
            do_normalize=norm_val,
            denoise=denoise_val,
            inference_timesteps=steps_val
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

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error during TTS generation: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        # Clean up the temporary reference wav file
        if temp_wav_path and is_temporary_file and os.path.exists(temp_wav_path):
            try:
                os.remove(temp_wav_path)
                logger.info("Cleaned up temporary reference audio file successfully.")
            except Exception as cleanup_err:
                logger.warning(f"Failed to clean up temporary file {temp_wav_path}: {str(cleanup_err)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("openai_api:app", host="0.0.0.0", port=8089, reload=False)
