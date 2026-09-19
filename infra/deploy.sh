#!/usr/bin/env bash
# deploy.sh — Orquesta wipe + install en las 20 VMs vía SSH sobre IAP.
# No requiere IP externa ni NAT funcionando: IAP tunneling de GCP alcanza
# a cualquier VM en la VPC del proyecto.
#
# Requisitos previos:
#   - gcloud CLI autenticado (gcloud auth login) y proyecto seteado
#     (gcloud config set project TU_PROYECTO)
#   - Firewall rule que permita SSH (tcp:22) desde el rango de IAP
#     (35.235.240.0/20) hacia todas las VMs. Ver README de este repo.
#   - Las VMs deben estar etiquetadas (--tags) así:
#       procesamiento -> tag "role-processing"  (12 VMs)
#       red           -> tag "role-network"     (5 VMs)
#       sql           -> tag "role-sql"          (3 VMs)
#
# Uso:
#   ./deploy.sh <role>       # role = processing | network | sql | all
#   ./deploy.sh all

set -euo pipefail

PROJECT="${GCP_PROJECT:?Exporta GCP_PROJECT con el id de tu proyecto}"
ZONE="${GCP_ZONE:-us-central1-a}"
ROLE="${1:-all}"

run_on_vm() {
  local vm="$1"
  local scripts=("${@:2}")
  echo "=== [$vm] ==="
  for s in "${scripts[@]}"; do
    echo "--- ejecutando $(basename "$s") en $vm ---"
    gcloud compute ssh "$vm" \
      --project="$PROJECT" --zone="$ZONE" --tunnel-through-iap \
      --command="$(cat "$s")"
  done
}

deploy_role() {
  local tag="$1"; shift
  local scripts=("$@")
  local vms
  vms=$(gcloud compute instances list --project="$PROJECT" \
    --filter="tags.items=${tag}" --format="value(name)")

  if [ -z "$vms" ]; then
    echo "!! No se encontraron VMs con tag ${tag}. Revisa el etiquetado."
    return
  fi

  for vm in $vms; do
    run_on_vm "$vm" "${scripts[@]}"
  done
}

case "$ROLE" in
  processing)
    deploy_role "role-processing" scripts/wipe.sh scripts/install-common.sh scripts/install-processing.sh
    ;;
  network)
    deploy_role "role-network" scripts/wipe.sh scripts/install-common.sh scripts/install-network.sh
    ;;
  sql)
    deploy_role "role-sql" scripts/wipe.sh scripts/install-common.sh scripts/install-sql.sh
    ;;
  all)
    deploy_role "role-processing" scripts/wipe.sh scripts/install-common.sh scripts/install-processing.sh
    deploy_role "role-network" scripts/wipe.sh scripts/install-common.sh scripts/install-network.sh
    deploy_role "role-sql" scripts/wipe.sh scripts/install-common.sh scripts/install-sql.sh
    ;;
  *)
    echo "Uso: $0 <processing|network|sql|all>"
    exit 1
    ;;
esac

echo ">>> Deploy completo para rol: ${ROLE}"
