#!/usr/bin/env bash
set -e

WORKSPACE="$(pwd)"

echo "📥 Downloading Qwen Image (FP8) models into: $WORKSPACE/models"

# Create required directories
mkdir -p \
  models/clip \
  models/vae \
  models/loras \
  models/unet

# -------------------------
# Diffusion Model (Main FP8)
# -------------------------
if [ ! -f models/unet/qwen_image_fp8_e4m3fn.safetensors ]; then
  echo "Downloading Diffusion Model..."
  wget -O models/unet/qwen_image_fp8_e4m3fn.safetensors \
    https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_fp8_e4m3fn.safetensors
else
  echo "✔ Diffusion model (FP8) already exists"
fi

# -------------------------
# Text encoder (Qwen VL)
# -------------------------
if [ ! -f models/clip/qwen_2.5_vl_7b_fp8_scaled.safetensors ]; then
  echo "Downloading Text Encoder..."
  wget -O models/clip/qwen_2.5_vl_7b_fp8_scaled.safetensors \
    https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors
else
  echo "✔ Qwen text encoder already exists"
fi

# -------------------------
# VAE
# -------------------------
if [ ! -f models/vae/qwen_image_vae.safetensors ]; then
  echo "Downloading VAE..."
  wget -O models/vae/qwen_image_vae.safetensors \
    https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors
else
  echo "✔ Qwen VAE already exists"
fi

# -------------------------
# Lightning LoRAs
# -------------------------

# 8 Steps
if [ ! -f models/loras/Qwen-Image-Lightning-8steps-V2.0.safetensors ]; then
  echo "Downloading LoRA (8 steps)..."
  wget -O models/loras/Qwen-Image-Lightning-8steps-V2.0.safetensors \
    https://huggingface.co/lightx2v/Qwen-Image-Lightning/resolve/main/Qwen-Image-Lightning-8steps-V2.0.safetensors
else
  echo "✔ LoRA (8 steps) already exists"
fi

# 4 Steps
if [ ! -f models/loras/Qwen-Image-Lightning-4steps-V2.0.safetensors ]; then
  echo "Downloading LoRA (4 steps)..."
  wget -O models/loras/Qwen-Image-Lightning-4steps-V2.0.safetensors \
    https://huggingface.co/lightx2v/Qwen-Image-Lightning/resolve/main/Qwen-Image-Lightning-4steps-V2.0.safetensors
else
  echo "✔ LoRA (4 steps) already exists"
fi

echo "✅ All Qwen FP8 models downloaded successfully"
