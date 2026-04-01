#!/bin/bash
set -e

OSD_ID=${OSD_ID:-"0"}
OSD_PATH=${OSD_PATH:-"/var/lib/ceph/osd/ceph-0"}

echo "=== OSD $OSD_ID arrancando en $OSD_PATH ==="

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

mkdir -p $OSD_PATH

# Inicializar solo si no tiene datos
if [ ! -f "$OSD_PATH/type" ]; then
  echo "=== Inicializando OSD $OSD_ID ==="

  UUID=$(uuidgen)

  # Crear keyring PRIMERO (usa ceph.client.admin.keyring para autenticar)
  ceph auth get-or-create osd.$OSD_ID \
    osd 'allow *' \
    mon 'allow profile osd' \
    mgr 'allow profile osd' \
    -o $OSD_PATH/keyring

  # mkfs con el keyring ya disponible
  ceph-osd -i $OSD_ID --mkfs --osd-uuid $UUID \
    --conf /etc/ceph/ceph.conf \
    --keyring $OSD_PATH/keyring

  chown -R ceph:ceph $OSD_PATH
  echo "=== OSD $OSD_ID inicializado correctamente ==="
else
  echo "=== OSD $OSD_ID ya inicializado, arrancando... ==="
fi

echo "=== Iniciando proceso ceph-osd $OSD_ID ==="
exec ceph-osd --foreground -i $OSD_ID \
  --conf /etc/ceph/ceph.conf \
  --setuser ceph --setgroup ceph