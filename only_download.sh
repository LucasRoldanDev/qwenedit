#!/bin/bash
set -e

echo "================================================================="
echo ">>> INICIANDO SCRIPT: SOLO DESCARGA DE MODELOS"
echo "================================================================="

WORKSPACE="/workspace"
COMFY_DIR="${WORKSPACE}/ComfyUI"

# Creamos el directorio base por si no existe, ya que no vamos a clonar ComfyUI completo
mkdir -p "$COMFY_DIR"

# Instalar dependencias ÚNICAMENTE para descargar (usando pip del sistema)
echo ">>> Instalando herramientas de descarga (huggingface_hub)..."
pip install -q hf_transfer huggingface_hub[cli]
alias hf="huggingface-cli"
export HF_HUB_ENABLE_HF_TRANSFER=1

# Exportar token si viene de RunPod
export HF_TOKEN="$RUNPOD_SECRET_hf_tk"

# =================================================================================
# 1. VALIDACIÓN DE REPO (Si aplica)
# =================================================================================
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

# =================================================================================
# 2. DESCARGAS DE LORAS SUELTOS (URLs directas)
# =================================================================================
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

# =================================================================================
# 3. DESCARGA DE SCRIPTS DE MODELOS (Flux, Qwen, etc.)
# =================================================================================
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

# =================================================================================
# 4. DESCARGA DEL REPOSITORIO DE WORKFLOWS/LORAS
# =================================================================================
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
    
    if [ -n "$HF_TOKEN" ]; then
        hf download "$REPO_WORKFLOW_LORAS" --local-dir "$LORA_DIR" --token "$HF_TOKEN" --include "*.safetensors" "*.pt" "*.ckpt" --quiet || echo "   [!] Error en descarga HF"
    else
        hf download "$REPO_WORKFLOW_LORAS" --local-dir "$LORA_DIR" --include "*.safetensors" "*.pt" "*.ckpt" --quiet || echo "   [!] Error en descarga HF"
    fi
    echo "   -> Descarga del repositorio finalizada."
fi

echo "================================================================="
echo ">>> ✅ FINALIZADO: TODOS LOS MODELOS HAN SIDO DESCARGADOS."
echo ">>> No se iniciará ComfyUI. Puedes cerrar este proceso."
echo "================================================================="
exit 0
