#!/bin/bash
set -e

# ================================================================================
# TEST HF: solo verifica autenticación y descarga de repo
# ================================================================================

WORKSPACE="/workspace"
TEST_DIR="${WORKSPACE}/hf_test_download"

# Token desde RunPod Secret
export HF_TOKEN="$RUNPOD_SECRET_hf_tk"

echo "============================================================"
echo " HF CONFIG TEST"
echo "============================================================"

# ------------------------------------------------------------------------------
# 1. Verificación de token
# ------------------------------------------------------------------------------
if [ -n "$HF_TOKEN" ]; then
    echo "[OK] HF_TOKEN detectado"
else
    echo "[WARN] HF_TOKEN NO detectado"
    echo "       Solo funcionarán repos públicos"
fi

# ------------------------------------------------------------------------------
# 2. Verificación de variable REPO_WORKFLOW_LORAS
# ------------------------------------------------------------------------------
if [ -z "$REPO_WORKFLOW_LORAS" ]; then
    echo "[ERROR] REPO_WORKFLOW_LORAS no está definida"
    echo "Ejemplo:"
    echo "export REPO_WORKFLOW_LORAS=imthelighting/workflow-loras"
    exit 1
fi

echo "[OK] Repo a descargar: $REPO_WORKFLOW_LORAS"

# ------------------------------------------------------------------------------
# 3. Instalación / verificación de huggingface_hub (global)
# ------------------------------------------------------------------------------
echo "------------------------------------------------------------"
echo "Instalando / actualizando huggingface_hub..."
pip install -U huggingface_hub --break-system-packages || pip install -U huggingface_hub

echo "[OK] huggingface_hub instalado"
hf --version

# ------------------------------------------------------------------------------
# 4. Descarga de repositorio
# ------------------------------------------------------------------------------
echo "------------------------------------------------------------"
echo "Preparando directorio de descarga..."
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

echo "Descargando repo desde Hugging Face..."

hf download "$REPO_WORKFLOW_LORAS" \
    --local-dir "$TEST_DIR" \
    --include "*.safetensors" "*.pt" "*.ckpt" \
    || {
        echo "[ERROR] Falló la descarga del repositorio"
        exit 1
    }

# ------------------------------------------------------------------------------
# 5. Resultado
# ------------------------------------------------------------------------------
echo "------------------------------------------------------------"
echo "[SUCCESS] Test HF completado correctamente"
echo "Archivos descargados en:"
echo "  $TEST_DIR"
echo "============================================================"
