#!/usr/bin/env bash
# =============================================================================
#  Lokales LLM-Setup für CachyOS + AMD RX 7800 XT (RDNA3)
#  Optimiert für Programmierung: Planung, Code, Tests, CI/CD
#  Stand: Oktober 2026
# =============================================================================
set -euo pipefail

# ── Konfiguration ─────────────────────────────────────────────────────────────
LLAMA_DIR="$HOME/llama.cpp"
MODEL_DIR="$HOME/models"
MODEL_FILE="gemma-4-12b-it-Q4_K_M.gguf"
MTP_FILE="mtp-gemma-4-12b-it-Q8_0.gguf"
MODEL_REPO="unsloth/gemma-4-12b-it-GGUF"
MTP_REPO="unsloth/gemma-4-12b-it-GGUF"
PORT=8080
CTX_SIZE=32768          # 32k Kontext – sicher auf 16 GB VRAM
NGL=999                 # Alle Layer auf GPU
THREADS=6               # 6 CPU-Threads (Ryzen 7 5800X: 8 Kerne / 16 Threads)
SPEC_DRAFT_N_MAX=4      # MTP Sweet Spot für Gemma 4 (laut Unsloth-Doku)

# ── Farben ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── 1. Abhängigkeiten installieren ───────────────────────────────────────────
info "Installiere Systemabhängigkeiten..."
sudo pacman -Syu --noconfirm
sudo pacman -S --noconfirm --needed \
    base-devel cmake git \
    vulkan-headers vulkan-icd-loader vulkan-tools vulkan-radeon \
    spirv-headers spirv-tools \
    python-huggingface-hub

# Vulkan-Treiber prüfen
info "Prüfe Vulkan-Installation..."
if ! vulkaninfo --summary 2>/dev/null | grep -qi "RADV"; then
    warn "RADV-Treiber nicht gefunden. Stelle sicher, dass 'vulkan-radeon' installiert ist."
fi

# ── 2. llama.cpp mit Vulkan-Backend kompilieren ──────────────────────────────
info "Kompiliere llama.cpp mit Vulkan-Backend..."
if [ -d "$LLAMA_DIR" ]; then
    info "llama.cpp bereits vorhanden – aktualisiere..."
    cd "$LLAMA_DIR"
    git pull --ff-only
else
    git clone https://github.com/ggml-org/llama.cpp.git "$LLAMA_DIR"
    cd "$LLAMA_DIR"
fi

# Wichtig: MTP-Unterstützung ist ab Juni 2026 in llama.cpp gemerged[reference:3]
# Wir bauen mit Vulkan, da dies auf RDNA3 die beste Performance liefert[reference:4]
cmake -B build-vulkan \
    -DGGML_VULKAN=ON \
    -DGGML_HIP=OFF \
    -DCMAKE_BUILD_TYPE=Release
cmake --build build-vulkan --config Release -j"$(nproc)"

LLAMA_SERVER="$LLAMA_DIR/build-vulkan/bin/llama-server"
[ -x "$LLAMA_SERVER" ] || error "llama-server wurde nicht gefunden: $LLAMA_SERVER"

# ── 3. Modell herunterladen ──────────────────────────────────────────────────
info "Lade Modell herunter..."
mkdir -p "$MODEL_DIR"
cd "$MODEL_DIR"

# Gemma 4 12B Q4_K_M – ~7.4 GB, Sweet Spot für 16 GB VRAM[reference:5]
if [ ! -f "$MODEL_FILE" ]; then
    info "Download: $MODEL_FILE (~7.4 GB)..."
    hf download "$MODEL_REPO" "$MODEL_FILE" --local-dir .
else
    info "$MODEL_FILE bereits vorhanden – überspringe Download."
fi

# MTP-Drafter für Gemma 4 – ~5 GB, Q8_0, kleinste empfohlene Präzision[reference:6]
if [ ! -f "$MTP_FILE" ]; then
    info "Download: $MTP_FILE (~5 GB)..."
    hf download "$MTP_REPO" "MTP/$MTP_FILE" --local-dir .
    # Datei aus Unterordner verschieben
    mv "MTP/$MTP_FILE" . 2>/dev/null || true
    rmdir MTP 2>/dev/null || true
