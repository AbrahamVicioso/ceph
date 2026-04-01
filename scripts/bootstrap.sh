#!/bin/bash
set -e

FSID=${CEPH_FSID:-"a7f62e58-1234-5678-abcd-aabbccddeeff"}
CONFIG=/etc/ceph/ceph.conf

if [ -f "$CONFIG" ]; then
  echo "=== ceph.conf ya existe, bootstrap omitido ==="
  sleep infinity
  exit 0
fi

echo "=== [1/6] Creando keyring de monitor ==="
ceph-authtool --create-keyring /etc/ceph/ceph.mon.keyring \
  --gen-key -n mon. --cap mon 'allow *'

echo "=== [2/6] Creando keyring de admin ==="
ceph-authtool --create-keyring /etc/ceph/ceph.client.admin.keyring \
  --gen-key -n client.admin \
  --cap mon 'allow *' \
  --cap osd 'allow *' \
  --cap mds 'allow *' \
  --cap mgr 'allow *'

ceph-authtool /etc/ceph/ceph.mon.keyring \
  --import-keyring /etc/ceph/ceph.client.admin.keyring

echo "=== [3/6] Creando monmap con los 3 monitores ==="
monmaptool --create \
  --add mon1 172.20.0.10 \
  --add mon2 172.20.0.11 \
  --add mon3 172.20.0.12 \
  --fsid $FSID \
  /etc/ceph/monmap

echo "=== [4/6] Escribiendo ceph.conf ==="
cat > /etc/ceph/ceph.conf << CONF
[global]
fsid = $FSID
mon_initial_members = mon1,mon2,mon3
mon_host = 172.20.0.10,172.20.0.11,172.20.0.12
auth_cluster_required = cephx
auth_service_required = cephx
auth_client_required = cephx
public_network = 172.20.0.0/24
osd_pool_default_size = 3
osd_pool_default_min_size = 2
osd_journal_size = 1024
[mon]
mon_allow_pool_delete = true
[osd]
osd_class_load_list = *
osd_class_default_list = *
osd_memory_target = 1073741824
CONF

echo "=== [5/6] Inicializando mon1, mon2 y mon3 con mkfs ==="

mkdir -p /var/lib/ceph/mon/ceph-mon1
ceph-mon --mkfs -i mon1 \
  --monmap /etc/ceph/monmap \
  --keyring /etc/ceph/ceph.mon.keyring
chown -R ceph:ceph /var/lib/ceph/mon/ceph-mon1
echo "    mon1 OK"

mkdir -p /var/lib/ceph/mon/ceph-mon2
ceph-mon --mkfs -i mon2 \
  --monmap /etc/ceph/monmap \
  --keyring /etc/ceph/ceph.mon.keyring
chown -R ceph:ceph /var/lib/ceph/mon/ceph-mon2
echo "    mon2 OK"

mkdir -p /var/lib/ceph/mon/ceph-mon3
ceph-mon --mkfs -i mon3 \
  --monmap /etc/ceph/monmap \
  --keyring /etc/ceph/ceph.mon.keyring
chown -R ceph:ceph /var/lib/ceph/mon/ceph-mon3
echo "    mon3 OK"

echo "=== [6/6] Ajustando permisos ==="
chmod 644 /etc/ceph/ceph.conf
chmod 600 /etc/ceph/ceph.client.admin.keyring
chmod 600 /etc/ceph/ceph.mon.keyring

echo ""
echo "=========================================="
echo "=== BOOTSTRAP OK - cluster inicializado ==="
echo "===                                     ==="
echo "=== Ejecuta ahora:                      ==="
echo "===   docker compose stop ceph-bootstrap ==="
echo "===   start.bat                         ==="
echo "=========================================="
sleep infinity