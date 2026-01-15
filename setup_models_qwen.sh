#!/usr/bin/env bash
set -e

export HF_HUB_ENABLE_HF_TRANSFER=1
alias hf="huggingface-cli"
pip install -U "huggingface_hub[cli]" > /dev/null 2>&1 || true

WORKSPACE="$(pwd)"
EXTRA_STORAGE="/extra-storage"

if [ -d "$EXTRA_STORAGE" ]; then
    BASE_DIR="$EXTRA_STORAGE/models"
else
    BASE_DIR="$WORKSPACE/models"
fi

mkdir -p "$BASE_DIR/clip" "$BASE_DIR/vae" "$BASE_DIR/loras" "$BASE_DIR/diffusion_models"

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
        if hf download "$repo_id" "$remote_path" --local-dir "$tmp_dl_dir" $token_arg; then
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

# Diffusion Model
download_and_move "Comfy-Org/Qwen-Image_ComfyUI" "split_files/diffusion_models/qwen_image_fp8_e4m3fn.safetensors" "$BASE_DIR/diffusion_models/qwen_image_fp8_e4m3fn.safetensors"

# Text encoder
download_and_move "Comfy-Org/Qwen-Image_ComfyUI" "split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors" "$BASE_DIR/clip/qwen_2.5_vl_7b_fp8_scaled.safetensors"

# VAE
download_and_move "Comfy-Org/Qwen-Image_ComfyUI" "split_files/vae/qwen_image_vae.safetensors" "$BASE_DIR/vae/qwen_image_vae.safetensors"

# LoRAs
download_and_move "lightx2v/Qwen-Image-Lightning" "Qwen-Image-Lightning-8steps-V2.0.safetensors" "$BASE_DIR/loras/Qwen-Image-Lightning-8steps-V2.0.safetensors"
download_and_move "lightx2v/Qwen-Image-Lightning" "Qwen-Image-Lightning-4steps-V2.0.safetensors" "$BASE_DIR/loras/Qwen-Image-Lightning-4steps-V2.0.safetensors"

echo "✅ All Qwen FP8 models downloaded successfully"
