#!/usr/bin/env bash
set -e

COMFY_BASE=/workspace/runpod-slim/ComfyUI
MODELS_BASE=$COMFY_BASE/models
CUSTOM_NODES=$COMFY_BASE/custom_nodes

echo "==> Going to ComfyUI directory"
cd "$COMFY_BASE"

# ---------- WAIT FOR .venv ----------
echo "==> Waiting for .venv directory..."
while [ ! -d ".venv" ]; do
  echo "    ⏳ Waiting for .venv..."
  sleep 2
done

echo "    ✓ .venv found"
sleep 5

# ---------- ACTIVATE ----------
echo "==> Activating virtual environment"
source .venv/bin/activate
echo "==> Python path: $(which python)"

# =========================================================
# 🔥 FIX TORCH FOR RTX 5090 (VERY IMPORTANT)
# =========================================================

echo "==> Installing PyTorch with CUDA 13 support"
pip uninstall -y torch torchvision torchaudio

pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu130


# =========================================================
# 🔥 INSTALL PYTHON REQUIREMENTS (LOCKED & CONTROLLED)
# =========================================================

echo "==> Installing Python dependencies from ltx-2-models-downloader"
pip install -r https://raw.githubusercontent.com/rjamitsharma01/ltx-2-models-downloader/main/requirements.txt

# =========================================================
# 🔥 CUSTOM NODES (GIT CLONE / UPDATE)
# =========================================================

echo "==> Setting up custom nodes"
mkdir -p "$CUSTOM_NODES"
cd "$CUSTOM_NODES"

clone_or_update () {
  local repo=$1
  local name=$(basename "$repo" .git)

  if [ -d "$name/.git" ]; then
    echo "==> Updating $name"
    cd "$name"
    git pull
    cd ..
  else
    echo "==> Cloning $name"
    git clone "$repo"
  fi
}

clone_or_update https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git
clone_or_update https://github.com/kijai/ComfyUI-segment-anything-2.git
clone_or_update https://github.com/un-seen/comfyui-tensorops.git

# =========================================================
# 📦 MODELS SETUP
# =========================================================

echo "==> Creating model folders"
mkdir -p \
  $MODELS_BASE/diffusion_models \
  $MODELS_BASE/vae \
  $MODELS_BASE/text_encoders \
  $MODELS_BASE/loras \

echo "==> Download LTX-2 checkpoint"
cd $MODELS_BASE/diffusion_models
# curl -L -O https://huggingface.co/Orange-3DV-Team/MoCha/resolve/main/preview/step18500.ckpt
curl -L -O hhttps://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/MoCha/Wan2_1_mocha-14B-preview_fp8_e4m3fn_scaled_KJ.safetensors

echo "==> Download LTX-2 spatial upscaler"
cd $MODELS_BASE/vae
curl -L -O https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors

echo "==> Download LTX-2 spatial upscaler"
cd $MODELS_BASE/text_encoders
curl -L -O https://huggingface.co/Kijai/WanVideo_comfy/blob/main/umt5-xxl-enc-fp8_e4m3fn.safetensors



echo "==> Download IC LoRA Pose Control"
cd $MODELS_BASE/loras
curl -L -O https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_T2V_14B_cfg_step_distill_v2_lora_rank256_bf16.safetensors

echo "==> DONE ✅ Environment + nodes + models ready"


