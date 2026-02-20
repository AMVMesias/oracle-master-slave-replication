@echo off
REM filepath: c:\Users\mesia\Desktop\Universidad\BD Avanzada\P2\proyecto\oracle-replication\scripts\stop_monitor.bat
echo ========================================
echo DETENIENDO MONITOR AUTOMATICO
echo ========================================

echo Buscando procesos de monitoreo...
echo Matando todos los procesos de PowerShell...
taskkill /f /im powershell.exe 2>nul

echo Esperando 3 segundos para que terminen los procesos...
timeout /t 3 /nobreak >nul

echo Verificando si hay procesos PowerShell restantes...
tasklist | findstr powershell

echo Limpiando archivos de control...
del system_state.txt 2>nul
del monitor.log 2>nul

echo.
echo ========================================
echo MONITOR AUTOMATICO DETENIDO
echo ========================================
echo.
echo El sistema ya no monitoreara automaticamente
echo Puedes reiniciar el monitor con la opcion 9
echo ========================================
pause
