# Infraestructura — Minecraft Multipaper en GCP

Scripts para aprovisionar las 18 VMs del clúster en Google Cloud
(zona `us-east1-b`, red `default`, subred `10.142.0.0/20`).

## Topología

| Rol | Software | Tag | Cantidad | IP externa |
|---|---|---|---|---|
| Red | Velocity (proxy) | `role-network` | 5 | Sí |
| Procesamiento | Paper | `role-processing` | 10 | No |
| Base de datos | MariaDB | `role-sql` | 3 | No |

El mapeo exacto de nombres de VM a rol está en
[`scripts/tag-instances.sh`](scripts/tag-instances.sh).

## Scripts

| Script | Dónde corre | Qué hace |
|---|---|---|
| `deploy.sh` | Tu máquina | Orquestador: por cada VM de un rol, corre `wipe` + `install-common` + `install-<rol>` vía SSH sobre IAP |
| `scripts/tag-instances.sh` | Tu máquina | Pone el tag de rol a cada una de las 18 VMs |
| `scripts/internal-firewall.sh` | Tu máquina | Crea la regla de firewall para tráfico interno (25565, 3306, 8080, ICMP) |
| `scripts/wipe.sh` | VM | Detiene servicios, borra `/opt/mc` y desinstala los paquetes del proyecto |
| `scripts/install-common.sh` | VM | Paquetes base, usuario `mcserver`, `cloudflared` |
| `scripts/install-processing.sh` | VM | Java 21 + Paper + servicio `paper` |
| `scripts/install-network.sh` | VM | Java 21 + Velocity + servicio `velocity` (opcionalmente NAT casera) |
| `scripts/install-sql.sh` | VM | MariaDB, base `minecraft`, usuario `mcapp`, firewall `ufw` |

Los scripts de VM no se copian a la VM: `deploy.sh` envía su contenido
como comando por `gcloud compute ssh`.

## Requisitos

- `gcloud` CLI autenticado (`gcloud auth login`).
- Bash (Linux, macOS, WSL o Git Bash en Windows).
- Las variables de entorno:

```bash
export GCP_PROJECT=tu-proyecto-id
export GCP_ZONE=us-east1-b          # obligatorio: deploy.sh usa us-central1-a si no se define
export MC_DB_PASSWORD='...'         # solo para los roles sql / all; no la commitees
```

## Puesta en marcha (una sola vez)

Los pasos van en este orden. Los comandos se corren desde la raíz del repo.

### 1. Etiquetar las VMs

```bash
./infra/scripts/tag-instances.sh
```

### 2. Firewall: SSH desde IAP

Permite que `gcloud compute ssh --tunnel-through-iap` llegue a todas las
VMs, tengan o no IP externa.

```bash
gcloud compute firewall-rules create allow-iap-ssh \
  --project="$GCP_PROJECT" \
  --direction=INGRESS \
  --action=ALLOW \
  --rules=tcp:22 \
  --source-ranges=35.235.240.0/20
```

### 3. Firewall: tráfico interno del clúster

```bash
./infra/scripts/internal-firewall.sh
```

### 4. Salida a internet para las VMs sin IP externa

**Este paso tiene que ir antes del deploy.** IAP solo cubre el SSH de
entrada; los scripts de instalación necesitan descargar paquetes (`apt`),
Paper/Velocity y `cloudflared`. Sin salida a internet, el deploy de los
roles `processing` y `sql` falla.

Opción recomendada, Cloud NAT (gestionado por Google):

```bash
gcloud compute routers create mc-router \
  --project="$GCP_PROJECT" --network=default --region=us-east1

gcloud compute routers nats create mc-nat \
  --project="$GCP_PROJECT" --router=mc-router --region=us-east1 \
  --auto-allocate-nat-external-ips --nat-all-subnet-ip-ranges
```

La alternativa de NAT casera (`IS_NAT_GATEWAY=true` en
`install-network.sh`) existe pero hoy tiene errores; ver
[Problemas conocidos](#problemas-conocidos).

### 5. Firewall: entrada de jugadores a Velocity

Abre el puerto del proxy solo en las VMs de red. 25577 es el puerto por
defecto de Velocity; cámbialo si `velocity.toml` usa otro.

```bash
gcloud compute firewall-rules create allow-velocity-public \
  --project="$GCP_PROJECT" \
  --direction=INGRESS \
  --action=ALLOW \
  --rules=tcp:25577 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=role-network
```

## Deploy

```bash
cd infra
./deploy.sh all            # las 18 VMs
./deploy.sh processing     # solo las 10 de procesamiento
./deploy.sh network        # solo las 5 de red
./deploy.sh sql            # solo las 3 de base de datos
```

> ⚠️ **El deploy es destructivo.** Cada ejecución corre `wipe.sh` antes de
> instalar, lo que borra `/opt/mc` y desinstala los paquetes del proyecto,
> incluido `mariadb-server` en las VMs SQL. No lo corras sobre el rol `sql`
> cuando haya datos que conservar.

Las VMs se procesan una por una, así que `all` tarda.

## Pendiente de configurar manualmente

1. **Configuración de Velocity y Paper.** Los scripts instalan los binarios
   pero no la configuración: lista de servidores y `forwarding-secret` en
   `velocity.toml`, y en cada Paper `online-mode=false` y el bloque
   `proxies.velocity` de `config/paper-global.yml`. Sin esto Velocity no
   puede enviar jugadores a Paper.
2. **`cloudflared`.** Se instala en todas las VMs, pero el túnel se
   configura a mano con tu cuenta de Cloudflare Zero Trust
   (`cloudflared tunnel login` y crear el túnel).
3. **Contraseña de la base de datos.** Se pasa por `MC_DB_PASSWORD` y nunca
   se commitea. Evita la comilla simple `'`: rompe el comando y el SQL.

## Problemas conocidos

Estos fallos están en los scripts actuales y hay que corregirlos antes del
primer deploy real.

- **API de PaperMC retirada.** `install-processing.sh` e
  `install-network.sh` descargan de `api.papermc.io/v2`, que ya responde
  `410 sunset`. Hay que migrar a `fill.papermc.io/v3`.
- **SSH bloqueado en las VMs SQL.** `install-sql.sh` activa `ufw` permitiendo
  solo el 3306, lo que corta el SSH desde IAP. Falta permitir
  `35.235.240.0/20` al puerto 22 antes de `ufw enable`.
- **Zona por defecto incorrecta en `deploy.sh`** (`us-central1-a`). Mientras
  no se corrija, exporta siempre `GCP_ZONE=us-east1-b`.
- **NAT casera** (`IS_NAT_GATEWAY=true`): los comandos `gcloud` que imprime
  al final no son válidos (`--no-can-ip-forward=false`; "Source/Destination
  Check" es de AWS, en GCP es `can-ip-forward`), e `iptables-persistent` se
  queda esperando una respuesta interactiva. Usa Cloud NAT.
- **Contraseña visible.** `deploy.sh` pasa `MC_DB_PASSWORD` dentro del
  comando SSH, así que aparece en la lista de procesos.
- **`wipe.sh` y los datos SQL.** El comentario dice que protege los datos,
  pero borra `/var/lib/mysql-mc`, que no existe; los datos reales están en
  `/var/lib/mysql`.
