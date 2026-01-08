#!/bin/bash

# =================================================================================
# VARIABLES DE CONFIGURACIÓN
# =================================================================================
WORKSPACE="/workspace"
COMFY_DIR="${WORKSPACE}/ComfyUI"
VENV_DIR="${COMFY_DIR}/venv"
SAGE_WHEEL="sageattention-2.1.1-cp312-cp312-linux_x86_64.whl"
SAGE_URL="https://huggingface.co/nitin19/flash-attention-wheels/resolve/main/$SAGE_WHEEL"

# Array con todos los Custom Nodes (Evita código repetido)
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
    "https://github.com/ClownsharkBatwing/RES4LYF.git"
)

# =================================================================================
# 1. PREPARACIÓN DEL SISTEMA Y PYTHON 3.12
# =================================================================================
echo ">>> [1/7] Actualizando sistema e instalando dependencias base..."
apt update && apt upgrade -y
apt install -y software-properties-common build-essential git python3-pip wget cmake pkg-config ninja-build

# Nota: Aunque Ubuntu 24.04 trae Python 3.12, ejecutamos esto para asegurar el entorno dev
add-apt-repository ppa:deadsnakes/ppa -y || echo "PPA ya existe o no es necesario"
apt update
apt install -y python3.12 python3.12-venv python3.12-dev

# Forzar Python 3.12 como predeterminado
update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1
update-alternatives --set python3 /usr/bin/python3.12

echo ">>> Versión de Python del sistema: $(python3 --version)"

# Limpieza de puertos (Nginx/3001)
systemctl stop nginx 2>/dev/null || true
pkill -f nginx || true
fuser -k 3001/tcp || true

# =================================================================================
# 2. INSTALACIÓN DE COMFYUI (OBLIGATORIO)
# =================================================================================
echo ">>> [2/7] Instalando ComfyUI..."
mkdir -p "$WORKSPACE"
cd "$WORKSPACE"

# Si existe la carpeta, la borramos para asegurar una instalación limpia (opcional, pero recomendado si quieres garantizar que funcione)
if [ -d "$COMFY_DIR" ]; then
    echo "Carpeta ComfyUI detectada. Actualizando..."
    cd "$COMFY_DIR" && git pull
else
    git clone https://github.com/comfyanonymous/ComfyUI.git
fi

# =================================================================================
# 3. CREACIÓN DEL ENTORNO VIRTUAL
# =================================================================================
echo ">>> [3/7] Creando entorno virtual (venv)..."
cd "$COMFY_DIR"
# Recreamos el venv para asegurar que esté limpio
rm -rf venv
python3 -m venv venv
source venv/bin/activate

echo ">>> Versión de Python en venv: $(python --version)"
pip install --upgrade pip

# =================================================================================
# 4. INSTALACIÓN DE PYTORCH Y SAGEATTENTION (OBLIGATORIO)
# =================================================================================
echo ">>> [4/7] Instalando PyTorch 2.7 y SageAttention..."

# Instalar PyTorch 2.7.0 con CUDA 12.8
pip install torch==2.7.0 torchvision==0.22.0 torchaudio==2.7.0 --index-url https://download.pytorch.org/whl/cu128

# Instalar dependencias previas
pip install triton packaging

# --- AQUI SE INSTALA SAGEATTENTION ---
cd "$WORKSPACE"
echo "Descargando SageAttention Wheel..."
rm -f "$SAGE_WHEEL" # Borrar si existía uno corrupto
wget "$SAGE_URL"

echo "Instalando SageAttention..."
pip install "./$SAGE_WHEEL"

# Verificar instalación
echo "Verificando instalaciones críticas:"
python -c 'import torch; print(f"Torch: {torch.__version__}, CUDA: {torch.version.cuda}")'
python -c 'import sageattention; print("SageAttention instalado correctamente")' || echo "ERROR: Falló SageAttention"

# Instalar requisitos base de ComfyUI
cd "$COMFY_DIR"
pip install -r requirements.txt

# =================================================================================
# 5. INSTALACIÓN DE CUSTOM NODES (Usando Array)
# =================================================================================
echo ">>> [5/7] Instalando Nodos Personalizados..."
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

# Instalar requirements.txt de cada nodo automáticamente
echo ">>> Instalando dependencias de los nodos..."
for dir in */; do
    if [ -f "${dir}requirements.txt" ]; then
        echo "Instalando deps para: $dir"
        pip install -r "${dir}requirements.txt"
    fi
done

# =================================================================================
# 6. CONFIGURACIÓN YAML
# =================================================================================
echo ">>> [6/7] Generando configuración de rutas..."
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
# 7. EJECUCIÓN
# =================================================================================
echo ">>> [7/7] Iniciando ComfyUI..."
chmod +x main.py

# Asegurar que estamos en el venv antes de lanzar
source "$VENV_DIR/bin/activate"

# Lanzar con SageAttention activado
python main.py --use-sage-attention --listen --port 3001 --preview-method latent2rgb
