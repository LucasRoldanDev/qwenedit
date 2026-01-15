#!/usr/bin/env bash
set -e

# Configuración de hf_transfer y alias
export HF_HUB_ENABLE_HF_TRANSFER=1

WORKSPACE="$(pwd)"
EXTRA_STORAGE="/extra-storage"

# DETECCIÓN DE VOLUMEN
if [ -d "$EXTRA_STORAGE" ]; then
    echo ">>> 💾 VOLUMEN DETECTADO. Usando /extra-storage/models"
    BASE_DIR="$EXTRA_STORAGE/models"
else
    echo ">>> 🏠 Usando almacenamiento local."
    BASE_DIR="$WORKSPACE/models"
fi

mkdir -p "$BASE_DIR/clip" "$BASE_DIR/vae" "$BASE_DIR/loras" "$BASE_DIR/unet"

# FUNCIÓN DE DESCARGA (SIN EL FLAG PROBLEMÁTICO)
download_and_move() {
    local repo_id="$1"
    local remote_path="$2"
    local target_file="$3"
    
    local target_dir=$(dirname "$target_file")
    local filename=$(basename "$target_file")

    if [ ! -f "$target_file" ]; then
        echo "   -> Descargando: $filename..."
        local tmp_dl_dir="$target_dir/_tmp_dl_$$"
        mkdir -p "$tmp_dl_dir"

        local token_arg=""
        if [ -n "$HF_TOKEN" ]; then token_arg="--token $HF_TOKEN"; fi

        # CORRECCIÓN: Quitamos --local-dir-use-symlinks False
        if hf download "$repo_id" "$remote_path" --local-dir "$tmp_dl_dir" --quiet $token_arg; then
            mv "$tmp_dl_dir/$remote_path" "$target_file"
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

# --- DESCARGAS ---

# Text encoder
download_and_move "Comfy-Org/Qwen-Image_ComfyUI" "split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors" "$BASE_DIR/clip/qwen_2.5_vl_7b_fp8_scaled.safetensors"

# VAE
download_and_move "Comfy-Org/Qwen-Image_ComfyUI" "split_files/vae/qwen_image_vae.safetensors" "$BASE_DIR/vae/qwen_image_vae.safetensors"

# Lightning LoRA
download_and_move "lightx2v/Qwen-Image-Lightning" "Qwen-Image-Edit-2509/Qwen-Image-Edit-2509-Lightning-4steps-V1.0-fp32.safetensors" "$BASE_DIR/loras/Qwen-Image-Edit-2509-Lightning-4steps-V2.0-fp32.safetensors"

# GGUF UNet
download_and_move "QuantStack/Qwen-Image-Edit-2509-GGUF" "Qwen-Image-Edit-2509-Q5_K_S.gguf" "$BASE_DIR/unet/Qwen-Image-Edit-2509-Q5_K_S.gguf"

echo "✅ Qwen models downloaded successfully"
