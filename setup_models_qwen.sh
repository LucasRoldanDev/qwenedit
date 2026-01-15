#!/usr/bin/env bash
set -e

# Configuración de hf_transfer y alias
export HF_HUB_ENABLE_HF_TRANSFER=1
alias hf="huggingface-cli"

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
    BASE_DIR="$EXTRA_STORAGE/models"
else
    echo "================================================================="
    echo ">>> 🏠 NO se detectó volumen externo. Usando almacenamiento local."
    echo ">>> Los modelos se guardarán en $WORKSPACE/models"
    echo "================================================================="
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
# FUNCIÓN DE DESCARGA AVANZADA (Descargar -> Mover/Renombrar)
# =================================================================================
download_and_move() {
    local repo_id="$1"
    local remote_path="$2"
    local target_file="$3"
    
    # Obtenemos el directorio donde irá el archivo
    local target_dir=$(dirname "$target_file")
    local filename=$(basename "$target_file")

    if [ ! -f "$target_file" ]; then
        echo "   -> Descargando: $filename..."
        
        # Creamos un directorio temporal dentro del target para bajar la estructura
        local tmp_dl_dir="$target_dir/_tmp_dl_$$"
        mkdir -p "$tmp_dl_dir"

        # Definir argumentos de token si existe
        local token_arg=""
        if [ -n "$HF_TOKEN" ]; then token_arg="--token $HF_TOKEN"; fi

        # Descargamos
        # Usamos || true para capturar errores nosotros y limpiar
        if hf download "$repo_id" "$remote_path" --local-dir "$tmp_dl_dir" --local-dir-use-symlinks False --quiet $token_arg; then
            
            # Movemos el archivo descargado (que estará dentro de la estructura de carpetas del repo)
            # al destino final con el nombre correcto
            mv "$tmp_dl_dir/$remote_path" "$target_file"
            
            # Limpiamos
            rm -rf "$tmp_dl_dir"
        else
            echo "   [!] Error descargando $filename"
            rm -rf "$tmp_dl_dir"
            return 1
        fi
    else
        echo "   ✔ $filename ya existe."
    fi
}

# =================================================================================
# Text encoder (Qwen VL)
# =================================================================================
# Repo: Comfy-Org/Qwen-Image_ComfyUI
# Remote: split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors
# Local: models/clip/qwen_2.5_vl_7b_fp8_scaled.safetensors
download_and_move \
    "Comfy-Org/Qwen-Image_ComfyUI" \
    "split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors" \
    "$BASE_DIR/clip/qwen_2.5_vl_7b_fp8_scaled.safetensors"

# =================================================================================
# VAE
# =================================================================================
# Repo: Comfy-Org/Qwen-Image_ComfyUI
# Remote: split_files/vae/qwen_image_vae.safetensors
# Local: models/vae/qwen_image_vae.safetensors
download_and_move \
    "Comfy-Org/Qwen-Image_ComfyUI" \
    "split_files/vae/qwen_image_vae.safetensors" \
    "$BASE_DIR/vae/qwen_image_vae.safetensors"

# =================================================================================
# Lightning LoRA (V1 → V2 rename)
# =================================================================================
# Repo: lightx2v/Qwen-Image-Lightning
# Remote: Qwen-Image-Edit-2509/Qwen-Image-Edit-2509-Lightning-4steps-V1.0-fp32.safetensors
# Local (Rename): ...V2.0-fp32.safetensors
download_and_move \
    "lightx2v/Qwen-Image-Lightning" \
    "Qwen-Image-Edit-2509/Qwen-Image-Edit-2509-Lightning-4steps-V1.0-fp32.safetensors" \
    "$BASE_DIR/loras/Qwen-Image-Edit-2509-Lightning-4steps-V2.0-fp32.safetensors"

# =================================================================================
# GGUF UNet model
# =================================================================================
# Repo: QuantStack/Qwen-Image-Edit-2509-GGUF
# Remote: Qwen-Image-Edit-2509-Q5_K_S.gguf
# Local: models/unet/Qwen-Image-Edit-2509-Q5_K_S.gguf
download_and_move \
    "QuantStack/Qwen-Image-Edit-2509-GGUF" \
    "Qwen-Image-Edit-2509-Q5_K_S.gguf" \
    "$BASE_DIR/unet/Qwen-Image-Edit-2509-Q5_K_S.gguf"

echo "✅ Qwen models downloaded successfully"
