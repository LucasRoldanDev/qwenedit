#!/usr/bin/env bash
set -e

# Obtenemos la ruta actual (normalmente /workspace/ComfyUI)
WORKSPACE="$(pwd)"
EXTRA_STORAGE="/extra-storage"

# =================================================================================
# DETECCIÓN DE VOLUMEN DE RED
# =================================================================================
if [ -d "$EXTRA_STORAGE" ]; then
    echo "================================================================="
    echo ">>> 💾 VOLUMEN EXTERNO DETECTADO (/extra-storage)"
    echo ">>> Los modelos se guardarán en el volumen de red para persistencia."
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
# Usamos la variable $BASE_DIR
mkdir -p \
  "$BASE_DIR/diffusion_models" \
  "$BASE_DIR/clip" \
  "$BASE_DIR/vae"

# =================================================================================
# FLUX.1-dev checkpoint (FP8)
# =================================================================================
FILE_PATH="$BASE_DIR/diffusion_models/flux1-dev-fp8.safetensors"

if [ ! -f "$FILE_PATH" ]; then
  echo "--> Descargando Flux Dev FP8..."
  # Nota: Si el modelo es privado, wget necesitará el header del token.
  # Si tienes problemas, agrega: --header "Authorization: Bearer $HF_TOKEN"
  wget -O "$FILE_PATH" \
    https://huggingface.co/Comfy-Org/flux1-dev/resolve/main/flux1-dev-fp8.safetensors
else
  echo "✔ Flux dev checkpoint already exists at: $FILE_PATH"
fi

# =================================================================================
# CLIP-L
# =================================================================================
FILE_PATH="$BASE_DIR/clip/clip_l.safetensors"

if [ ! -f "$FILE_PATH" ]; then
  echo "--> Descargando CLIP-L..."
  wget -O "$FILE_PATH" \
    https://huggingface.co/GraydientPlatformAPI/flux-clip/resolve/main/clip_l.safetensors
else
  echo "✔ CLIP-L already exists at: $FILE_PATH"
fi

# =================================================================================
# T5XXL encoder (FP8 scaled)
# =================================================================================
FILE_PATH="$BASE_DIR/clip/t5xxl_fp8_e4m3fn_scaled.safetensors"

if [ ! -f "$FILE_PATH" ]; then
  echo "--> Descargando T5XXL..."
  wget -O "$FILE_PATH" \
    https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors
else
  echo "✔ T5XXL encoder already exists at: $FILE_PATH"
fi

# =================================================================================
# VAE (BF16)
# =================================================================================
FILE_PATH="$BASE_DIR/vae/flux-vae-bf16.safetensors"

if [ ! -f "$FILE_PATH" ]; then
  echo "--> Descargando VAE..."
  wget -O "$FILE_PATH" \
    https://huggingface.co/Kijai/flux-fp8/resolve/main/flux-vae-bf16.safetensors
else
  echo "✔ Flux VAE already exists at: $FILE_PATH"
fi

echo "✅ FLUX.1-dev models process finished."
