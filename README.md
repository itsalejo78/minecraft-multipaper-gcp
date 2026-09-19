# minecraft-multipaper-gcp

Infraestructura y plugin para un clúster multi-servidor de Minecraft
(Paper + Velocity) desplegado en Google Cloud, con handoff de entidades
entre servidores de procesamiento.

## Estructura

```
infra/     -> scripts de aprovisionamiento de las 20 VMs (GCP)
plugin/    -> código del plugin Java para Paper (próximamente)
```

Ver `infra/README.md` para el flujo de despliegue.
