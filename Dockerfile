# Base solicitada
FROM runpod/pytorch:1.0.2-cu1281-torch280-ubuntu2404

# Evitar interacciones durante la instalación
ENV DEBIAN_FRONTEND=noninteractive

# Variables de entorno
ENV WORKSPACE="/workspace"
ENV COMFY_DIR="${WORKSPACE}/ComfyUI"
ENV VENV_DIR="${COMFY_DIR}/venv"
# TRUCO: Añadimos el venv al PATH del sistema. 
# Así no necesitamos hacer "source venv/bin/activate" en cada línea.
ENV PATH="${VENV_DIR}/bin:$PATH" 
ENV COMFYUI_VERSION="v0.4.0"

# =================================================================================
# 1. PREPARACIÓN DEL SISTEMA
# =================================================================================
# Instalamos dependencias de sistema y Python 3.12 (si no viniera por defecto)
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

# Clonar ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git ${COMFY_DIR} && \
    cd ${COMFY_DIR} && \
    git fetch --all --tags && \
    git checkout ${COMFYUI_VERSION}

WORKDIR ${COMFY_DIR}

# Crear el entorno virtual
RUN python3 -m venv venv

# --- A PARTIR DE AQUÍ TODO CORRE DENTRO DEL VENV GRACIAS A LA VARIABLE PATH ---

# 1. Actualizar pip y wheel
RUN pip install --upgrade pip wheel

# 2. Instalar PyTorch
# CAMBIO IMPORTANTE: Usamos el index-url de cu124. Es compatible con cu128.
# Si 2.7.0 falla aquí, es porque esa versión específica no está en el repo estable,
# intenta cambiar a una versión estable conocida o el index-url a nightly si es experimental.
RUN pip install torch==2.7.0 torchvision==0.22.0 torchaudio==2.7.0 --index-url https://download.pytorch.org/whl/cu124

# 3. Dependencias extra de PyTorch
RUN pip install triton packaging

# 4. Requirements de ComfyUI
RUN pip install -r requirements.txt

# 5. SageAttention
# Descargamos primero para asegurar que la URL funciona
RUN wget "https://huggingface.co/nitin19/flash-attention-wheels/resolve/main/sageattention-2.1.1-cp312-cp312-linux_x86_64.whl" -O sage.whl && \
    pip install sage.whl && \
    rm sage.whl

# 6. Huggingface CLI (necesario para el script de arranque)
RUN pip install "huggingface_hub[cli]"

# =================================================================================
# 3. INSTALACIÓN DE CUSTOM NODES
# =================================================================================
WORKDIR ${COMFY_DIR}/custom_nodes

# Clonamos los repositorios
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

# Instalamos requirements de los nodos
# Usamos un bucle seguro para instalar
RUN for dir in */; do \
        if [ -f "$dir/requirements.txt" ]; then \
            echo "Installing requirements for $dir"; \
            pip install -r "$dir/requirements.txt" || echo "Warning: Failed to install reqs for $dir"; \
        fi; \
    done

# =================================================================================
# 4. CONFIGURACIÓN FINAL
# =================================================================================
# Copiar el script de arranque (entrypoint) que debes tener en tu carpeta local
COPY start.sh /start.sh
RUN chmod +x /start.sh

WORKDIR ${COMFY_DIR}

# Comando de inicio
CMD ["/start.sh"]
