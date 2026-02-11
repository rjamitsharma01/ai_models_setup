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

# ---------- ACTIVATE ----------
echo "==> Activating ComfyUI virtual environment"
source .venv/bin/activate
echo "==> VENV activated: $(which python)"

# =========================================================
# 🔥 INSTALL PYTHON REQUIREMENTS (LOCKED & CONTROLLED)
# =========================================================

echo "==> Installing Python dependencies from ltx-2-models-downloader"
pip install -r https://raw.githubusercontent.com/rjamitsharma01/ai_models_setup/main/ltx2-comfyui/RTX4090/requirements.txt

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

clone_or_update https://github.com/rjamitsharma01/ComfyUI-LTXVideo-locked
clone_or_update https://github.com/Fannovel16/comfyui_controlnet_aux
clone_or_update https://github.com/ltdrdata/ComfyUI-Impact-Pack
clone_or_update https://github.com/akatz-ai/ComfyUI-DepthCrafter-Nodes
clone_or_update https://github.com/evanspearman/ComfyMath
clone_or_update https://github.com/shizuka-ai/ComfyUI-tbox

# =========================================================
# 📦 MODELS SETUP
# =========================================================

echo "==> Creating model folders"
mkdir -p \
  $MODELS_BASE/checkpoints \
  $MODELS_BASE/loras \
  $MODELS_BASE/latent_upscale_models \
  $MODELS_BASE/text_encoders

echo "==> Download LTX-2 checkpoint"
cd $MODELS_BASE/checkpoints
curl -L -O https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-19b-distilled-fp8.safetensors

echo "==> Download LTX-2 spatial upscaler"
cd $MODELS_BASE/latent_upscale_models
curl -L -O https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-spatial-upscaler-x2-1.0.safetensors

echo "==> Setup Gemma text encoder"
cd $MODELS_BASE/text_encoders
rm -rf gemma-3-12b-it-bnb-4bit
git clone https://huggingface.co/unsloth/gemma-3-12b-it-bnb-4bit
cd gemma-3-12b-it-bnb-4bit

rm -f model-00001-of-00002.safetensors model-00002-of-00002.safetensors

curl -L -O https://huggingface.co/unsloth/gemma-3-12b-it-bnb-4bit/resolve/main/model-00001-of-00002.safetensors
curl -L -O https://huggingface.co/unsloth/gemma-3-12b-it-bnb-4bit/resolve/main/model-00002-of-00002.safetensors
curl -L -O https://huggingface.co/unsloth/gemma-3-12b-it-bnb-4bit/resolve/main/tokenizer.json
curl -L -O https://huggingface.co/unsloth/gemma-3-12b-it-bnb-4bit/resolve/main/tokenizer.model

echo "==> Download IC LoRA Pose Control"
cd $MODELS_BASE/loras
curl -L -O https://huggingface.co/Lightricks/LTX-2-19b-IC-LoRA-Pose-Control/resolve/main/ltx-2-19b-ic-lora-pose-control.safetensors

echo "==> DONE ✅ Environment + nodes + models ready"
