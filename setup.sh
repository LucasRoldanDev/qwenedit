#!/bin/bash
set -e  # Detiene el script si hay errores críticos

# =================================================================================
# DEBUG: MOSTRAR VARIABLES DE ENTORNO AL INICIO
# =================================================================================
echo "================================================================="
echo ">>> [0/9] LISTADO COMPLETO DE VARIABLES DE ENTORNO"
echo "================================================================="
#printenv
echo "================================================================="
echo ">>> FIN DEL LISTADO DE VARIABLES"
echo "================================================================="

# =================================================================================
# VARIABLES DE CONFIGURACIÓN Y TOKEN
# =================================================================================
WORKSPACE="/workspace"
COMFY_DIR="${WORKSPACE}/ComfyUI"
VENV_DIR="${COMFY_DIR}/venv"
SAGE_WHEEL="sageattention-2.1.1-cp312-cp312-linux_x86_64.whl"
SAGE_URL="https://huggingface.co/nitin19/flash-attention-wheels/resolve/main/$SAGE_WHEEL"
COMFYUI_VERSION="v0.4.0"

# Captura del secreto de RunPod y exportación
export HF_TOKEN="$RUNPOD_SECRET_hf_tk"

if [ -n "$HF_TOKEN" ]; then
    echo "================================================================="
    echo "TOKEN ENCONTRADO. Se utilizará para descargas."
    echo "================================================================="
else
    echo "================================================================="
    echo "TOKEN NO ENCONTRADO. Se omitirán descargas privadas."
    echo "================================================================="
fi

# =================================================================================
# VALIDACIÓN PREVIA (PRE-FLIGHT CHECK)
# Verifica si el repositorio existe antes de instalar nada
# =================================================================================
if [ -n "$REPO_WORKFLOW_LORAS" ]; then
    echo ">>> VALIDANDO ACCESO AL REPOSITORIO: $REPO_WORKFLOW_LORAS"
    
    # Nos aseguramos de tener curl
    if ! command -v curl &> /dev/null; then
        echo "Instalando curl temporalmente para la verificación..."
        apt-get update -qq && apt-get install -y -qq curl
    fi

    API_URL="https://huggingface.co/api/models/$REPO_WORKFLOW_LORAS"
    
    # Petición a la API de HF
    if [ -n "$HF_TOKEN" ]; then
        HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" -H "Authorization: Bearer $HF_TOKEN" "$API_URL")
    else
        HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" "$API_URL")
    fi

    echo ">>> ESTADO HTTP API: $HTTP_STATUS"

    if [ "$HTTP_STATUS" -eq 200 ]; then
        echo ">>> [OK] Repositorio validado correctamente. Continuando instalación..."
    elif [ "$HTTP_STATUS" -eq 401 ] || [ "$HTTP_STATUS" -eq 403 ]; then
        echo "#################################################################"
        echo ">>> [ERROR CRÍTICO] ACCESO DENEGADO AL REPOSITORIO ($HTTP_STATUS)"
        echo ">>> El repositorio existe pero tu token no tiene permisos."
        echo ">>> Ejecución cancelada."
        echo "#################################################################"
        exit 1
    elif [ "$HTTP_STATUS" -eq 404 ]; then
        echo "#################################################################"
        echo ">>> [ERROR CRÍTICO] REPOSITORIO NO ENCONTRADO (404)"
        echo ">>> El repositorio '$REPO_WORKFLOW_LORAS' no existe."
        echo ">>> Ejecución cancelada."
        echo "#################################################################"
        exit 1
    else
        echo ">>> [ADVERTENCIA] Respuesta inesperada ($HTTP_STATUS). Intentando continuar..."
    fi
else
    echo ">>> [INFO] No se definió REPO_WORKFLOW_LORAS, se salta la validación."
fi

# ---------------------------------------------------------------------------------
# LISTA DE MODELOS RESTRINGIDOS/GATED
# ---------------------------------------------------------------------------------
GATED_MODELS_URLS=(
    # Ejemplo: "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors"
)

# Array con todos los Custom Nodes
NODES_URLS=(
    "https://github.com/ltdrdata/ComfyUI-Manager.git"
    "https://github.com/yolain/ComfyUI-Easy-Use.git"
    "https://github.com/kijai/ComfyUI-KJNodes.git"
    "https://github.com/cubiq/ComfyUI_essentials.git"
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git"
    "https://github.com/rgthree/rgthree-comfy.git"
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git"
    "https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git"
    "https://github.com/calcuis/gguf.git"
    "https://github.com/melMass/comfy_mtb.git"
    "https://github.com/city96/ComfyUI-GGUF.git"
    "https://github.com/ClownsharkBatwing/RES4LYF.git"
)

