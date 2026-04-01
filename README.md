# Ceph Storage Cluster — Docker Compose

## Arquitectura

```
Clientes (S3 / CephFS / RBD)
         │
    [HAProxy :80/:443]
      ┌───┴───┐
   [rgw1]   [rgw2]        ← RADOS Gateway (S3/Swift API)
         │
   ┌─────┼─────┐
[mon1] [mon2] [mon3]      ← Monitor Cluster (Quorum)
         │
   [mgr1] [mgr2]          ← Manager (Dashboard :8443)
         │
  [mds1] [mds2]           ← Metadata Server (CephFS)
         │
[osd0][osd1][osd2][osd3]  ← Object Storage Daemons
         │
[Prometheus][Grafana]     ← Observabilidad
```

## Requisitos

- Docker ≥ 24.x
- Docker Compose v2
- RAM: mínimo 8 GB (16 GB recomendado)
- CPU: 4 vCPUs mínimo
- Disco: depende de los volúmenes OSD

## Despliegue

### 1. Preparar configuración

```bash
# Clonar / copiar los archivos
mkdir ceph-stack && cd ceph-stack

# Copiar variables de entorno
cp .env.example .env
# Editar .env y ajustar CEPH_FSID (usa: uuidgen)
nano .env

# Crear directorio de configuración compartido
mkdir -p ceph-config haproxy/certs grafana/provisioning grafana/dashboards
```

### 2. Bootstrap inicial (solo la primera vez)

```bash
# Inicializar el cluster y generar keyrings
docker compose up ceph-bootstrap -d

# Esperar a que el bootstrap termine
docker compose logs -f ceph-bootstrap
# Busca el mensaje: "Bootstrap completado"

# Detener el bootstrap (no se necesita más)
docker compose stop ceph-bootstrap
```

### 3. Levantar el cluster completo

```bash
# Levantar en orden (depends_on se encarga del orden)
docker compose up -d mon1 mon2 mon3
sleep 30
docker compose up -d mgr1 mgr2
sleep 20
docker compose up -d osd0 osd1 osd2 osd3
sleep 30
docker compose up -d mds1 mds2
docker compose up -d rgw1 rgw2
docker compose up -d haproxy
docker compose up -d prometheus grafana ceph-exporter
```

O de una vez (Docker respeta depends_on):
```bash
docker compose up -d
```

### 4. Crear filesystem CephFS

```bash
docker exec ceph-mon1 ceph osd pool create cephfs_data 64
docker exec ceph-mon1 ceph osd pool create cephfs_metadata 16
docker exec ceph-mon1 ceph fs new cephfs cephfs_metadata cephfs_data
```

### 5. Crear bucket S3 de prueba

```bash
# Crear usuario RGW
docker exec ceph-mon1 radosgw-admin user create \
  --uid=testuser \
  --display-name="Test User" \
  --email=test@example.com

# El comando devuelve access_key y secret_key — guardarlos

# Probar con AWS CLI
aws s3 mb s3://mi-bucket \
  --endpoint-url http://localhost \
  --no-verify-ssl

aws s3 cp archivo.txt s3://mi-bucket/ \
  --endpoint-url http://localhost
```

### 6. Verificar estado del cluster

```bash
# Estado general
docker exec ceph-mon1 ceph status

# Estado de los OSDs
docker exec ceph-mon1 ceph osd tree

# Estado de los pools
docker exec ceph-mon1 ceph df

# Estado de los monitores
docker exec ceph-mon1 ceph mon stat
```

## Accesos

| Servicio          | URL                          | Credenciales          |
|-------------------|------------------------------|-----------------------|
| S3 API            | http://localhost              | Ver usuario RGW       |
| Ceph Dashboard    | https://localhost:8443        | admin / (ver .env)    |
| Grafana           | http://localhost:3000         | admin / (ver .env)    |
| Prometheus        | http://localhost:9090         | —                     |
| HAProxy Stats     | http://localhost:8404/stats   | admin / haproxy_stats_2024 |

## Estructura de directorios

```
ceph-stack/
├── docker-compose.yml
├── .env
├── ceph-config/          ← keyrings y ceph.conf (generados por bootstrap)
│   ├── ceph.conf
│   ├── ceph.mon.keyring
│   └── ceph.client.admin.keyring
├── haproxy/
│   ├── haproxy.cfg
│   └── certs/            ← coloca aquí tu certificado TLS
├── prometheus/
│   └── prometheus.yml
└── grafana/
    ├── provisioning/     ← datasources y dashboards automáticos
    └── dashboards/       ← archivos JSON de Grafana dashboards
```

## Notas de producción

1. **OSD en producción**: cada OSD debe mapear a un disco físico dedicado con `devices:` en compose, no un volumen Docker.
2. **Red pública vs cluster**: en producción usar dos redes separadas (public_network y cluster_network).
3. **TLS**: configurar certificados en HAProxy y en el Dashboard de Ceph.
4. **Backup de keyrings**: los archivos en `ceph-config/` son críticos — respaldarlos inmediatamente.
5. **Replication factor**: ajustar `osd_pool_default_size = 3` en ceph.conf según disponibilidad de OSDs.
6. **CRUSH map**: en producción configurar dominios de fallo por host/rack/datacenter.