#!/usr/bin/env bash
# install-sql.sh — Rol: base de datos (una de las 3 VMs SQL)
# Requiere haber corrido antes install-common.sh
# NOTA: estas VMs no deben tener IP externa. El acceso es solo desde la
# subred interna (Paper/plugins) y administración vía cloudflared/IAP.

set -euo pipefail

echo ">>> [sql] Instalando MariaDB..."
sudo apt-get install -y mariadb-server
echo "mariadb-server" | sudo tee -a /opt/.mc-installed-packages > /dev/null

echo ">>> [sql] Configurando bind-address a la IP interna (no 127.0.0.1, para aceptar la subred)..."
INTERNAL_IP=$(hostname -I | awk '{print $1}')
sudo sed -i "s/^bind-address.*/bind-address = ${INTERNAL_IP}/" /etc/mysql/mariadb.conf.d/50-server.cnf

sudo systemctl enable mariadb
sudo systemctl restart mariadb

echo ">>> [sql] Creando base de datos y usuario de aplicación..."
# Contraseña real se inyecta por variable de entorno en el momento del deploy,
# NUNCA hardcodeada en el repo.
: "${MC_DB_PASSWORD:?Debes exportar MC_DB_PASSWORD antes de correr este script}"

sudo mysql <<SQL
CREATE DATABASE IF NOT EXISTS minecraft;
CREATE USER IF NOT EXISTS 'mcapp'@'%' IDENTIFIED BY '${MC_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON minecraft.* TO 'mcapp'@'%';
FLUSH PRIVILEGES;
SQL

echo ">>> [sql] Restringiendo firewall a solo la subred interna del proyecto..."
sudo ufw allow from 10.0.0.0/8 to any port 3306
sudo ufw --force enable

echo ">>> [sql] Instalado."
