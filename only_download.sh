#!/bin/bash
set -e

echo "================================================================="
echo ">>> 📥 INICIANDO MODO SOLO DESCARGA (Only Download)"
echo "================================================================="

# 1. Instalar herramientas de descarga acelerada en el sistema global
#    (Usamos pip del sistema porque en este modo quizás no existe el venv)
echo ">>> Instalando hf_transfer y dependencias..."
pip install -q "huggingface_hub[cli]" hf_transfer

# 2. Configurar aceleración HF
export HF_HUB_ENABLE_HF_TRANSFER=1
alias hf="huggingface-cli"

# 3. Descarga de Scripts de Modelos (Usando tus scripts remotos)
#    Estos scripts ya tienen la lógica de detectar /extra-storage
if [ "${DOWNLOAD_QWEN:-0}" = "1" ]; then
    echo ">>> ⬇️ Descargando Modelos Qwen Text..."
    bash <(curl -fsSL https://raw.githubusercontent.com/LucasRoldanDev/qwenedit/main/setup_models_qwen.sh)
fi

if [ "${DOWNLOAD_QWEN_IMAGE:-0}" = "1" ]; then
    echo ">>> ⬇️ Descargando Modelos Qwen Image..."
    bash <(curl -fsSL https://raw.githubusercontent.com/LucasRoldanDev/qwenedit/main/setup_models_qwen_image.sh)
fi

if [ "${DOWNLOAD_FLUX:-0}" = "1" ]; then
    echo ">>> ⬇️ Descargando Modelos FLUX..."
    bash <(curl -fsSL https://raw.githubusercontent.com/LucasRoldanDev/qwenedit/main/setup_models_flux.sh)
fi

# 4. Descarga del Repositorio de LoRAs
if [ -n "$REPO_WORKFLOW_LORAS" ]; then
    echo ">>> ⬇️ Descargando Repositorio de LoRAs..."
    
    EXTRA_STORAGE="/extra-storage"
    if [ -d "$EXTRA_STORAGE" ]; then
        echo "   >>> 💾 Volumen detectado. Guardando en red."
        LORA_DIR="${EXTRA_STORAGE}/models/loras"
    else
        echo "   >>> 🏠 Guardando en local (Workspace)."
        # Si no hay extra storage, asumimos la ruta estándar de Comfy aunque no esté instalado
        LORA_DIR="/workspace/ComfyUI/models/loras"
    fi
    mkdir -p "$LORA_DIR"

    # Usamos hf download con quiet
    token_arg=""
    if [ -n "$HF_TOKEN" ]; then token_arg="--token $HF_TOKEN"; fi
    
    hf download "$REPO_WORKFLOW_LORAS" --local-dir "$LORA_DIR" $token_arg --include "*.safetensors" "*.pt" "*.ckpt" --quiet || echo "Error descarga repo"
fi

echo "================================================================="
echo ">>> ✅ DESCARGAS COMPLETADAS. DETENIENDO CONTENEDOR."
echo "================================================================="
