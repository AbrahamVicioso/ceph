@echo off
REM =========================================================
REM  RESET COMPLETO — borra todo y empieza desde cero
REM  ADVERTENCIA: elimina todos los datos del cluster
REM =========================================================
echo ADVERTENCIA: Esto elimina TODOS los datos de Ceph.
pause

docker compose down -v
rmdir /s /q ceph-config
mkdir ceph-config

echo.
echo Reset completo. Ahora ejecuta:
echo   1. docker compose up ceph-bootstrap -d
echo   2. Espera el mensaje "Bootstrap completado"
echo   3. docker compose stop ceph-bootstrap
echo   4. start.bat
pause