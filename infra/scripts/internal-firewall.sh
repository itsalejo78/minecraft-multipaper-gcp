#!/usr/bin/env bash
# internal-firewall.sh — Permite que las 18 VMs se hablen entre sí por
# los puertos que necesita el clúster: 25565 (Minecraft/Paper),
# 3306 (MySQL/MariaDB), y 8080 (canal propio entre servidores, para el
# futuro sistema de handoff de entidades).
#
# Solo abre tráfico DENTRO de la subred interna del proyecto (10.142.0.0/20,
# la que vimos en la lista de instancias) — nada de esto expone puertos
# a internet.

set -euo pipefail

PROJECT="${GCP_PROJECT:?Exporta GCP_PROJECT}"
SUBNET_RANGE="10.142.0.0/20"

gcloud compute firewall-rules create allow-mc-internal \
  --project="$PROJECT" \
  --direction=INGRESS \
  --action=ALLOW \
  --rules=tcp:25565,tcp:3306,tcp:8080,icmp \
  --source-ranges="$SUBNET_RANGE" \
  --description="Comunicación interna entre VMs del clúster Minecraft (Paper, Velocity, SQL, ping de diagnóstico)"

echo ">>> Regla creada. Probá conectividad entre dos VMs con:"
echo "    ping -c 3 <IP_INTERNA_DESTINO>"
