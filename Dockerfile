# ---------------------------------------------------------------------
# BASE IMAGE
# ---------------------------------------------------------------------
FROM runpod/pytorch:1.0.2-cu1281-torch280-ubuntu2404

# Evitar prompts durante la instalación
ENV DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------
# SYSTEM UPDATES & PACKAGES
# ---------------------------------------------------------------------
# Ubuntu 24.04 ya incluye Python 3.12. No usamos PPA deadsnakes.
# Eliminamos nginx si existe (limpieza preventiva)
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y \
    software-properties-common \
    build-essential \
    git \
    python3-pip \
    python3-dev \
    python3-venv \
    wget \
    cmake \
    pkg-config \
    ninja-build \
    curl \
    lsof \
    psmisc && \
    rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------
# PYTHON & PYTORCH SETUP
# ---------------------------------------------------------------------
# Actualizamos pip
RUN python3 -m pip install --upgrade pip

# Instalar PyTorch 2.7.0 con CUDA 12.8 (Como solicita tu script)
# NOTA: Sobreescribimos la versión base para cumplir con tu script
RUN pip install torch==2.7.0 torchvision==0.22.0 torchaudio==2.7.0 --index-url https://download.pytorch.org/whl/cu128

# Instalar dependencias extra
RUN pip install triton packaging

# ---------------------------------------------------------------------
# SAGEATTENTION SETUP
# ---------------------------------------------------------------------
WORKDIR /workspace
# Descargamos e instalamos la wheel específica precompilada
RUN wget https://huggingface.co/nitin19/flash-attention-wheels/resolve/main/sageattention-2.1.1-cp312-cp312-linux_x86_64.whl && \
    pip install ./sageattention-2.1.1-cp312-cp312-linux_x86_64.whl && \
    rm ./sageattention-2.1.1-cp312-cp312-linux_x86_64.whl

# ---------------------------------------------------------------------
# COMFYUI INSTALLATION
# ---------------------------------------------------------------------
WORKDIR /workspace
RUN git clone https://github.com/comfyanonymous/ComfyUI.git

WORKDIR /workspace/ComfyUI
RUN pip install --no-cache-dir -r requirements.txt

# ---------------------------------------------------------------------
# CUSTOM NODES INSTALLATION
# ---------------------------------------------------------------------
WORKDIR /workspace/ComfyUI/custom_nodes

# Clonar todos los repositorios solicitados
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git && \
    git clone https://github.com/yolain/ComfyUI-Easy-Use.git && \
    git clone https://github.com/kijai/ComfyUI-KJNodes.git && \
    git clone https://github.com/cubiq/ComfyUI_essentials.git && \
    git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git && \
    git clone https://github.com/rgthree/rgthree-comfy.git && \
    git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git && \
    git clone https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git && \
    git clone https://github.com/calcuis/gguf.git && \
    git clone https://github.com/melMass/comfy_mtb.git && \
    git clone https://github.com/ClownsharkBatwing/RES4LYF.git

# Instalación automática de requirements.txt para todos los nodos custom
RUN for dir in *; do \
        if [ -d "$dir" ] && [ -f "$dir/requirements.txt" ]; then \
            echo "Instalando dependencias para $dir..."; \
            pip install --no-cache-dir -r "$dir/requirements.txt"; \
        fi; \
    done

# ---------------------------------------------------------------------
# CONFIGURATION (extra_model_paths.yaml)
# ---------------------------------------------------------------------
WORKDIR /workspace/ComfyUI

# Crear el archivo de configuración de rutas usando bash dentro de RUN
RUN /bin/bash -c 'cat <<EOF > extra_model_paths.yaml
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
EOF'

# Dar permisos de ejecución (aunque python lo ejecuta igual)
RUN chmod +x main.py

# ---------------------------------------------------------------------
# FINAL SETUP & LAUNCH
# ---------------------------------------------------------------------
# Exponer el puerto configurado
EXPOSE 3001

# Comando de inicio
# Usamos python3 directo (sin venv, ya que instalamos todo en system)
# "--listen 0.0.0.0" es necesario para que docker exponga el puerto al exterior
CMD ["python3", "main.py", "--use-sage-attention", "--listen", "0.0.0.0", "--port", "3001", "--preview-method", "latent2rgb"]
