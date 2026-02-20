@echo off
echo ========================================================
echo LIMPIEZA COMPLETA DEL SISTEMA
echo ========================================================
echo.
echo ADVERTENCIA: Esta operacion eliminara:
echo - Todos los contenedores Oracle
echo - Todas las redes Docker
echo - Todos los volumenes
echo - Todos los archivos de estado
echo - Todos los logs
echo.
set /p confirm="¿Estas seguro de que quieres limpiar todo? (S/N): "
if /i not "%confirm%"=="S" (
    echo Operacion cancelada.
    exit /b
)

echo.
echo ========================================
echo DETENIENDO MONITOR...
echo ========================================
call scripts\stop_monitor.bat

echo.
echo ========================================
echo ELIMINANDO CONTENEDORES...
echo ========================================
docker stop oracle-master oracle-slave1 oracle-slave2 2>nul
docker rm oracle-master oracle-slave1 oracle-slave2 2>nul

echo.
echo ========================================
echo ELIMINANDO REDES...
echo ========================================
docker network rm oracle-net 2>nul

echo.
echo ========================================
echo ELIMINANDO VOLUMENES...
echo ========================================
docker volume rm master-data slave1-data slave2-data 2>nul

echo.
echo ========================================
echo LIMPIANDO ARCHIVOS DE ESTADO...
echo ========================================
del scripts\system_state.txt 2>nul
del scripts\monitor.log 2>nul
del scripts\monitor.pid 2>nul
del *.sql 2>nul

echo.
echo ========================================
echo LIMPIEZA COMPLETADA
echo ========================================
echo.
echo El sistema ha sido completamente limpiado.
echo Puedes usar la opcion A del menu para configurar todo de nuevo.
echo.
pause
