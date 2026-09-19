#!/usr/bin/env bash
# install-processing.sh — Rol: servidor Paper (una de las 12 VMs de procesamiento)
# Requiere haber corrido antes install-common.sh

set -euo pipefail

PAPER_VERSION="${PAPER_VERSION:-1.21.4}"   # ajustar según la versión objetivo
PAPER_DIR="/opt/mc/paper"

echo ">>> [processing] Instalando Java 21 (requerido por Paper moderno)..."
sudo apt-get install -y openjdk-21-jre-headless
echo "openjdk-21-jre-headless" | sudo tee -a /opt/.mc-installed-packages > /dev/null

echo ">>> [processing] Creando estructura de servidor Paper..."
sudo -u mcserver mkdir -p "${PAPER_DIR}"
cd "${PAPER_DIR}"

echo ">>> [processing] Descargando última build estable de Paper ${PAPER_VERSION}..."
BUILD=$(curl -s "https://api.papermc.io/v2/projects/paper/versions/${PAPER_VERSION}/builds" \
  | grep -o '"build":[0-9]*' | tail -1 | grep -o '[0-9]*')
sudo -u mcserver curl -o paper.jar \
  "https://api.papermc.io/v2/projects/paper/versions/${PAPER_VERSION}/builds/${BUILD}/downloads/paper-${PAPER_VERSION}-${BUILD}.jar"

echo "eula=true" | sudo -u mcserver tee eula.txt > /dev/null

# El server.properties real (puertos, IP de bind, base de datos) se sobreescribe
# desde el propio repo en el paso de deploy, no aquí (esto es solo el binario base).

echo ">>> [processing] Creando carpeta de plugins..."
sudo -u mcserver mkdir -p "${PAPER_DIR}/plugins"

echo ">>> [processing] Registrando servicio systemd..."
sudo tee /etc/systemd/system/paper.service > /dev/null <<EOF
[Unit]
Description=Paper Minecraft Server
After=network.target

[Service]
User=mcserver
WorkingDirectory=${PAPER_DIR}
ExecStart=/usr/bin/java -Xms2G -Xmx4G -jar paper.jar nogui
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable paper
echo ">>> [processing] Instalado. El plugin custom se despliega aparte vía CI/CD."
