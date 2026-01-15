# Base solicitada
FROM runpod/pytorch:1.0.2-cu1281-torch280-ubuntu2404

# Evitar interacciones durante la instalación
ENV DEBIAN_FRONTEND=noninteractive

# Variables de entorno fijas para la construcción
ENV WORKSPACE="/workspace"
ENV COMFY_DIR="${WORKSPACE}/ComfyUI"
ENV VENV_DIR="${COMFY_DIR}/venv"
# Añadimos el venv al PATH para que 'python' y 'pip' sean los del entorno virtual por defecto
ENV PATH="${VENV_DIR}/bin:$PATH" 
ENV COMFYUI_VERSION="v0.4.0"

# =================================================================================
# 1. PREPARACIÓN DEL SISTEMA Y PYTHON 3.12
# =================================================================================
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y software-properties-common build-essential git python3-pip wget cmake pkg-config ninja-build curl && \
    # Instalar Python 3.12
    add-apt-repository ppa:deadsnakes/ppa -y && \
    apt-get update && \
    apt-get install -y python3.12 python3.12-venv python3.12-dev && \
    # Configurar Python 3.12 como default
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 && \
    update-alternatives --set python3 /usr/bin/python3.12 && \
    # Limpieza
    apt-get clean && rm -rf /var/lib/apt/lists/*

# =================================================================================
# 2. INSTALACIÓN DE COMFYUI Y VENV
# =================================================================================
WORKDIR ${WORKSPACE}

RUN git clone https://github.com/comfyanonymous/ComfyUI.git ${COMFY_DIR} && \
    cd ${COMFY_DIR} && \
    git fetch --all --tags && \
    git checkout ${COMFYUI_VERSION}

# Crear entorno virtual e instalar dependencias base
WORKDIR ${COMFY_DIR}
RUN python3 -m venv venv && \
    # Actualizar pip dentro del venv
    pip install --upgrade pip && \
    # Instalar PyTorch 2.7 (Según tu script)
    pip install torch==2.7.0 torchvision==0.22.0 torchaudio==2.7.0 --index-url https://download.pytorch.org/whl/cu128 && \
    pip install triton packaging && \
    # Dependencias de ComfyUI
    pip install -r requirements.txt && \
    # SageAttention
    wget "https://huggingface.co/nitin19/flash-attention-wheels/resolve/main/sageattention-2.1.1-cp312-cp312-linux_x86_64.whl" -O sage.whl && \
    pip install sage.whl && \
    rm sage.whl && \
    # Herramienta para descargas HF (necesaria para el script de arranque)
    pip install "huggingface_hub[cli]"

# =================================================================================
# 3. INSTALACIÓN DE CUSTOM NODES
# =================================================================================
WORKDIR ${COMFY_DIR}/custom_nodes

# Clonamos los repositorios definidos en tu script
RUN git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git && \
    git clone --depth 1 https://github.com/yolain/ComfyUI-Easy-Use.git && \
    git clone --depth 1 https://github.com/kijai/ComfyUI-KJNodes.git && \
    git clone --depth 1 https://github.com/cubiq/ComfyUI_essentials.git && \
    git clone --depth 1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git && \
    git clone --depth 1 https://github.com/rgthree/rgthree-comfy.git && \
    git clone --depth 1 https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git && \
    git clone --depth 1 https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git && \
    git clone --depth 1 https://github.com/calcuis/gguf.git && \
    git clone --depth 1 https://github.com/melMass/comfy_mtb.git && \
    git clone --depth 1 https://github.com/city96/ComfyUI-GGUF.git && \
    git clone --depth 1 https://github.com/ClownsharkBatwing/RES4LYF.git

# Instalamos los requirements de todos los nodos descargados
RUN for dir in */; do \
        if [ -f "$dir/requirements.txt" ]; then \
            echo "Installing requirements for $dir"; \
            pip install -r "$dir/requirements.txt"; \
        fi; \
    done

# Copiar el script de arranque (entrypoint)
COPY start.sh /start.sh
RUN chmod +x /start.sh

WORKDIR ${COMFY_DIR}

# El comando por defecto ejecutará el script de lógica
CMD ["/start.sh"]
