#!/bin/bash
set -e

MGR_ID=${MGR_ID:-"mgr1"}

echo "=== MGR $MGR_ID arrancando ==="

# Esperar a que ceph.conf exista
until [ -f /etc/ceph/ceph.conf ]; do
  echo "Esperando ceph.conf..."
  sleep 3
done

# Esperar a que el monitor responda
until ceph --conf /etc/ceph/ceph.conf mon stat > /dev/null 2>&1; do
  echo "Esperando al monitor..."
  sleep 5
done

mkdir -p /var/lib/ceph/mgr/ceph-$MGR_ID

# Crear keyring si no existe
if [ ! -f "/var/lib/ceph/mgr/ceph-$MGR_ID/keyring" ]; then
  echo "=== Creando keyring para MGR $MGR_ID ==="
  ceph auth get-or-create mgr.$MGR_ID \
    mon 'allow profile mgr' \
    osd 'allow *' \
    mds 'allow *' \
    > /var/lib/ceph/mgr/ceph-$MGR_ID/keyring
  chmod 600 /var/lib/ceph/mgr/ceph-$MGR_ID/keyring
else
  echo "=== Keyring MGR $MGR_ID ya existe ==="
fi

chown -R ceph:ceph /var/lib/ceph/mgr/

# Habilitar módulo Prometheus (solo mgr1 lo hace; es idempotente)
if [ "$MGR_ID" = "mgr1" ]; then
  echo "=== Habilitando módulo Prometheus en MGR ==="
  ceph mgr module enable prometheus --force 2>/dev/null || true
  ceph config set mgr mgr/prometheus/server_addr 0.0.0.0 2>/dev/null || true
  ceph config set mgr mgr/prometheus/port 9283 2>/dev/null || true
  echo "=== Módulo Prometheus habilitado ==="
fi

echo "=== Iniciando ceph-mgr $MGR_ID ==="
exec ceph-mgr --foreground -i $MGR_ID \
  --conf /etc/ceph/ceph.conf \
  --setuser ceph --setgroup ceph
