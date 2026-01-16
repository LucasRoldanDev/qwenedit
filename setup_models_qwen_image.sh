#!/usr/bin/env bash
set -e

WORKSPACE="$(pwd)"
EXTRA_STORAGE="/extra-storage"

# =================================================================================
# DETECCIÓN DE VOLUMEN DE RED
# =================================================================================
if [ -d "$EXTRA_STORAGE" ]; then
    echo "💾 External storage detected. Using /extra-storage/models"
    BASE_DIR="$EXTRA_STORAGE/models"
else
    echo "🏠 No external storage detected. Using local models directory"
    BASE_DIR="$WORKSPACE/models"
fi

echo "📥 Downloading Qwen Image (FP8) models into: $BASE_DIR"

# =================================================================================
# CREACIÓN DE DIRECTORIOS
# =================================================================================
mkdir -p \
  "$BASE_DIR/clip" \
  "$BASE_DIR/vae" \
  "$BASE_DIR/loras" \
  "$BASE_DIR/diffusion_models"

# =================================================================================
# Diffusion Model (Main FP8)
# =================================================================================
FILE_PATH="$BASE_DIR/diffusion_models/qwen_image_fp8_e4m3fn.safetensors"
if [ ! -f "$FILE_PATH" ]; then
  echo "Downloading Diffusion Model..."
  wget -O "$FILE_PATH" \
    https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_fp8_e4m3fn.safetensors
else
  echo "✔ Diffusion model (FP8) already exists"
fi

# =================================================================================
# Text encoder (Qwen VL)
# =================================================================================
FILE_PATH="$BASE_DIR/clip/qwen_2.5_vl_7b_fp8_scaled.safetensors"
if [ ! -f "$FILE_PATH" ]; then
  echo "Downloading Text Encoder..."
  wget -O "$FILE_PATH" \
    https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors
else
  echo "✔ Qwen text encoder already exists"
fi

# =================================================================================
# VAE
# =================================================================================
FILE_PATH="$BASE_DIR/vae/qwen_image_vae.safetensors"
if [ ! -f "$FILE_PATH" ]; then
  echo "Downloading VAE..."
  wget -O "$FILE_PATH" \
    https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors
else
  echo "✔ Qwen VAE already exists"
fi

# =================================================================================
# Lightning LoRAs
# =================================================================================

# 8 Steps
FILE_PATH="$BASE_DIR/loras/Qwen-Image-Lightning-8steps-V2.0.safetensors"
if [ ! -f "$FILE_PATH" ]; then
  echo "Downloading LoRA (8 steps)..."
  wget -O "$FILE_PATH" \
    https://huggingface.co/lightx2v/Qwen-Image-Lightning/resolve/main/Qwen-Image-Lightning-8steps-V2.0.safetensors
else
  echo "✔ LoRA (8 steps) already exists"
fi

# 4 Steps
FILE_PATH="$BASE_DIR/loras/Qwen-Image-Lightning-4steps-V2.0.safetensors"
if [ ! -f "$FILE_PATH" ]; then
  echo "Downloading LoRA (4 steps)..."
  wget -O "$FILE_PATH" \
    https://huggingface.co/lightx2v/Qwen-Image-Lightning/resolve/main/Qwen-Image-Lightning-4steps-V2.0.safetensors
else
  echo "✔ LoRA (4 steps) already exists"
fi

echo "✅ All Qwen FP8 models downloaded successfully"
