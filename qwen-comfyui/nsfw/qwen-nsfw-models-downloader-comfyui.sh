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

echo "==> Download Qwen-Rapid-AIO-NSFW-v23 checkpoint"
cd $MODELS_BASE/checkpoints
curl -L -O https://huggingface.co/Phr00t/Qwen-Image-Edit-Rapid-AIO/resolve/main/v23/Qwen-Rapid-AIO-NSFW-v23.safetensors


echo "==> DONE ✅ Environment + nodes + models ready"
