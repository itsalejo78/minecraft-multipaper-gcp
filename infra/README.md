# Infraestructura — Minecraft Multipaper en GCP

## Requisito previo: firewall para IAP

Antes de correr `deploy.sh` por primera vez, crea esta regla una sola vez:

```bash
gcloud compute firewall-rules create allow-iap-ssh \
  --project=TU_PROYECTO \
  --direction=INGRESS \
  --action=ALLOW \
  --rules=tcp:22 \
  --source-ranges=35.235.240.0/20
```

Esto permite que `gcloud compute ssh --tunnel-through-iap` llegue a
cualquiera de las 20 VMs, tengan o no IP externa.

## Etiquetado de VMs

Cada VM debe llevar uno de estos tags (se pone al crearla o después con
`gcloud compute instances add-tags`):

| Rol | Tag | Cantidad | IP externa |
|---|---|---|---|
| Procesamiento (Paper) | `role-processing` | 12 | No |
| Red (Velocity) | `role-network` | 5 | Sí |
| Base de datos (SQL) | `role-sql` | 3 | No |

## Uso

```bash
export GCP_PROJECT=tu-proyecto-id
export GCP_ZONE=us-central1-a
cd infra
./deploy.sh all            # borra e instala las 20 VMs
./deploy.sh processing     # solo las 12 de procesamiento
```

## Pendiente de configurar manualmente (fuera de estos scripts)

1. Designar UNA VM de red como NAT casera: correr su `install-network.sh`
   con `IS_NAT_GATEWAY=true`, y luego aplicar los 3 pasos de `gcloud` que
   el script imprime al final (disable source/dest check + ruta 0.0.0.0/0).
2. Configurar `cloudflared` con tu cuenta de Cloudflare Zero Trust
   (`cloudflared tunnel login` + crear el túnel) — esto es interactivo,
   no se puede automatizar 100% en este script sin tus credenciales.
3. Contraseñas de la base de datos: se pasan por variable de entorno
   `MC_DB_PASSWORD`, nunca se commitean al repo.
