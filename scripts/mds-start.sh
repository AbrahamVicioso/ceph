#!/bin/bash
set -e

MDS_ID=${MDS_ID:-"mds1"}
CEPHFS_NAME=${CEPHFS_NAME:-"cephfs"}

echo "=== MDS $MDS_ID arrancando ==="

until ceph --conf /etc/ceph/ceph.conf mon stat > /dev/null 2>&1; do
  echo "Esperando al monitor..."
  sleep 5
done

mkdir -p /var/lib/ceph/mds/ceph-$MDS_ID

# Crear keyring del MDS
ceph auth get-or-create mds.$MDS_ID \
  mds 'allow *' \
  osd 'allow rwx' \
  mon 'allow profile mds' \
  mgr 'allow profile mds' \
  > /var/lib/ceph/mds/ceph-$MDS_ID/keyring

# Crear CephFS si no existe (solo mds1)
if [ "$MDS_ID" = "mds1" ]; then
  if ! ceph fs ls 2>/dev/null | grep -q $CEPHFS_NAME; then
    echo "=== Creando CephFS: $CEPHFS_NAME ==="
    ceph osd pool create cephfs_metadata 16 || true
    ceph osd pool create cephfs_data 32 || true
    ceph fs new $CEPHFS_NAME cephfs_metadata cephfs_data || true
  fi
fi

chown -R ceph:ceph /var/lib/ceph/mds/

echo "=== Iniciando ceph-mds $MDS_ID ==="
exec ceph-mds --foreground -i $MDS_ID \
  --conf /etc/ceph/ceph.conf \
  --setuser ceph --setgroup ceph