#!/usr/bin/env bash
# tag-instances.sh — Etiqueta las 20 VMs existentes según su rol.
# Completar GCP_PROJECT antes de correr. Zona: us-east1-b.

set -euo pipefail

PROJECT="${GCP_PROJECT:?Exporta GCP_PROJECT con tu project id (gcloud config get-value project)}"
ZONE="us-east1-b"

NETWORK_VMS=(amd64 instance-20260905-151020 instance-20260905-151211 instance-20260905-151440 instance-20260905-151625)
PROCESSING_VMS=(instance-20260905-152216 instance-20260905-155149 instance-20260905-155522 instance-20260905-162107 instance-20260905-162236 instance-20260905-162453 instance-20260905-162557 instance-20260905-162733 instance-20260905-162851 instance-20260905-163111 instance-20260905-163316 instance-20260905-163406)
SQL_VMS=(instance-20260905-163504 instance-20260905-163553 instance-20260907-001520)

tag_group() {
  local tag="$1"; shift
  for vm in "$@"; do
    echo ">>> Etiquetando $vm como $tag"
    gcloud compute instances add-tags "$vm" --tags="$tag" --zone="$ZONE" --project="$PROJECT"
  done
}

tag_group "role-network" "${NETWORK_VMS[@]}"
tag_group "role-processing" "${PROCESSING_VMS[@]}"
tag_group "role-sql" "${SQL_VMS[@]}"

echo ">>> Quitando IP externa de las 2 VMs reasignadas a procesamiento (buena práctica de seguridad)..."
for vm in instance-20260905-152216 instance-20260905-155149; do
  gcloud compute instances delete-access-config "$vm" \
    --access-config-name="External NAT" --zone="$ZONE" --project="$PROJECT" || \
    echo "!! No se pudo quitar la IP de $vm automáticamente (revisar nombre del access-config manualmente con: gcloud compute instances describe $vm --zone=$ZONE)"
done

echo ">>> Etiquetado completo."
