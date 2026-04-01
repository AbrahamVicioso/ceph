@echo off
REM =========================================================
REM  Arranque escalonado del cluster Ceph
REM  Ejecutar desde: C:\Users\AVICIOSO\Desktop\ceph\
REM =========================================================

echo.
echo [1/6] Levantando MONITOREs...
docker compose up -d mon1 mon2 mon3
echo     Esperando 60s para quorum...
timeout /t 5 /nobreak >nul

echo.
echo [2/6] Levantando MANAGERs...
docker compose up -d mgr1 mgr2
echo     Esperando 30s...
timeout /t 5 /nobreak >nul

echo.
echo [3/6] Levantando OSDs...
docker compose up -d osd0 osd1 osd2 osd3
echo     Esperando 60s para que los OSDs registren...
timeout /t 5 /nobreak >nul

echo.
echo [4/6] Levantando MDS (CephFS)...
docker compose up -d mds1 mds2
echo     Esperando 20s...
timeout /t 5 /nobreak >nul

echo.
echo [5/6] Levantando RGW (S3 Gateway)...
docker compose up -d rgw1 rgw2
echo     Esperando 60s para que RGW inicialice pools...
timeout /t 5 /nobreak >nul

echo.
echo [6/6] Levantando HAProxy + Observabilidad...
docker compose up -d haproxy prometheus grafana

echo.
echo =========================================================
echo  Verificando estado del cluster...
echo =========================================================
docker exec ceph-mon1 ceph status

echo.
echo  ACCESOS:
echo    S3 API     : http://localhost
echo    Dashboard  : https://localhost:8443
echo    Grafana    : http://localhost:3000  (admin / ceph_admin_2024)
echo    Prometheus : http://localhost:9090
echo    HAProxy    : http://localhost:8404/stats
echo.
pause