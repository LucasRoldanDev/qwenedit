#!/usr/bin/env bash
set -e

WORKSPACE="$(pwd)"

echo "Downloading FLUX.1-dev models into: $WORKSPACE/models"

# Create required directories
mkdir -p \
  models/diffusion_models \
  models/clip \
  models/vae

# -------------------------
# FLUX.1-dev checkpoint (FP8)
# -------------------------
if [ ! -f models/diffusion_models/flux1-dev-fp8.safetensors ]; then
  wget -O models/diffusion_models/flux1-dev-fp8.safetensors \
    https://huggingface.co/Comfy-Org/flux1-dev/resolve/main/flux1-dev-fp8.safetensors
else
  echo "Flux dev checkpoint already exists"
fi

# -------------------------
# CLIP-L
# -------------------------
if [ ! -f models/clip/clip_l.safetensors ]; then
  wget -O models/clip/clip_l.safetensors \
    https://huggingface.co/GraydientPlatformAPI/flux-clip/resolve/main/clip_l.safetensors
else
  echo "✔ CLIP-L already exists"
fi

# -------------------------
# T5XXL encoder (FP8 scaled)
# -------------------------
if [ ! -f models/clip/t5xxl_fp8_e4m3fn_scaled.safetensors ]; then
  wget -O models/clip/t5xxl_fp8_e4m3fn.safetensors \
    https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors
else
  echo "✔ T5XXL encoder already exists"
fi

# -------------------------
# VAE (BF16)
# -------------------------
if [ ! -f models/vae/flux-vae-bf16.safetensors ]; then
  wget -O models/vae/flux-vae-bf16.safetensors \
    https://huggingface.co/Kijai/flux-fp8/resolve/main/flux-vae-bf16.safetensors
else
  echo "✔ Flux VAE already exists"
fi

echo "✅ FLUX.1-dev models downloaded successfully"
