#!/bin/bash
set -e

echo "================================================================="
echo ">>> INICIANDO CONTENEDOR COMFYUI CUSTOM"
echo "================================================================="

WORKSPACE="/workspace"
COMFY_DIR="${WORKSPACE}/ComfyUI"
VENV_DIR="${COMFY_DIR}/venv"

# Asegurar que estamos usando el venv
source "$VENV_DIR/bin/activate"

# Exportar token si viene de RunPod
export HF_TOKEN="$RUNPOD_SECRET_hf_tk"

# =================================================================================
# VALIDACIÓN Y DESCARGAS (RUNTIME)
# =================================================================================

# 1. Validación de REPO_WORKFLOW_LORAS
if [ -n "$REPO_WORKFLOW_LORAS" ]; then
    echo ">>> VALIDANDO REPOSITORIO: $REPO_WORKFLOW_LORAS"
    API_URL="https://huggingface.co/api/models/$REPO_WORKFLOW_LORAS"
    
    if [ -n "$HF_TOKEN" ]; then
        HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" -H "Authorization: Bearer $HF_TOKEN" "$API_URL")
    else
        HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" "$API_URL")
    fi

    if [ "$HTTP_STATUS" -ne 200 ]; then
        echo ">>> [ERROR] No se puede acceder al repo ($HTTP_STATUS). Verifica el token o el nombre."
        # No hacemos exit 1 para permitir que arranque ComfyUI aunque falle la descarga
    fi
fi

# 2. Descargas de LORAS sueltos (LORAS_URL)
if [ -n "$LORAS_URL" ]; then
    echo ">>> Descargando LORAS sueltos..."
    LORA_DIR="${COMFY_DIR}/models/loras"
    mkdir -p "$LORA_DIR" && cd "$LORA_DIR"
    
    IFS=',' read -ra ADDR <<< "$LORAS_URL"
    for url in "${ADDR[@]}"; do
        clean_url=$(echo "$url" | xargs)
        if [ -n "$clean_url" ]; then
            if [ -n "$HF_TOKEN" ]; then
                wget --header "Authorization: Bearer $HF_TOKEN" --content-disposition "$clean_url" || echo "Falló: $clean_url"
            else
                wget --content-disposition "$clean_url" || echo "Falló: $clean_url"
            fi
        fi
    done
fi

# 3. Descarga de Scripts de Modelos (Qwen, Flux, etc)
cd "$COMFY_DIR"
if [ "${DOWNLOAD_QWEN:-0}" = "1" ]; then
    echo ">>> Ejecuyendo setup Qwen..."
    bash <(curl -fsSL https://raw.githubusercontent.com/LucasRoldanDev/qwenedit/main/setup_models_qwen.sh)
fi

if [ "${DOWNLOAD_QWEN_IMAGE:-0}" = "1" ]; then
    echo ">>> Ejecuyendo setup Qwen Image..."
    bash <(curl -fsSL https://raw.githubusercontent.com/LucasRoldanDev/qwenedit/main/setup_models_qwen_image.sh)
fi

if [ "${DOWNLOAD_FLUX:-0}" = "1" ]; then
    echo ">>> Ejecuyendo setup FLUX..."
    bash <(curl -fsSL https://raw.githubusercontent.com/LucasRoldanDev/qwenedit/main/setup_models_flux.sh)
fi

# 4. Descarga del Repositorio de Workflows/Loras (HF CLI)
if [ -n "$REPO_WORKFLOW_LORAS" ]; then
    echo ">>> Descargando repositorio completo: $REPO_WORKFLOW_LORAS"
    LORA_DIR="${COMFY_DIR}/models/loras"
    mkdir -p "$LORA_DIR"
    
    # Usamos el token si existe
    if [ -n "$HF_TOKEN" ]; then
        huggingface-cli download "$REPO_WORKFLOW_LORAS" --local-dir "$LORA_DIR" --token "$HF_TOKEN" --include "*.safetensors" "*.pt" "*.ckpt" || echo "Error en descarga HF"
    else
        huggingface-cli download "$REPO_WORKFLOW_LORAS" --local-dir "$LORA_DIR" --include "*.safetensors" "*.pt" "*.ckpt" || echo "Error en descarga HF"
    fi
fi

# =================================================================================
# CONFIGURACIÓN FINAL Y ARRANQUE
# =================================================================================
cd "$COMFY_DIR"

# Crear yaml de rutas extra
cat <<EOF > extra_model_paths.yaml
comfyui:
    base_path: /extra-storage/models/
    checkpoints: checkpoints/
    animatediff_models: animatediff_models
    diffusion_models: |
        checkpoints/
        diffusion_models/
    unet: |
        checkpoints/
        unet/
    loras: loras/
    text_encoders: text_encoders/
    style_models: style_models/
    clip: clip/
    clip_vision: clip_vision/
    configs: configs/
    controlnet: controlnet/
    embeddings: embeddings/
    llm: LLM/
    upscale_models: |
                    models/upscale_models
                    models/ESRGAN
                    models/RealESRGAN
                    models/SwinIR
    vae: vae/
EOF

echo ">>> Iniciando ComfyUI..."
python main.py --use-sage-attention --listen --port 3001 --preview-method latent2rgb --enable-cors-header *
