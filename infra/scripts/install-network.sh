#!/usr/bin/env bash
# install-network.sh — Rol: proxy Velocity (una de las 5 VMs de red)
# Requiere haber corrido antes install-common.sh
#
# Variable de entorno opcional:
#   IS_NAT_GATEWAY=true   -> además configura esta VM como NAT casera
#                             para las 15 VMs sin IP externa.

set -euo pipefail

VELOCITY_VERSION="${VELOCITY_VERSION:-3.4.0}"
VELOCITY_DIR="/opt/mc/velocity"

echo ">>> [network] Instalando Java 21..."
sudo apt-get install -y openjdk-21-jre-headless
echo "openjdk-21-jre-headless" | sudo tee -a /opt/.mc-installed-packages > /dev/null

echo ">>> [network] Descargando Velocity ${VELOCITY_VERSION}..."
sudo -u mcserver mkdir -p "${VELOCITY_DIR}"
cd "${VELOCITY_DIR}"
BUILD=$(curl -s "https://api.papermc.io/v2/projects/velocity/versions/${VELOCITY_VERSION}/builds" \
  | grep -o '"build":[0-9]*' | tail -1 | grep -o '[0-9]*')
sudo -u mcserver curl -o velocity.jar \
  "https://api.papermc.io/v2/projects/velocity/versions/${VELOCITY_VERSION}/builds/${BUILD}/downloads/velocity-${VELOCITY_VERSION}-${BUILD}.jar"

sudo tee /etc/systemd/system/velocity.service > /dev/null <<EOF
[Unit]
Description=Velocity Proxy
After=network.target

[Service]
User=mcserver
WorkingDirectory=${VELOCITY_DIR}
ExecStart=/usr/bin/java -Xms1G -Xmx2G -jar velocity.jar
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable velocity

if [ "${IS_NAT_GATEWAY:-false}" = "true" ]; then
  echo ">>> [network] Configurando esta VM como NAT casera para las VMs sin IP externa..."
  echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf
  sudo sysctl -p

  INTERNAL_IFACE=$(ip route | grep -m1 'default' | awk '{print $5}')
  sudo iptables -t nat -A POSTROUTING -o "${INTERNAL_IFACE}" -j MASQUERADE
  sudo iptables -A FORWARD -i "${INTERNAL_IFACE}" -o "${INTERNAL_IFACE}" -j ACCEPT
  sudo apt-get install -y iptables-persistent
  sudo netfilter-persistent save

  echo ">>> [network] IMPORTANTE (manual, fuera de la VM):"
  echo "    1) gcloud compute instances update <esta-vm> --no-can-ip-forward=false"
  echo "    2) Deshabilitar 'Source/Destination Check' en esta VM desde gcloud/consola."
  echo "    3) Crear ruta 0.0.0.0/0 -> IP interna de esta VM, aplicada a las 15 VMs privadas."
fi

echo ">>> [network] Instalado. La topología de servidores (config Velocity) se aplica en el deploy."
