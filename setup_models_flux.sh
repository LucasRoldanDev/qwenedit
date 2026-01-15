#!/usr/bin/env bash
set -e

# Aseguramos que hf_transfer esté activo para velocidad máxima
export HF_HUB_ENABLE_HF_TRANSFER=1

# Definimos alias para hf por si no se hereda del script padre
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
    echo ">>> Los modelos FLUX se guardarán en el volumen de red."
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
  "$BASE_DIR/diffusion_models" \
  "$BASE_DIR/clip" \
  "$BASE_DIR/vae"

# =================================================================================
# FUNCIÓN DE DESCARGA (hf download)
# =================================================================================
download_model() {
    local repo_id="$1"
    local filename="$2"
    local target_dir="$3"
    
    # Comprobamos si el archivo ya existe
    if [ ! -f "$target_dir/$filename" ]; then
        echo "   -> Descargando: $filename..."
        
        # Ejecutamos hf download
        # --local-dir: Carpeta destino
        # --local-dir-use-symlinks False: Baja el archivo real, no un enlace simbólico (vital para volumen de red)
        # --quiet: Oculta la barra de progreso
        if [ -n "$HF_TOKEN" ]; then
            hf download "$repo_id" "$filename" \
                --local-dir "$target_dir" \
                --local-dir-use-symlinks False \
                --token "$HF_TOKEN" \
                --quiet
        else
            hf download "$repo_id" "$filename" \
                --local-dir "$target_dir" \
                --local-dir-use-symlinks False \
                --quiet
        fi
    else
        echo "   ✔ $filename ya existe."
    fi
}

# =================================================================================
# FLUX.1-dev checkpoint (FP8)
# =================================================================================
# Repo: Comfy-Org/flux1-dev
# Archivo: flux1-dev-fp8.safetensors
download_model "Comfy-Org/flux1-dev" "flux1-dev-fp8.safetensors" "$BASE_DIR/diffusion_models"

# =================================================================================
# CLIP-L
# =================================================================================
# Repo: GraydientPlatformAPI/flux-clip
# Archivo: clip_l.safetensors
download_model "GraydientPlatformAPI/flux-clip" "clip_l.safetensors" "$BASE_DIR/clip"

# =================================================================================
# T5XXL encoder (FP8 scaled)
# =================================================================================
# Repo: comfyanonymous/flux_text_encoders
# Archivo: t5xxl_fp8_e4m3fn.safetensors
download_model "comfyanonymous/flux_text_encoders" "t5xxl_fp8_e4m3fn.safetensors" "$BASE_DIR/clip"

# =================================================================================
# VAE (BF16)
# =================================================================================
# Repo: Kijai/flux-fp8
# Archivo: flux-vae-bf16.safetensors
download_model "Kijai/flux-fp8" "flux-vae-bf16.safetensors" "$BASE_DIR/vae"

echo "✅ Proceso de modelos FLUX.1-dev finalizado."
