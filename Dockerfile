FROM runpod/worker-comfyui:5.5.1-base

# System deps
RUN apt-get update && \
    apt-get install -y git && \
    rm -rf /var/lib/apt/lists/*

# Python deps needed by ComfyUI Manager / nodes
RUN pip install --no-cache-dir GitPython

# Custom nodes
WORKDIR /comfyui/custom_nodes

RUN git clone --depth=1 https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git && \
    git clone --depth=1 https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git && \
    git clone --depth=1 https://github.com/calcuis/gguf.git && \
    git clone --depth=1 https://github.com/melMass/comfy_mtb.git && \
    git clone --depth=1 https://github.com/yolain/ComfyUI-Easy-Use.git

WORKDIR /comfyui
