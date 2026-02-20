@echo off
REM filepath: c:\Users\mesia\Desktop\Universidad\BD Avanzada\P2\proyecto\oracle-replication\scripts\start_monitor.bat
echo ========================================
echo INICIANDO MONITOR AUTOMATICO
echo ========================================

echo Creando archivo de estado del sistema...
echo ORIGINAL > system_state.txt

echo Verificando si hay monitor previo ejecutandose...
taskkill /f /im powershell.exe /fi "WINDOWTITLE eq monitor_service*" 2>nul

echo Iniciando servicio de monitoreo en segundo plano...
start /b powershell -WindowStyle Hidden -ExecutionPolicy Bypass -Command "& '%~dp0monitor_service.ps1'"

echo.
echo ========================================
echo MONITOR AUTOMATICO INICIADO
echo ========================================
echo.
echo El sistema ahora monitoreara automaticamente:
echo - Estado de contenedores Oracle
echo - Failover automatico cuando master se apague
echo - Recuperacion automatica cuando master vuelva
echo - Sincronizacion de datos bidireccional
echo.
echo Para detener el monitor, usa la opcion 10 del menu
echo Para ver el estado del sistema, usa la opcion 11
echo.
echo LOG DE MONITOREO: monitor.log
echo ESTADO DEL SISTEMA: system_state.txt
echo ========================================
pause
