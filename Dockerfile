# clean base image containing only comfyui, comfy-cli and comfyui-manager
FROM runpod/worker-comfyui:5.5.1-base

# ============================
# Install custom nodes manually
# ============================
WORKDIR /comfyui/custom_nodes

# ComfyUI Custom Scripts (pysssss)
RUN git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git

# Inpaint Crop and Stitch (Improved Inpaint nodes)
RUN git clone https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git

# GGUF Loader support
RUN git clone https://github.com/calcuis/gguf.git

# Return to comfyui root
WORKDIR /comfyui

# ============================
# Download models into ComfyUI
# ============================

RUN comfy model download \
    --url https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors \
    --relative-path models/clip \
    --filename qwen_2.5_vl_7b_fp8_scaled.safetensors

RUN comfy model download \
    --url https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors \
    --relative-path models/vae \
    --filename qwen_image_vae.safetensors

# NOTE: Original requested filename for this LoRA was "Public\\Qween\\Qwen-Image-Edit-2509-Lightning-4steps-V2.0-fp32.safetensors"
# Using V1.0 and renaming
RUN comfy model download \
    --url https://huggingface.co/lightx2v/Qwen-Image-Lightning/resolve/main/Qwen-Image-Edit-2509/Qwen-Image-Edit-2509-Lightning-4steps-V1.0-fp32.safetensors \
    --relative-path models/loras \
    --filename Qwen-Image-Edit-2509-Lightning-4steps-V2.0-fp32.safetensors

RUN comfy model download \
    --url https://huggingface.co/QuantStack/Qwen-Image-Edit-2509-GGUF/resolve/main/Qwen-Image-Edit-2509-Q5_K_S.gguf \
    --relative-path models/diffusion_models \
    --filename Qwen-Image-Edit-2509-Q5_K_S.gguf

# ============================
# Optional input copy
# ============================
# COPY input/ /comfyui/input/
