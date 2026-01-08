#!/bin/bash

# =================================================================================
# VARIABLES DE CONFIGURACIÓN Y TOKEN
# =================================================================================
WORKSPACE="/workspace"
COMFY_DIR="${WORKSPACE}/ComfyUI"
VENV_DIR="${COMFY_DIR}/venv"
SAGE_WHEEL="sageattention-2.1.1-cp312-cp312-linux_x86_64.whl"
SAGE_URL="https://huggingface.co/nitin19/flash-attention-wheels/resolve/main/$SAGE_WHEEL"

# Captura del secreto de RunPod
HF_TOKEN="$RUNPOD_SECRET_hf_tk"

if [ -n "$HF_TOKEN" ]; then
    echo "================================================================="
    echo "TOKEN ENCONTRADO (RUNPOD_SECRET_hf_tk): Se habilitan descargas privadas."
    echo "================================================================="
else
    echo "================================================================="
    echo "TOKEN NO ENCONTRADO: Se omitirán los modelos que requieran autenticación."
    echo "================================================================="
fi

# ---------------------------------------------------------------------------------
# LISTA DE MODELOS RESTRINGIDOS/GATED (MODIFICAR AQUÍ)
# Añade las URLs de descarga directa (resolve/main/...)
# ---------------------------------------------------------------------------------
GATED_MODELS_URLS=(
    # Ejemplo: "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors"
    # Añade tus líneas abajo:
    
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
# 1. PREPARACIÓN DEL SISTEMA Y PYTHON 3.12
# =================================================================================
echo ">>> [1/9] Actualizando sistema e instalando dependencias base..."
apt update && apt upgrade -y
apt install -y software-properties-common build-essential git python3-pip wget cmake pkg-config ninja-build

add-apt-repository ppa:deadsnakes/ppa -y || echo "PPA ya existe o no es necesario"
apt update
apt install -y python3.12 python3.12-venv python3.12-dev

update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1
update-alternatives --set python3 /usr/bin/python3.12

echo ">>> Versión de Python del sistema: $(python3 --version)"

systemctl stop nginx 2>/dev/null || true
pkill -f nginx || true
fuser -k 3001/tcp || true

# =================================================================================
# 2. INSTALACIÓN DE COMFYUI
# =================================================================================
echo ">>> [2/9] Instalando ComfyUI..."
mkdir -p "$WORKSPACE"
cd "$WORKSPACE"

if [ -d "$COMFY_DIR" ]; then
    echo "Carpeta ComfyUI detectada. Actualizando..."
    cd "$COMFY_DIR" && git pull
else
    git clone https://github.com/comfyanonymous/ComfyUI.git
fi

# =================================================================================
# 3. CREACIÓN DEL ENTORNO VIRTUAL
# =================================================================================
echo ">>> [3/9] Creando entorno virtual (venv)..."
cd "$COMFY_DIR"
rm -rf venv
python3 -m venv venv
source venv/bin/activate

echo ">>> Versión de Python en venv: $(python --version)"
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

python -c 'import torch; print(f"Torch: {torch.__version__}, CUDA: {torch.version.cuda}")'
python -c 'import sageattention; print("SageAttention instalado correctamente")' || echo "ERROR: Falló SageAttention"

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
# 6. DESCARGA DE LORAS EXTRA (Variable LORAS_URL)
# =================================================================================
# Se usa el token también aquí por si se descargan Loras privados de HF
if [ -n "$LORAS_URL" ]; then
    echo ">>> [6/9] Argumento LORAS_URL detectado. Procesando descargas..."
    
    LORA_DIR="${COMFY_DIR}/models/loras"
    mkdir -p "$LORA_DIR"
    cd "$LORA_DIR"

    IFS=',' read -ra ADDR <<< "$LORAS_URL"
    
    for url in "${ADDR[@]}"; do
        clean_url=$(echo "$url" | xargs)
        if [ -n "$clean_url" ]; then
            echo "--> Descargando Lora: $clean_url"
            
            if [ -n "$HF_TOKEN" ]; then
                wget --header "Authorization: Bearer $HF_TOKEN" --content-disposition "$clean_url" || echo "ADVERTENCIA: Falló descarga de $clean_url"
            else
                wget --content-disposition "$clean_url" || echo "ADVERTENCIA: Falló descarga de $clean_url"
            fi
        fi
    done
else
    echo ">>> [6/9] No se detectó LORAS_URL. Saltando descargas extra."
fi

# =================================================================================
# 6.5. DESCARGA DE MODELOS PRIVADOS (Token de RunPod)
# =================================================================================
echo ">>> [7/9] Verificando modelos privados (Gated Models)..."

if [ -n "$HF_TOKEN" ] && [ ${#GATED_MODELS_URLS[@]} -gt 0 ]; then
    echo "--> Token detectado. Iniciando descarga de modelos restringidos..."
    
    # Por defecto los descargamos en checkpoints
    CHECKPOINT_DIR="${COMFY_DIR}/models/checkpoints"
    mkdir -p "$CHECKPOINT_DIR"
    cd "$CHECKPOINT_DIR"

    for url in "${GATED_MODELS_URLS[@]}"; do
        clean_url=$(echo "$url" | xargs)
        if [ -n "$clean_url" ]; then
            echo "--> Descargando Modelo Privado: $clean_url"
            wget --header "Authorization: Bearer $HF_TOKEN" --content-disposition "$clean_url" || echo "ERROR: Falló la descarga autenticada de $clean_url"
        fi
    done
else
    if [ -z "$HF_TOKEN" ]; then
        echo "--> SALTANDO: No se detectó la variable de entorno RUNPOD_SECRET_hf_tk."
    elif [ ${#GATED_MODELS_URLS[@]} -eq 0 ]; then
        echo "--> SALTANDO: La lista GATED_MODELS_URLS está vacía."
    fi
fi

# =================================================================================
# 7. CONFIGURACIÓN YAML
# =================================================================================
echo ">>> [8/9] Generando configuración de rutas..."
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

# =================================================================================
# 8. EJECUCIÓN
# =================================================================================
echo ">>> [9/9] Iniciando ComfyUI..."
chmod +x main.py
source "$VENV_DIR/bin/activate"

# Ejecutar
python main.py --use-sage-attention --listen --port 3001 --preview-method latent2rgb