# =================================================================================
# 1. PREPARACIÓN DEL SISTEMA
# =================================================================================
echo ">>> [1/9] Actualizando sistema e instalando dependencias base..."
apt update && apt upgrade -y
apt install -y software-properties-common build-essential git python3-pip wget cmake pkg-config ninja-build

# =================================================================================
# 2. INSTALACIÓN DE PYTHON 3.12
# =================================================================================
add-apt-repository ppa:deadsnakes/ppa -y || echo "PPA ya existe o no es necesario"
apt update
apt install -y python3.12 python3.12-venv python3.12-dev

update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1
update-alternatives --set python3 /usr/bin/python3.12

echo ">>> Versión de Python activa (Sistema): $(python3 --version)"

systemctl stop nginx 2>/dev/null || true
pkill -f nginx || true
fuser -k 3001/tcp || true

# =================================================================================
# 3. INSTALACIÓN DE COMFYUI Y VENV
# =================================================================================
echo ">>> [2/9] Instalando ComfyUI..."
mkdir -p "$WORKSPACE"
cd "$WORKSPACE"

if [ -d "$COMFY_DIR/.git" ]; then
    echo ">>> ComfyUI ya existe. Forzando versión $COMFYUI_VERSION..."
    cd "$COMFY_DIR"
    git fetch --all --tags
    git checkout "$COMFYUI_VERSION"
else
    echo ">>> Clonando ComfyUI versión $COMFYUI_VERSION..."
    git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFY_DIR"
    cd "$COMFY_DIR"
    git fetch --all --tags
    git checkout "$COMFYUI_VERSION"
fi

echo ">>> [3/9] Creando entorno virtual (venv)..."
cd "$COMFY_DIR"
rm -rf venv
python3 -m venv venv
source venv/bin/activate

echo ">>> Versión de Python en venv Comfy: $(python --version)"
pip install --upgrade pip

# =================================================================================
# 4. INSTALACIÓN DE PYTORCH Y SAGEATTENTION
# =================================================================================
echo ">>> [4/9] Instalando PyTorch 2.7 y SageAttention..."
pip install torch==2.7.0 torchvision==0.22.0 torchaudio==2.7.0 --index-url https://download.pytorch.org/whl/cu128
pip install triton packaging

# SageAttention
cd "$WORKSPACE"
rm -f "$SAGE_WHEEL"
wget "$SAGE_URL"
pip install "./$SAGE_WHEEL"

cd "$COMFY_DIR"
pip install -r requirements.txt

# =================================================================================
# 5. INSTALACIÓN DE CUSTOM NODES
# =================================================================================
echo ">>> [5/9] Instalando Nodos Personalizados..."
mkdir -p custom_nodes && cd custom_nodes

for repo_url in "${NODES_URLS[@]}"; do
    dir_name=$(basename "$repo_url" .git)
    if [ ! -d "$dir_name" ]; then
        echo "Clonando: $dir_name"
        git clone --depth 1 "$repo_url"
    else
        echo "Ya existe: $dir_name"
    fi
done

echo ">>> Instalando dependencias de los nodos..."
for dir in */; do
    if [ -f "${dir}requirements.txt" ]; then
        echo "Instalando deps para: $dir"
        pip install -r "${dir}requirements.txt"
    fi
done

# =================================================================================
# 6. DESCARGAS INDIVIDUALES (WGET)
# =================================================================================
if [ -n "$LORAS_URL" ]; then
    echo ">>> [6/9] LORAS_URL detectado. Descargando archivos sueltos..."
    LORA_DIR="${COMFY_DIR}/models/loras"
    mkdir -p "$LORA_DIR"
    cd "$LORA_DIR"

    IFS=',' read -ra ADDR <<< "$LORAS_URL"
    for url in "${ADDR[@]}"; do
        clean_url=$(echo "$url" | xargs)
        if [ -n "$clean_url" ]; then
            echo "--> Descargando: $clean_url"
            if [ -n "$HF_TOKEN" ]; then
                wget --header "Authorization: Bearer $HF_TOKEN" --content-disposition "$clean_url" || echo "ADVERTENCIA: Falló descarga"
            else
                wget --content-disposition "$clean_url" || echo "ADVERTENCIA: Falló descarga"
            fi
        fi
    done
