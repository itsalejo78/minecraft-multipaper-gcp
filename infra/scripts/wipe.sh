#!/usr/bin/env bash
# wipe.sh — Deja la VM en estado limpio antes de instalar el rol que le toque.
# Uso: sudo ./wipe.sh
# ADVERTENCIA: esto borra TODO lo que haya en /opt/mc, servicios systemd
# relacionados, y paquetes instalados por los scripts de este repo.
# No toca el sistema operativo base ni el usuario que ejecuta el script.

set -euo pipefail

echo ">>> [wipe] Deteniendo servicios conocidos (si existen)..."
for svc in paper velocity mariadb mysql cloudflared; do
  if systemctl list-unit-files | grep -q "^${svc}.service"; then
    sudo systemctl stop "${svc}" || true
    sudo systemctl disable "${svc}" || true
    sudo rm -f "/etc/systemd/system/${svc}.service"
  fi
done
sudo systemctl daemon-reload

echo ">>> [wipe] Borrando directorios de trabajo..."
sudo rm -rf /opt/mc
sudo rm -rf /opt/velocity
sudo rm -rf /opt/cloudflared
sudo rm -rf /var/lib/mysql-mc      # datos de SQL propios del proyecto, NO /var/lib/mysql del sistema

echo ">>> [wipe] Limpiando usuario de servicio si existe..."
if id "mcserver" &>/dev/null; then
  sudo pkill -u mcserver || true
fi

echo ">>> [wipe] Limpiando paquetes previos instalados por este proyecto (marcados manualmente)..."
# No usamos 'apt purge' agresivo sobre paquetes del sistema para no romper la VM.
# Solo removemos lo que instalamos nosotros y quedó marcado.
if [ -f /opt/.mc-installed-packages ]; then
  xargs -a /opt/.mc-installed-packages sudo apt-get -y purge || true
  sudo rm -f /opt/.mc-installed-packages
fi

sudo apt-get -y autoremove
echo ">>> [wipe] Listo. VM en estado limpio."
