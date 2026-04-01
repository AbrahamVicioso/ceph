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

echo "=== Iniciando ceph-mgr $MGR_ID ==="
exec ceph-mgr --foreground -i $MGR_ID \
  --conf /etc/ceph/ceph.conf \
  --setuser ceph --setgroup ceph
