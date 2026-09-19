#!/usr/bin/env bash
# install-common.sh — Base compartida por los 3 roles (procesamiento, red, sql)
# Se ejecuta SIEMPRE antes del script específico del rol.

set -euo pipefail

echo ">>> [common] Actualizando índices de paquetes..."
sudo apt-get update -y

echo ">>> [common] Instalando dependencias base..."
PKGS="curl wget unzip git ufw"
sudo apt-get install -y $PKGS
echo "$PKGS" | tr ' ' '\n' | sudo tee -a /opt/.mc-installed-packages > /dev/null

echo ">>> [common] Creando usuario de servicio 'mcserver' (sin login)..."
if ! id "mcserver" &>/dev/null; then
  sudo useradd -r -m -s /usr/sbin/nologin mcserver
fi

sudo mkdir -p /opt/mc
sudo chown mcserver:mcserver /opt/mc

echo ">>> [common] Instalando cloudflared (para acceso administrativo sin IP externa)..."
if ! command -v cloudflared &>/dev/null; then
  curl -L --output /tmp/cloudflared.deb \
    https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
  sudo dpkg -i /tmp/cloudflared.deb
  echo "cloudflared" | sudo tee -a /opt/.mc-installed-packages > /dev/null
fi

echo ">>> [common] Base instalada. Continúa con el script del rol correspondiente."
