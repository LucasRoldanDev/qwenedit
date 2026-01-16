# FROM runpod/pytorch:1.0.2-cu1281-torch280-ubuntu2404 <---- modern cuda

# Old cuda for  old compatibility
FROM runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04 

ENV DEBIAN_FRONTEND=noninteractive
ENV WORKSPACE="/workspace"
ENV COMFY_DIR="${WORKSPACE}/ComfyUI"
ENV VENV_DIR="${COMFY_DIR}/venv"
ENV PATH="${VENV_DIR}/bin:$PATH" 
ENV COMFYUI_VERSION="v0.4.0"

# 1. Preparación del sistema (Limpiamos caché apt al final de la misma capa)
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y software-properties-common build-essential git python3-pip wget cmake pkg-config ninja-build curl \
    python3.12 python3.12-venv python3.12-dev && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 && \
    update-alternatives --set python3 /usr/bin/python3.12 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 2. Instalación de ComfyUI
WORKDIR ${WORKSPACE}
RUN git clone https://github.com/comfyanonymous/ComfyUI.git ${COMFY_DIR} && \
    cd ${COMFY_DIR} && \
    git fetch --all --tags && \
    git checkout ${COMFYUI_VERSION}

WORKDIR ${COMFY_DIR}

# --- PUNTOS CRÍTICOS PARA AHORRAR ESPACIO ---

# A: Usar system-site-packages para reciclar el Torch de la imagen base
RUN python3 -m venv venv --system-site-packages

# B: --no-cache-dir es vital
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install --no-cache-dir "huggingface_hub[cli]"

# 3. Custom Nodes
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

# C: Eliminar torch de los requirements de los nodos para no reinstalarlo
RUN for dir in */; do \
        if [ -f "$dir/requirements.txt" ]; then \
            sed -i '/torch/d' "$dir/requirements.txt"; \
            sed -i '/opencv-python/d' "$dir/requirements.txt"; \
            pip install --no-cache-dir -r "$dir/requirements.txt" || echo "Warning: Failed reqs for $dir"; \
        fi; \
    done

RUN pip install --no-cache-dir opencv-python-headless

# 4. Config Final
COPY start.sh /start.sh
RUN chmod +x /start.sh

WORKDIR ${COMFY_DIR}
CMD ["/bin/bash", "-c", "curl -fsSL https://raw.githubusercontent.com/LucasRoldanDev/qwenedit/refs/heads/main/start.sh | bash"]
