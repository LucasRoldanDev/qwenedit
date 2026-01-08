#!/bin/bash

# =================================================================================
# VARIABLES DE CONFIGURACIÓN
# =================================================================================
WORKSPACE="/workspace"
COMFY_DIR="${WORKSPACE}/ComfyUI"
VENV_DIR="${COMFY_DIR}/venv"
SAGE_WHEEL="sageattention-2.1.1-cp312-cp312-linux_x86_64.whl"
SAGE_URL="https://huggingface.co/nitin19/flash-attention-wheels/resolve/main/$SAGE_WHEEL"

# Array con Custom Nodes
# AÑADIDO: city96/ComfyUI-GGUF (El soporte principal de GGUF)
NODES_URLS=(
    "https://github.com/ltdrdata/ComfyUI-Manager.git"
    "https://github.com/yolain/ComfyUI-Easy-Use.git"
    "https://github.com/kijai/ComfyUI-KJNodes.git"
    "https://github.com/cubiq/ComfyUI_essentials.git"
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git"
    "https://github.com/rgthree/rgthree-comfy.git"
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git"
    "https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git"
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
# 5. INSTALACIÓN DE CUSTOM NODES (Lista Automática)
# =================================================================================
echo ">>> [5/9] Instalando Nodos Personalizados (Incluido city96/GGUF)..."
mkdir -p custom_nodes && cd custom_nodes

# Instalamos la librería gguf de python necesaria para city96 y calcuis
pip install gguf

for repo_url in "${NODES_URLS[@]}"; do
    dir_name=$(basename "$repo_url" .git)
    if [ ! -d "$dir_name" ]; then
        echo "Clonando: $dir_name"
        git clone --depth 1 "$repo_url"
    else
        echo "Ya existe: $dir_name"
    fi
done

# =================================================================================
# 6. INSTALACIÓN MANUAL DE CALCUIS GGUF (Evitar conflicto)
# =================================================================================
# Nota: city96 ya se instaló arriba como 'ComfyUI-GGUF'. 
# Aquí instalamos calcuis con otro nombre para tener ambos.
echo ">>> [6/9] Instalando Node GGUF (Calcuis Version)..."
cd "$COMFY_DIR/custom_nodes"

if [ ! -d "ComfyUI-GGUF-Calcuis" ]; then
    echo "Clonando Calcuis GGUF como ComfyUI-GGUF-Calcuis..."
    git clone --depth 1 https://github.com/calcuis/gguf.git ComfyUI-GGUF-Calcuis
else
    echo "ComfyUI-GGUF-Calcuis ya existe."
fi

# Instalación de dependencias de todos los nodos
echo ">>> Instalando requirements.txt de todos los nodos..."
for dir in */; do
    if [ -f "${dir}requirements.txt" ]; then
        echo "Instalando deps para: $dir"
        pip install -r "${dir}requirements.txt"
    fi
done

# =================================================================================
# 7. DESCARGA DE LORAS EXTRA
# =================================================================================
if [ -n "$LORAS_URL" ]; then
    echo ">>> [7/9] Procesando LORAS_URL..."
    LORA_DIR="${COMFY_DIR}/models/loras"
    mkdir -p "$LORA_DIR"
    cd "$LORA_DIR"
    
    IFS=',' read -ra ADDR <<< "$LORAS_URL"
    for url in "${ADDR[@]}"; do
        clean_url=$(echo "$url" | xargs)
        if [ -n "$clean_url" ]; then
            echo "--> Descargando: $clean_url"
            wget --content-disposition "$clean_url" || echo "ADVERTENCIA: Falló descarga de $clean_url"
        fi
    done
else
    echo ">>> [7/9] No se detectó LORAS_URL."
fi

# =================================================================================
# 8. CONFIGURACIÓN YAML
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
# 9. EJECUCIÓN
# =================================================================================
echo ">>> [9/9] Iniciando ComfyUI..."
chmod +x main.py
source "$VENV_DIR/bin/activate"

# Ejecutar
python main.py --use-sage-attention --listen --port 3001 --preview-method latent2rgb
