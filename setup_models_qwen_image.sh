#!/usr/bin/env bash
set -e

# Obtenemos la ruta actual
WORKSPACE="$(pwd)"
EXTRA_STORAGE="/extra-storage"

# =================================================================================
# DETECCIÓN DE VOLUMEN DE RED
# =================================================================================
if [ -d "$EXTRA_STORAGE" ]; then
    echo "================================================================="
    echo ">>> 💾 VOLUMEN EXTERNO DETECTADO (/extra-storage)"
    echo ">>> Los modelos Qwen (FP8) se guardarán en el volumen de red."
    echo "================================================================="
    # Definimos la base en el volumen extra
    BASE_DIR="$EXTRA_STORAGE/models"
else
    echo "================================================================="
    echo ">>> 🏠 NO se detectó volumen externo. Usando almacenamiento local."
    echo ">>> Los modelos se guardarán en $WORKSPACE/models"
    echo "================================================================="
    # Definimos la base en la carpeta local
    BASE_DIR="$WORKSPACE/models"
fi

echo ">>> Directorio objetivo: $BASE_DIR"

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
  echo "--> Descargando Diffusion Model (FP8)..."
  wget -O "$FILE_PATH" \
    https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_fp8_e4m3fn.safetensors
else
  echo "✔ Diffusion model (FP8) already exists at: $FILE_PATH"
fi

# =================================================================================
# Text encoder (Qwen VL)
# =================================================================================
FILE_PATH="$BASE_DIR/clip/qwen_2.5_vl_7b_fp8_scaled.safetensors"

if [ ! -f "$FILE_PATH" ]; then
  echo "--> Descargando Text Encoder..."
  wget -O "$FILE_PATH" \
    https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors
else
  echo "✔ Qwen text encoder already exists at: $FILE_PATH"
fi

# =================================================================================
# VAE
# =================================================================================
FILE_PATH="$BASE_DIR/vae/qwen_image_vae.safetensors"

if [ ! -f "$FILE_PATH" ]; then
  echo "--> Descargando VAE..."
  wget -O "$FILE_PATH" \
    https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors
else
  echo "✔ Qwen VAE already exists at: $FILE_PATH"
fi

# =================================================================================
# Lightning LoRAs
# =================================================================================

# 8 Steps
FILE_PATH="$BASE_DIR/loras/Qwen-Image-Lightning-8steps-V2.0.safetensors"

if [ ! -f "$FILE_PATH" ]; then
  echo "--> Descargando LoRA (8 steps)..."
  wget -O "$FILE_PATH" \
    https://huggingface.co/lightx2v/Qwen-Image-Lightning/resolve/main/Qwen-Image-Lightning-8steps-V2.0.safetensors
else
  echo "✔ LoRA (8 steps) already exists at: $FILE_PATH"
fi

# 4 Steps
FILE_PATH="$BASE_DIR/loras/Qwen-Image-Lightning-4steps-V2.0.safetensors"

if [ ! -f "$FILE_PATH" ]; then
  echo "--> Descargando LoRA (4 steps)..."
  wget -O "$FILE_PATH" \
    https://huggingface.co/lightx2v/Qwen-Image-Lightning/resolve/main/Qwen-Image-Lightning-4steps-V2.0.safetensors
else
  echo "✔ LoRA (4 steps) already exists at: $FILE_PATH"
fi

echo "✅ All Qwen FP8 models downloaded successfully"
