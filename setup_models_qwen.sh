#!/usr/bin/env bash
set -e

WORKSPACE="$(pwd)"

echo "📥 Downloading Qwen Image models into: $WORKSPACE/models"

# Create required directories
mkdir -p \
  models/clip \
  models/vae \
  models/loras \
  models/unet

# -------------------------
# Text encoder (Qwen VL)
# -------------------------
if [ ! -f models/clip/qwen_2.5_vl_7b_fp8_scaled.safetensors ]; then
  wget -O models/clip/qwen_2.5_vl_7b_fp8_scaled.safetensors \
    https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors
else
  echo "✔ Qwen text encoder already exists"
fi

# -------------------------
# VAE
# -------------------------
if [ ! -f models/vae/qwen_image_vae.safetensors ]; then
  wget -O models/vae/qwen_image_vae.safetensors \
    https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors
else
  echo "✔ Qwen VAE already exists"
fi

# -------------------------
# Lightning LoRA (V1 → V2 rename)
# -------------------------
if [ ! -f models/loras/Qwen-Image-Edit-2509-Lightning-4steps-V2.0-fp32.safetensors ]; then
  wget -O models/loras/Qwen-Image-Edit-2509-Lightning-4steps-V2.0-fp32.safetensors \
    https://huggingface.co/lightx2v/Qwen-Image-Lightning/resolve/main/Qwen-Image-Edit-2509/Qwen-Image-Edit-2509-Lightning-4steps-V1.0-fp32.safetensors
else
  echo "✔ Qwen Lightning LoRA already exists"
fi

# -------------------------
# GGUF UNet model
# -------------------------
if [ ! -f models/unet/Qwen-Image-Edit-2509-Q5_K_S.gguf ]; then
  wget -O models/unet/Qwen-Image-Edit-2509-Q5_K_S.gguf \
    https://huggingface.co/QuantStack/Qwen-Image-Edit-2509-GGUF/resolve/main/Qwen-Image-Edit-2509-Q5_K_S.gguf
else
  echo "✔ Qwen GGUF UNet already exists"
fi

echo "✅ Qwen models downloaded successfully"
