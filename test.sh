#!/bin/bash
set -e

# ================================================================================
# TEST HF: Verificación visual de Token y Descarga
# ================================================================================

WORKSPACE="/workspace"
TEST_DIR="${WORKSPACE}/hf_test_download"

# 1. Capturar Token
export HF_TOKEN="$RUNPOD_SECRET_hf_tk"

echo "============================================================"
echo " HF CONFIG TEST"
echo "============================================================"

# ------------------------------------------------------------------------------
# 1. Diagnóstico de Token (CON VISUALIZACIÓN PARCIAL)
# ------------------------------------------------------------------------------
if [ -n "$HF_TOKEN" ]; then
    echo "[OK] HF_TOKEN detectado."
    
    # Lógica para mostrar los últimos 4 caracteres
    # ${VAR: -4} extrae los últimos 4.
    LAST_FOUR="${HF_TOKEN: -4}"
    
    echo "     Longitud: ${#HF_TOKEN} caracteres."
    echo "     Token Check: ...$LAST_FOUR"  # <--- AQUÍ MOSTRAMOS EL FINAL DEL TOKEN
    
    if [[ "$HF_TOKEN" != hf_* ]]; then
        echo "[WARN] CUIDADO: El token no empieza por 'hf_'. Verifica que sea correcto."
    else
        echo "     Formato: Correcto (Empieza por 'hf_')"
    fi
else
    echo "[WARN] HF_TOKEN NO detectado o está vacío."
    echo "       La descarga fallará si el repositorio es privado."
fi

# ------------------------------------------------------------------------------
# 2. Verificación de variable REPO
# ------------------------------------------------------------------------------
if [ -z "$REPO_WORKFLOW_LORAS" ]; then
    echo "[ERROR] REPO_WORKFLOW_LORAS no está definida."
    exit 1
fi

echo "[OK] Repo a descargar: $REPO_WORKFLOW_LORAS"

# ------------------------------------------------------------------------------
# 3. Instalación de huggingface_hub
# ------------------------------------------------------------------------------
echo "------------------------------------------------------------"
echo "Instalando huggingface_hub..."
pip install -U "huggingface_hub[cli]" --break-system-packages || pip install -U huggingface_hub
echo "[OK] huggingface_hub instalado"

# ------------------------------------------------------------------------------
# 4. Descarga de repositorio
# ------------------------------------------------------------------------------
echo "------------------------------------------------------------"
echo "Preparando directorio de descarga..."
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

echo "Iniciando descarga..."

if [ -n "$HF_TOKEN" ]; then
    echo "--> Usando autenticación explícita (--token)..."
    hf download "$REPO_WORKFLOW_LORAS" \
        --local-dir "$TEST_DIR" \
        --token "$HF_TOKEN" \
        --include "*.safetensors" "*.pt" "*.ckpt" \
        || {
            echo "------------------------------------------------------------"
            echo "[ERROR] Falló la descarga AUTENTICADA."
            echo "1. Revisa que los caracteres '...$LAST_FOUR' coincidan con tu token real."
            echo "2. Revisa permisos del repo."
            exit 1
        }
else
    echo "--> Intentando descarga PÚBLICA (Sin token)..."
    hf download "$REPO_WORKFLOW_LORAS" \
        --local-dir "$TEST_DIR" \
        --include "*.safetensors" "*.pt" "*.ckpt" \
        || {
            echo "[ERROR] Falló la descarga PÚBLICA."
            exit 1
        }
fi

# ------------------------------------------------------------------------------
# 5. Resultado
# ------------------------------------------------------------------------------
echo "------------------------------------------------------------"
echo "[SUCCESS] Test HF completado correctamente."
echo "Archivos descargados en: $TEST_DIR"
ls -lh "$TEST_DIR"
echo "============================================================"