fi

echo ">>> [7/9] Verificando modelos Checkpoints privados..."
if [ -n "$HF_TOKEN" ] && [ ${#GATED_MODELS_URLS[@]} -gt 0 ]; then
    CHECKPOINT_DIR="${COMFY_DIR}/models/checkpoints"
    mkdir -p "$CHECKPOINT_DIR"
    cd "$CHECKPOINT_DIR"

    for url in "${GATED_MODELS_URLS[@]}"; do
        clean_url=$(echo "$url" | xargs)
        if [ -n "$clean_url" ]; then
            echo "--> Descargando Modelo Privado: $clean_url"
            wget --header "Authorization: Bearer $HF_TOKEN" --content-disposition "$clean_url" || echo "ERROR: Falló descarga"
        fi
    done
fi

cd "$COMFY_DIR"
if [ "${DOWNLOAD_QWEN:-0}" = "1" ]; then
    echo ">>> DOWNLOAD_QWEN=1 detectado"
    bash <(curl -fsSL https://raw.githubusercontent.com/LucasRoldanDev/qwenedit/main/setup_models_qwen.sh)
fi

# Bloque NUEVO para Qwen Image
if [ "${DOWNLOAD_QWEN_IMAGE:-0}" = "1" ]; then
    echo ">>> DOWNLOAD_QWEN_IMAGE=1 detectado"
    bash <(curl -fsSL https://raw.githubusercontent.com/LucasRoldanDev/qwenedit/main/setup_models_qwen_image.sh)
fi

if [ "${DOWNLOAD_FLUX:-0}" = "1" ]; then
    echo ">>> DOWNLOAD_FLUX=1 detectado"
    bash <(curl -fsSL https://raw.githubusercontent.com/LucasRoldanDev/qwenedit/main/setup_models_flux.sh)
fi


# =================================================================================
# 8. DESCARGA FINAL DE REPOSITORIO (GLOBAL PIP + HF) - CORREGIDO
# =================================================================================
if [ -n "$REPO_WORKFLOW_LORAS" ]; then
    echo ">>> [8/9] Preparando descarga de repositorio ($REPO_WORKFLOW_LORAS)..."
    
    LORA_DIR="${COMFY_DIR}/models/loras"
    mkdir -p "$LORA_DIR"

    # 1. Salir del entorno virtual
    deactivate 2>/dev/null || true
    
    echo "--> Instalando huggingface_hub[cli] globalmente..."
    pip install -U "huggingface_hub[cli]" --break-system-packages || pip install -U huggingface_hub
    
    # 2. Descarga usando lógica explícita de token y MÚLTIPLES INCLUDES
    #    NOTA: Se usa --include repetido para evitar errores de parseo
    if [ -n "$HF_TOKEN" ]; then
        echo "--> Usando autenticación EXPLÍCITA con Token..."
        hf download "$REPO_WORKFLOW_LORAS" \
            --local-dir "$LORA_DIR" \
            --token "$HF_TOKEN" \
            --include "*.safetensors" --include "*.pt" --include "*.ckpt" \
            || { echo "ERROR CRÍTICO: Falló la descarga."; exit 1; }
    else
        echo "--> Intentando descarga PÚBLICA (Sin token)..."
        hf download "$REPO_WORKFLOW_LORAS" \
            --local-dir "$LORA_DIR" \
            --include "*.safetensors" --include "*.pt" --include "*.ckpt" \
            || { echo "ERROR CRÍTICO: Falló la descarga."; exit 1; }
    fi

    # 3. Reactivar venv
    source "$VENV_DIR/bin/activate"
    echo "--> Descarga de repositorio finalizada."

else
    echo ">>> [8/9] No se detectó REPO_WORKFLOW_LORAS. Saltando."
fi

# =================================================================================
# 9. CONFIGURACIÓN YAML Y EJECUCIÓN
# =================================================================================
echo ">>> [9/9] Generando configuración e iniciando..."
cd "$COMFY_DIR"

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

chmod +x main.py
# Aseguramos que el venv esté activo antes de lanzar
source "$VENV_DIR/bin/activate"

# Ejecutar
python main.py --use-sage-attention --listen --port 3001 --preview-method latent2rgb --enable-cors-header * 
