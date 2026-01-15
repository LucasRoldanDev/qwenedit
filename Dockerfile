# Base solicitada
FROM runpod/pytorch:1.0.2-cu1281-torch280-ubuntu2404

ENV DEBIAN_FRONTEND=noninteractive
ENV WORKSPACE="/workspace"
ENV COMFY_DIR="${WORKSPACE}/ComfyUI"
ENV VENV_DIR="${COMFY_DIR}/venv"
# Añadimos el venv al PATH para no repetir source activate
ENV PATH="${VENV_DIR}/bin:$PATH" 
ENV COMFYUI_VERSION="v0.4.0"

# =================================================================================
# 1. PREPARACIÓN DEL SISTEMA
# =================================================================================
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y software-properties-common build-essential git python3-pip wget cmake pkg-config ninja-build curl \
    python3.12 python3.12-venv python3.12-dev && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 && \
    update-alternatives --set python3 /usr/bin/python3.12 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# =================================================================================
# 2. INSTALACIÓN DE COMFYUI Y VENV
# =================================================================================
WORKDIR ${WORKSPACE}

RUN git clone https://github.com/comfyanonymous/ComfyUI.git ${COMFY_DIR} && \
    cd ${COMFY_DIR} && \
    git fetch --all --tags && \
    git checkout ${COMFYUI_VERSION}

WORKDIR ${COMFY_DIR}
RUN python3 -m venv venv

# --- INSTALACIÓN DE DEPENDENCIAS ---

# 1. Pip base
RUN pip install --upgrade pip wheel

# 2. PyTorch (Directo de PyPI para máxima compatibilidad)
RUN pip install torch==2.7.0 torchvision==0.22.0 torchaudio==2.7.0

# 3. Dependencias extra
RUN pip install triton packaging

# 4. Requirements de ComfyUI
RUN pip install -r requirements.txt

# 5. SageAttention (CORREGIDO: Instalación directa desde URL)
RUN pip install "https://huggingface.co/nitin19/flash-attention-wheels/resolve/main/sageattention-2.1.1-cp312-cp312-linux_x86_64.whl"

# 6. Huggingface CLI
RUN pip install "huggingface_hub[cli]"

# =================================================================================
# 3. INSTALACIÓN DE CUSTOM NODES
# =================================================================================
WORKDIR ${COMFY_DIR}/custom_nodes

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
    git clone --depth 1 https://github.com/ClownsharkBatwing/RES4LYF.git && \
    git clone --depth 1 https://github.com/TinyTerra/ComfyUI_tinyterraNodes

# Instalación de requirements de nodos
RUN for dir in */; do \
        if [ -f "$dir/requirements.txt" ]; then \
            echo "Installing requirements for $dir"; \
            pip install -r "$dir/requirements.txt" || echo "Warning: Failed to install reqs for $dir"; \
        fi; \
    done

# =================================================================================
# 4. CONFIGURACIÓN FINAL
# =================================================================================
COPY start.sh /start.sh
RUN chmod +x /start.sh

WORKDIR ${COMFY_DIR}
# En lugar de copiar un archivo local, le decimos que descargue y ejecute el remoto al iniciar
CMD ["/bin/bash", "-c", "curl -fsSL https://raw.githubusercontent.com/LucasRoldanDev/qwenedit/refs/heads/main/start.sh | bash"]
