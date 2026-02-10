#!/usr/bin/env bash
set -e

COMFY_BASE=/workspace/runpod-slim/ComfyUI
MODELS_BASE=$COMFY_BASE/models
CUSTOM_NODES=$COMFY_BASE/custom_nodes

echo "==> Going to ComfyUI directory"
cd "$COMFY_BASE"

# ---------- WAIT FOR .venv ----------
echo "==> Waiting for .venv directory to appear..."
while [ ! -d ".venv" ]; do
  echo "    ⏳ .venv not found yet, waiting..."
  sleep 2
done

echo "    ✓ .venv found"

# ---------- EXTRA GRACE TIME ----------
echo "==> Waiting extra 5 seconds for venv to stabilize"
sleep 5



# =========================================================
# 📦 MODELS SETUP
# =========================================================

echo "==> Creating model folders"
mkdir -p \
  $MODELS_BASE/loras \
  $MODELS_BASE/controlnet \
  $MODELS_BASE/vae \
  $MODELS_BASE/diffusion_models \
  $MODELS_BASE/text_encoders



echo "==> Download Qwen-Image-InstantX-ControlNet"
cd $MODELS_BASE/controlnet
curl -L -O https://huggingface.co/Comfy-Org/Qwen-Image-InstantX-ControlNets/resolve/main/split_files/controlnet/Qwen-Image-InstantX-ControlNet-Union.safetensors

echo "==> Download qwen_image_fp8_e4m3fn diffusion_models"
cd $MODELS_BASE/diffusion_models
curl -L -O https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_fp8_e4m3fn.safetensors

echo "==> Download lotus-depth-d-v1-1 diffusion_models"
cd $MODELS_BASE/diffusion_models
curl -L -O https://huggingface.co/Comfy-Org/lotus/resolve/main/lotus-depth-d-v1-1.safetensors

echo "==> Download LoRA Qwen-Image-Lightning-4steps-V1.0"
cd $MODELS_BASE/loras
curl -L -O https://huggingface.co/lightx2v/Qwen-Image-Lightning/resolve/main/Qwen-Image-Lightning-4steps-V1.0.safetensors

echo "==> Download text_encoders qwen_2.5_vl_7b_fp8_scaled"
cd $MODELS_BASE/text_encoders
curl -L -O https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors

echo "==> Download vae vae-ft-mse-840000-ema-pruned"
cd $MODELS_BASE/vae
curl -L -O https://huggingface.co/stabilityai/sd-vae-ft-mse-original/resolve/main/vae-ft-mse-840000-ema-pruned.safetensors

echo "==> Download vae qwen_image_vae"
cd $MODELS_BASE/vae
curl -L -O https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors



echo "==> DONE ✅ Environment + nodes + models ready"
