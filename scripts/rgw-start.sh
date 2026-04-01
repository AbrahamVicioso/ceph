#!/bin/bash
set -e

RGW_ID=${RGW_ID:-"rgw1"}
RGW_PORT=${RGW_PORT:-"7480"}

echo "=== RGW $RGW_ID arrancando en puerto $RGW_PORT ==="

until ceph --conf /etc/ceph/ceph.conf mon stat > /dev/null 2>&1; do
  echo "Esperando al monitor..."
  sleep 5
done

# Esperar a que haya OSDs activos
until [ "$(ceph --conf /etc/ceph/ceph.conf osd stat | grep -o '[0-9]* up' | awk '{print $1}')" -ge "1" ] 2>/dev/null; do
  echo "Esperando OSDs activos..."
  sleep 5
done

RGW_DATA="/var/lib/ceph/radosgw/ceph-rgw.$RGW_ID"
mkdir -p $RGW_DATA

# Crear keyring del RGW (usa ceph.client.admin.keyring para autenticar)
ceph auth get-or-create client.rgw.$RGW_ID \
  osd 'allow rwx' \
  mon 'allow rw' \
  mgr 'allow rw' \
  -o $RGW_DATA/keyring

chown -R ceph:ceph /var/lib/ceph/radosgw/

echo "=== Iniciando radosgw $RGW_ID en :$RGW_PORT ==="
exec radosgw --foreground \
  -n client.rgw.$RGW_ID \
  --conf /etc/ceph/ceph.conf \
  --keyring $RGW_DATA/keyring \
  --rgw-frontends="beast port=$RGW_PORT" \
  --setuser ceph --setgroup ceph