#!/bin/bash
set -e

echo "================================================================="
echo ">>> INICIANDO SCRIPT DE ARRANQUE (OPTIMIZADO)"
echo "================================================================="

WORKSPACE="/workspace"
COMFY_DIR="${WORKSPACE}/ComfyUI"
VENV_DIR="${COMFY_DIR}/venv"

# Asegurar que estamos usando el venv
source "$VENV_DIR/bin/activate"

# Instalar hf_transfer para máxima velocidad
# y asegurar que existe el comando 'hf'
pip install -q hf_transfer huggingface_hub[cli]
alias hf="huggingface-cli"
export HF_HUB_ENABLE_HF_TRANSFER=1

# Exportar token si viene de RunPod
export HF_TOKEN="$RUNPOD_SECRET_hf_tk"

# =================================================================================
# VALIDACIÓN Y DESCARGAS
# =================================================================================

# 1. Validación de REPO_WORKFLOW_LORAS (Silenciosa)
if [ -n "$REPO_WORKFLOW_LORAS" ]; then
    echo ">>> Validando acceso al repositorio..."
    API_URL="https://huggingface.co/api/models/$REPO_WORKFLOW_LORAS"
    
    if [ -n "$HF_TOKEN" ]; then
        HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" -H "Authorization: Bearer $HF_TOKEN" "$API_URL")
    else
        HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" "$API_URL")
    fi

    if [ "$HTTP_STATUS" -ne 200 ]; then
        echo ">>> [ERROR] Acceso denegado o repo no encontrado ($HTTP_STATUS)."
    else
        echo ">>> [OK] Repositorio validado."
    fi
fi

# 2. Descargas de LORAS sueltos (URLs directas)
if [ -n "$LORAS_URL" ]; then
    echo ">>> Procesando lista de LoRAs sueltos..."
    LORA_DIR="${COMFY_DIR}/models/loras"
    mkdir -p "$LORA_DIR" && cd "$LORA_DIR"
    
    IFS=',' read -ra ADDR <<< "$LORAS_URL"
    for url in "${ADDR[@]}"; do
        clean_url=$(echo "$url" | xargs)
        if [ -n "$clean_url" ]; then
            filename=$(basename "$clean_url")
            echo "   -> Descargando: $filename"
            if [ -n "$HF_TOKEN" ]; then
                wget -q --header "Authorization: Bearer $HF_TOKEN" --content-disposition "$clean_url" || echo "   [!] Falló: $clean_url"
            else
                wget -q --content-disposition "$clean_url" || echo "   [!] Falló: $clean_url"
            fi
        fi
    done
fi

# 3. Descarga de Scripts de Modelos (Silenciados)
cd "$COMFY_DIR"
if [ "${DOWNLOAD_QWEN:-0}" = "1" ]; then
    echo ">>> Descargando modelos Qwen (Texto/Edit)..."
    bash <(curl -fsSL https://raw.githubusercontent.com/LucasRoldanDev/qwenedit/main/setup_models_qwen.sh) > /dev/null 2>&1
    echo "   -> Completado."
fi

if [ "${DOWNLOAD_QWEN_IMAGE:-0}" = "1" ]; then
    echo ">>> Descargando modelos Qwen (Imagen)..."
    bash <(curl -fsSL https://raw.githubusercontent.com/LucasRoldanDev/qwenedit/main/setup_models_qwen_image.sh) > /dev/null 2>&1
    echo "   -> Completado."
fi

if [ "${DOWNLOAD_FLUX:-0}" = "1" ]; then
    echo ">>> Descargando modelos FLUX.1-dev..."
    bash <(curl -fsSL https://raw.githubusercontent.com/LucasRoldanDev/qwenedit/main/setup_models_flux.sh) > /dev/null 2>&1
    echo "   -> Completado."
fi

# 4. Descarga del Repositorio de Workflows/Loras (Usando 'hf' + hf_transfer)
if [ -n "$REPO_WORKFLOW_LORAS" ]; then
    
    EXTRA_STORAGE="/extra-storage"
    
    # Lógica de detección de volumen
    if [ -d "$EXTRA_STORAGE" ]; then
        echo ">>> 💾 VOLUMEN EXTERNO DETECTADO. Cacheando LoRAs en red."
        LORA_DIR="${EXTRA_STORAGE}/models/loras"
    else
        echo ">>> 🏠 Usando almacenamiento local."
        LORA_DIR="${COMFY_DIR}/models/loras"
    fi

    mkdir -p "$LORA_DIR"
    echo ">>> Descargando repositorio de LoRAs (usando hf_transfer)..."
    echo "   -> Repo: $REPO_WORKFLOW_LORAS"
    echo "   -> Destino: $LORA_DIR"
    
    # Usamos 'hf' en lugar de huggingface-cli como pediste (gracias al alias)
    # --quiet oculta la barra de progreso
    if [ -n "$HF_TOKEN" ]; then
        hf download "$REPO_WORKFLOW_LORAS" --local-dir "$LORA_DIR" --token "$HF_TOKEN" --include "*.safetensors" "*.pt" "*.ckpt" --quiet || echo "   [!] Error en descarga HF"
    else
        hf download "$REPO_WORKFLOW_LORAS" --local-dir "$LORA_DIR" --include "*.safetensors" "*.pt" "*.ckpt" --quiet || echo "   [!] Error en descarga HF"
    fi
    echo "   -> Descarga del repositorio finalizada."
fi

# =================================================================================
# LÓGICA DE SOLO CACHÉ (SKIPEAR ARRANQUE)
# =================================================================================
if [ "${ONLY_DOWNLOAD_MODELS:-0}" = "1" ] || [ "${ONLY_DOWNLOAD_MODELS}" = "true" ]; then
    echo "================================================================="
    echo ">>> ✅ MODO 'ONLY_DOWNLOAD_MODELS' ACTIVO"
    echo ">>> Todas las descargas han finalizado correctamente."
    echo ">>> Deteniendo ejecución antes de iniciar ComfyUI."
    echo ">>> Puedes apagar este Pod."
    echo "================================================================="
    sleep 5 # Pequeña pausa para asegurar logs
    exit 0
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

echo ">>> Instalando dependencias finales..."
pip install -q websocket-client

echo ">>> Iniciando ComfyUI..."
python main.py --use-sage-attention --listen --port 3001 --preview-method latent2rgb --enable-cors-header "*"
