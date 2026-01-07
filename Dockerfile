# Base image with ComfyUI
FROM runpod/worker-comfyui:5.5.1-base

# ============================
# System dependencies
# ============================
RUN apt-get update && \
    apt-get install -y git && \
    rm -rf /var/lib/apt/lists/*

# ============================
# Install custom nodes
# ============================
WORKDIR /comfyui/custom_nodes

# Use shallow clones to reduce RAM & network usage
RUN git clone --depth=1 https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git && \
    git clone --depth=1 https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git && \
    git clone --depth=1 https://github.com/calcuis/gguf.git && \
    git clone --depth=1 https://github.com/melMass/comfy_mtb.git && \
    git clone --depth=1 https://github.com/yolain/ComfyUI-Easy-Use.git

# Return to ComfyUI root
WORKDIR /comfyui

# ============================
# Runtime model download note
# ============================
# IMPORTANT:
# Models MUST be downloaded at runtime (entrypoint / start command),
# not during docker build, to avoid EOF / BuildKit crashes.
#
# Example runtime command:
# comfy model download --url <url> --relative-path models/...
