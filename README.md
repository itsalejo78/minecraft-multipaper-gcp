# minecraft-multipaper-gcp

Infraestructura y plugin para un clúster multi-servidor de Minecraft
(Paper + Velocity) desplegado en Google Cloud, con handoff de entidades
entre servidores de procesamiento.

## Arquitectura

18 VMs en `us-east1-b`:

- **5 de red** — proxies Velocity, únicas con IP externa; reciben a los jugadores.
- **10 de procesamiento** — servidores Paper, solo en la red interna.
- **3 de base de datos** — MariaDB, solo en la red interna.

La administración se hace por SSH sobre IAP (no hace falta IP externa) y
`cloudflared`.

## Estructura

```
infra/     -> scripts de aprovisionamiento de las VMs (GCP)
plugin/    -> código del plugin Java para Paper (próximamente)
```

## Estado

La infraestructura todavía no se puede desplegar de punta a punta: hay
fallos conocidos en los scripts. Ver la sección *Problemas conocidos* de
[`infra/README.md`](infra/README.md#problemas-conocidos).

Para el flujo de despliegue, ver [`infra/README.md`](infra/README.md).
