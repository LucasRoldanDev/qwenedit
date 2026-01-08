
# 🚀 ComfyUI Ultimate Setup Script para RunPod

Este script de Bash automatiza completamente la instalación y configuración de **ComfyUI** en entornos Linux (específicamente optimizado para RunPod). Incluye soporte para **Python 3.12**, **SageAttention**, descarga de modelos autenticados de Hugging Face y gestión automática de nodos personalizados.

## ✨ Características Principales

*   **Entorno Moderno**: Instala Python 3.12 y PyTorch 2.7 (Nightly/Preview) con CUDA 12.8.
*   **Optimización**: Instala y activa **SageAttention** para una inferencia más rápida.
*   **Gestión de Nodos**: Descarga e instala automáticamente una lista curada de *Custom Nodes* populares (Manager, ControlNet, IPAdapter, etc.) y sus dependencias.
*   **Integración con Hugging Face**:
    *   Autenticación automática mediante *Secrets* de RunPod.
    *   Descarga de modelos privados/gated (ej. FLUX.1 Dev).
    *   Descarga de repositorios completos de LoRAs.
*   **Persistencia**: Configura `extra_model_paths.yaml` para usar almacenamiento externo si está disponible.

---

## 🛠️ Configuración en RunPod

Para sacar el máximo provecho al script, debes configurar las **Variables de Entorno** y los **Secretos** en la configuración de tu Pod (o en la plantilla).

### 1. Autenticación (Hugging Face Token)
Para descargar modelos privados (como FLUX.1 Dev) o repositorios restringidos, necesitas tu token.

1.  Ve a tu perfil de Hugging Face -> Settings -> Access Tokens.
2.  En RunPod, añade un **Secret** (o variable de entorno):
    *   **Key**: `RUNPOD_SECRET_hf_tk`
    *   **Value**: `hf_tu_token_aqui...`

> **Nota:** El script busca específicamente la variable `RUNPOD_SECRET_hf_tk`. Si no la encuentra, omitirá las descargas que requieran permisos, pero instalará ComfyUI normalmente.

### 2. Descarga de LoRAs Específicos (`LORAS_URL`)
Si deseas descargar archivos individuales (.safetensors) al iniciar:

*   **Key**: `LORAS_URL`
*   **Value**: Una lista de URLs directas separadas por comas.
    *   *Ejemplo:* `https://url.com/lora1.safetensors, https://url.com/lora2.safetensors`

### 3. Descarga de Repositorio Completo (`REPO_WORKFLOW_LORAS`)
Si tienes una colección de LoRAs en un repositorio de Hugging Face y quieres descargarlos todos automáticamente a la carpeta `models/loras`:

*   **Key**: `REPO_WORKFLOW_LORAS`
*   **Value**: El ID del repositorio (Usuario/NombreRepo).
    *   *Ejemplo:* `xlabs-ai/flux-ip-adapter`
    *   *Comportamiento:* Descargará solo los archivos `.safetensors` de ese repo.

---

## ⚙️ Personalización del Script (Edición Manual)

Hay ciertas configuraciones que están "hardcodeadas" en el script y que puedes modificar según tus necesidades antes de ejecutarlo:

### A. Modelos Checkpoints (Gated Models)
Busca la sección en el script llamada `GATED_MODELS_URLS`. Aquí debes poner las URLs de descarga directa de los modelos grandes (Checkpoints) que requieren token.

```bash
GATED_MODELS_URLS=(
    "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors"
    # Añade más modelos aquí
)
```

### B. Custom Nodes
El array `NODES_URLS` contiene los repositorios de Github de los nodos que se instalarán. Puedes añadir o quitar líneas según tu flujo de trabajo.

---

## 🚀 Instalación y Uso

1.  Copia el script en tu entorno de RunPod (por ejemplo, crea un archivo `install.sh`).
2.  Dale permisos de ejecución:
    ```bash
    chmod +x install.sh
    ```
3.  Ejecuta el script:
    ```bash
    ./install.sh
    ```

### ¿Qué ocurre durante la ejecución?
1.  **Actualización del Sistema**: Instala dependencias base de Linux.
2.  **Configuración de Python**: Configura Python 3.12 y crea un entorno virtual (`venv`).
3.  **Dependencias AI**: Instala PyTorch y compila/descarga SageAttention.
4.  **ComfyUI**: Clona o actualiza el repositorio oficial.
5.  **Nodos**: Clona los nodos personalizados e instala sus `requirements.txt`.
6.  **Descargas**:
    *   Descarga LoRAs sueltos definidos en `LORAS_URL`.
    *   Descarga el repositorio completo definido en `REPO_WORKFLOW_LORAS`.
    *   Descarga los modelos Checkpoint definidos en el script (si hay Token).
7.  **Arranque**: Inicia ComfyUI en el puerto `3001`.

---

## 📂 Estructura de Directorios

El script asume la siguiente estructura típica de RunPod:

*   `/workspace/ComfyUI`: Directorio principal de instalación.
*   `/workspace/ComfyUI/venv`: Entorno virtual.
*   `/workspace/ComfyUI/models/loras`: Destino de las descargas de LoRAs.
*   `/extra-storage/models/`: Ruta configurada en `extra_model_paths.yaml` (si usas volúmenes de red).

## ⚠️ Solución de Problemas

*   **Error 401/403 en descargas**: Verifica que tu token en `RUNPOD_SECRET_hf_tk` sea válido y tenga permisos de lectura ("Read") en Hugging Face. Asegúrate de haber aceptado los términos de uso del modelo en la web de Hugging Face (especialmente para FLUX o SD3).
*   **SageAttention falla**: El script descarga una *wheel* precompilada específica para Linux x86_64 y Python 3.12. Si cambias la versión de Python, esto fallará.