else
    info "$MTP_FILE bereits vorhanden – überspringe Download."
fi

# ── 4. Startskript erstellen ─────────────────────────────────────────────────
info "Erstelle Startskript..."
START_SCRIPT="$HOME/start-llm-server.sh"

cat > "$START_SCRIPT" << 'EOF'
#!/usr/bin/env bash
# llama.cpp Server – optimiert für AMD RX 7800 XT (RDNA3) + Programmierung
#
# Referenz: 80-90 tok/s auf RX 7800 XT mit Vulkan, 102k Kontext[reference:7]
# Parameter basieren auf dem bewährten Setup aus llama.cpp Discussion #26785[reference:8]
#
# Wichtige Erkenntnisse für diese GPU:
#   --spec-type draft-mtp    : Multi-Token Prediction aktivieren (3x Speedup)
#   --spec-draft-n-max 4    : Sweet Spot für Gemma 4 (laut Unsloth)
#   --cache-type-k/v f16    : ~10 tok/s schneller als q8_0 auf AMD[reference:9]
#   --parallel 1            : Voller Kontext, keine Performance-Einbrüche[reference:10]
#   -ngl all                : Alle Layer auf GPU
#   --flash-attn on         : Flash Attention aktivieren

set -euo pipefail

LLAMA_DIR="$HOME/llama.cpp"
MODEL_DIR="$HOME/models"
MODEL_FILE="gemma-4-12b-it-Q4_K_M.gguf"
MTP_FILE="mtp-gemma-4-12b-it-Q8_0.gguf"

exec "$LLAMA_DIR/build-vulkan/bin/llama-server" \
    --model "$MODEL_DIR/$MODEL_FILE" \
    --model-draft "$MODEL_DIR/$MTP_FILE" \
    --spec-type draft-mtp \
    --spec-draft-n-max 4 \
    --ctx-size 32768 \
    --parallel 1 \
    --cache-type-k f16 \
    --cache-type-v f16 \
    --batch-size 2048 \
    --ubatch-size 2048 \
    -ngl 999 \
    -t 6 \
    --flash-attn on \
    --host 127.0.0.1 \
    --port 8080 \
    --perf
EOF

chmod +x "$START_SCRIPT"

# ── 5. Systemd-Service erstellen (optional, für Autostart) ──────────────────
info "Erstelle systemd-Service (optional)..."
SERVICE_FILE="$HOME/.config/systemd/user/llama-server.service"
mkdir -p "$(dirname "$SERVICE_FILE")"

cat > "$SERVICE_FILE" << EOF
[Unit]
Description=llama.cpp Server (Gemma 4 12B MTP, Vulkan, RX 7800 XT)
After=network.target

[Service]
Type=simple
ExecStart=$START_SCRIPT
Restart=on-failure
RestartSec=10
Environment=GGML_VK_VISIBLE_DEVICES=0

[Install]
WantedBy=default.target
EOF

info "Systemd-Service: $SERVICE_FILE"
info "Aktivieren mit: systemctl --user enable --now llama-server"

# ── 6. Fertig ────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Setup abgeschlossen!${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "  Server starten:     $START_SCRIPT"
echo "  Autostart:          systemctl --user enable --now llama-server"
echo "  Server-Log:         journalctl --user -u llama-server -f"
echo ""
echo "  OpenAI-API-Endpunkt: http://127.0.0.1:8080/v1"
echo "  Test:                curl http://127.0.0.1:8080/v1/models"
echo ""
echo -e "${YELLOW}  OmniRoute-Konfiguration (siehe unten):${NC}"
echo "  1. In OmniRoute: Provider vom Typ 'OpenAI-kompatibel' hinzufügen"
echo "  2. Basis-URL: http://127.0.0.1:8080/v1"
echo "  3. API-Key: (leer lassen)"
echo "  4. In ~/.omniroute/.env: OMNIROUTE_ALLOW_PRIVATE_PROVIDER_URLS=true"
echo ""
