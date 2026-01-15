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
    echo ">>> Los modelos Qwen Image se guardarán en el volumen de red."
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
  "$BASE_DIR/unet"

# =================================================================================
# Text encoder (Qwen VL)
# =================================================================================
FILE_PATH="$BASE_DIR/clip/qwen_2.5_vl_7b_fp8_scaled.safetensors"

if [ ! -f "$FILE_PATH" ]; then
  echo "--> Descargando Qwen Text Encoder..."
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
  echo "--> Descargando Qwen VAE..."
  wget -O "$FILE_PATH" \
    https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors
else
  echo "✔ Qwen VAE already exists at: $FILE_PATH"
fi

# =================================================================================
# Lightning LoRA (V1 → V2 rename)
# =================================================================================
FILE_PATH="$BASE_DIR/loras/Qwen-Image-Edit-2509-Lightning-4steps-V2.0-fp32.safetensors"

if [ ! -f "$FILE_PATH" ]; then
  echo "--> Descargando Qwen Lightning LoRA..."
  wget -O "$FILE_PATH" \
    https://huggingface.co/lightx2v/Qwen-Image-Lightning/resolve/main/Qwen-Image-Edit-2509/Qwen-Image-Edit-2509-Lightning-4steps-V1.0-fp32.safetensors
else
  echo "✔ Qwen Lightning LoRA already exists at: $FILE_PATH"
fi

# =================================================================================
# GGUF UNet model
# =================================================================================
FILE_PATH="$BASE_DIR/unet/Qwen-Image-Edit-2509-Q5_K_S.gguf"

if [ ! -f "$FILE_PATH" ]; then
  echo "--> Descargando Qwen GGUF UNet..."
  wget -O "$FILE_PATH" \
    https://huggingface.co/QuantStack/Qwen-Image-Edit-2509-GGUF/resolve/main/Qwen-Image-Edit-2509-Q5_K_S.gguf
else
  echo "✔ Qwen GGUF UNet already exists at: $FILE_PATH"
fi

echo "✅ Qwen models downloaded successfully"
