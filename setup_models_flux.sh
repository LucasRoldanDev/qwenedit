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

mkdir -p "$BASE_DIR/diffusion_models" "$BASE_DIR/clip" "$BASE_DIR/vae"

download_model() {
    local repo_id="$1"
    local filename="$2"
    local target_dir="$3"
    
    if [ ! -f "$target_dir/$filename" ]; then
        echo "   -> Descargando: $filename..."
        
        # CORRECCIÓN: Quitamos --local-dir-use-symlinks False
        if [ -n "$HF_TOKEN" ]; then
            hf download "$repo_id" "$filename" --local-dir "$target_dir" --token "$HF_TOKEN" --quiet
        else
            hf download "$repo_id" "$filename" --local-dir "$target_dir" --quiet
        fi
    else
        echo "   ✔ $filename ya existe."
    fi
}

# --- DESCARGAS ---
download_model "Comfy-Org/flux1-dev" "flux1-dev-fp8.safetensors" "$BASE_DIR/diffusion_models"
download_model "GraydientPlatformAPI/flux-clip" "clip_l.safetensors" "$BASE_DIR/clip"
download_model "comfyanonymous/flux_text_encoders" "t5xxl_fp8_e4m3fn.safetensors" "$BASE_DIR/clip"
download_model "Kijai/flux-fp8" "flux-vae-bf16.safetensors" "$BASE_DIR/vae"

echo "✅ Proceso de modelos FLUX.1-dev finalizado."
