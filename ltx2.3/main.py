import requests
import os
import time
from dotenv import load_dotenv
from pathlib import Path
import runpod
import os
import paramiko

stime=time.time()
# ======================
# LOAD .env SAFELY
# ======================
ENV_PATH =  ".env"
load_dotenv(ENV_PATH)

RUNPOD_API_KEY = os.getenv("RUNPOD_API_KEY")
SSH_PRIVATE_KEY_PATH = os.getenv("SSH_PRIVATE_KEY_PATH")
SSH_USER = os.getenv("SSH_USER", "root")

if not RUNPOD_API_KEY:
    raise RuntimeError("RUNPOD_API_KEY missing in .env")

print("✅ API key loaded")

runpod.api_key = RUNPOD_API_KEY
GPU_TYPES = {
    "a4000": "NVIDIA RTX A4000",
    "4090": "NVIDIA GeForce RTX 4090",
    "5090": "NVIDIA GeForce RTX 5090",
}

GPU_CHOICE = "5090"
POD_NAME = "ltx2-auto-comfyui"
IMAGE = "runpod/comfyui:latest"
CONTAINER_DISK = 400
VOLUME_DISK = 0


pod = runpod.create_pod(
    name="ltx2_3-auto-comfyui",
    image_name="runpod/comfyui:latest",

    gpu_type_id=GPU_TYPES[GPU_CHOICE],
    gpu_count=1,

    cloud_type="SECURE",

    # 💾 Storage
    container_disk_in_gb=CONTAINER_DISK,
    volume_in_gb=VOLUME_DISK,

    # 🌐 Network
    support_public_ip=True,
    start_ssh=True,
    ports="8188/http,8080/http,8888/http,22/tcp",

    # 🧠 Resources
    min_vcpu_count=12,
    min_memory_in_gb=32,
)
pod_id = pod["id"]
print("🚀 Pod created with ID:", pod_id)

def wait_for_runtime(pod_id, timeout=300):
    start = time.time()
    while time.time() - start < timeout:
        pod_info = runpod.get_pod(pod_id)

        runtime = pod_info.get("runtime")
        if runtime and runtime.get("ports"):
            return runtime["ports"]

        print("⏳ Waiting for pod runtime...")
        time.sleep(5)

    raise TimeoutError("Runtime not ready")


ports = wait_for_runtime(pod_id)

jupyter_url = None
ssh_url = None

for p in ports:
    if p["privatePort"] == 22:
        hostname = p['ip']
        port = p['publicPort']
        ssh_url = f"ssh {SSH_USER}@{hostname} -p {port}"

print("🔐 SSH CMD:", ssh_url)

import paramiko

class IgnoreHostKeyPolicy(paramiko.MissingHostKeyPolicy):
    def missing_host_key(self, client, hostname, key):
        return  # do nothing, no save, no prompt

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(IgnoreHostKeyPolicy())

ssh.connect(
    hostname=hostname,
    port=port,
    username="root",
    key_filename="/Users/amitsharma/.ssh/id_ed25519",
    allow_agent=False,
    look_for_keys=False,
    timeout=15
)

stdin, stdout, stderr = ssh.exec_command("nvidia-smi")
print(stdout.read().decode())



# cmd = """
# set -e
# cd /root
# curl -fsSL https://raw.githubusercontent.com/rjamitsharma01/ai_models_setup/main/ltx2-comfyui/RTX4090/ltx-2-models-downloader-comfyui.sh | bash
# """

# stdin, stdout, stderr = ssh.exec_command(cmd, get_pty=True)

# for line in iter(stdout.readline, ""):
#     print(line, end="")

# for line in iter(stderr.readline, ""):
#     print(line, end="")

# ssh.close()

print("⏱️ Total time taken:", time.time() - stime, "seconds")
print("⏱️ Total time taken in minutes:", (time.time() - stime) / 60, "minutes")
base_url = f"https://{pod['id']}-8188.proxy.runpod.net"
print(f"🌐 Access ComfyUI at: {base_url}")
restart_endpoint = f"{base_url}/api/manager/reboot"
requests.get(restart_endpoint)
print("🔄 Sent reboot command to ComfyUI. It may take a minute to restart.")