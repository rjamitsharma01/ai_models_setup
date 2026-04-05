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
  sleep 2
done

sleep 5

# ---------- ACTIVATE ----------
source .venv/bin/activate
echo "==> VENV: $(which python)"

# =========================================================
# 🔥 REQUIREMENTS
# =========================================================
# pip install -r https://raw.githubusercontent.com/rjamitsharma01/ai_models_setup/main/ltx2-comfyui/RTX4090/requirements.txt

# =========================================================
# 🔥 CUSTOM NODES
# =========================================================
cd "$CUSTOM_NODES"

clone_or_update () {
  local repo=$1
  local name=$(basename "$repo" .git)

  if [ -d "$name/.git" ]; then
    cd "$name" && git pull && cd ..
  else
    git clone "$repo"
  fi
}

# clone_or_update https://github.com/rjamitsharma01/ComfyUI-LTXVideo-locked
clone_or_update https://github.com/Lightricks/ComfyUI-LTXVideo.git
clone_or_update https://github.com/Fannovel16/comfyui_controlnet_aux
clone_or_update https://github.com/ltdrdata/ComfyUI-Impact-Pack
clone_or_update https://github.com/evanspearman/ComfyMath

# =========================================================
# 📦 MODEL FOLDERS
# =========================================================
mkdir -p \
  $MODELS_BASE/diffusion_models \
  $MODELS_BASE/vae \
  $MODELS_BASE/loras \
  $MODELS_BASE/text_encoders

# =========================================================
# 🔥 LTX 2.3 MAIN MODEL
# =========================================================
echo "==> Download LTX 2.3"
cd $MODELS_BASE/diffusion_models

curl -L -O https://huggingface.co/Kijai/LTX2.3_comfy/resolve/main/diffusion_models/ltx-2.3-22b-distilled_transformer_only_fp8_input_scaled_v3.safetensors

# =========================================================
# 🔥 VAE (VIDEO + AUDIO)
# =========================================================
cd $MODELS_BASE/vae

curl -L -O https://huggingface.co/Kijai/LTX2.3_comfy/resolve/main/vae/LTX23_video_vae_bf16.safetensors
curl -L -O https://huggingface.co/Kijai/LTX2.3_comfy/resolve/main/vae/LTX23_audio_vae_bf16.safetensors

# =========================================================
# 🔥 TEXT ENCODERS (GEMMA + LTX)
# =========================================================
cd $MODELS_BASE/text_encoders

curl -L -O https://huggingface.co/Comfy-Org/ltx-2/resolve/main/split_files/text_encoders/gemma_3_12B_it_fp8_scaled.safetensors
curl -L -O https://huggingface.co/Kijai/LTX2.3_comfy/resolve/main/text_encoders/ltx-2.3_text_projection_bf16.safetensors

# =========================================================
# 🔥 LORAS (ONLY USED IN JSON)
# =========================================================
cd $MODELS_BASE/loras

# GEMMA LORA
curl -L -O https://huggingface.co/Comfy-Org/ltx-2/resolve/main/split_files/loras/gemma-3-12b-it-abliterated_lora_rank64_bf16.safetensors

# LTX IC LORA
curl -L -O https://huggingface.co/Lightricks/LTX-2.3-22b-IC-LoRA-Union-Control/resolve/main/ltx-2.3-22b-ic-lora-union-control-ref0.5.safetensors
# =========================================================
# 🔥 QWEN IMAGE EDIT (USED IN JSON)
# =========================================================
cd $MODELS_BASE/diffusion_models
curl -L -O https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_edit_2511_fp8mixed.safetensors

cd $MODELS_BASE/text_encoders
curl -L -O https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors

cd $MODELS_BASE/vae
curl -L -O https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors

cd $MODELS_BASE/loras
curl -L -O https://huggingface.co/lightx2v/Qwen-Image-Edit-2511-Lightning/resolve/main/Qwen-Image-Edit-2511-Lightning-8steps-V1.0-fp32.safetensors


echo "✅ ALL DONE — LTX 2.3 WORKFLOW READY"