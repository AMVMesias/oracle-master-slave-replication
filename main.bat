REM filepath: c:\Users\mesia\Desktop\Universidad\BD Avanzada\P2\proyecto\oracle-replication\main.bat
@echo off
echo ========================================================
echo ORACLE REPLICATION - SISTEMA AUTOMATICO
echo ========================================================
:menu
echo.
echo ========================================
echo      SISTEMA DE REPLICACION ORACLE
echo ========================================
echo.
echo A. CONFIGURAR Y EJECUTAR TODO AUTOMATICAMENTE
echo.
echo Este sistema incluye:
echo ✓ Replicacion Master-Slave automatica
echo ✓ Failover automatico con Docker Desktop
echo ✓ Replicacion bidireccional durante failover
echo ✓ Recovery automatico y sincronizacion
echo ✓ Monitoreo continuo en segundo plano
echo.
echo 0. Salir
echo.
set /p opcion="Selecciona una opcion (A o 0): "

if /i "%opcion%"=="A" call scripts/setup_automatic_system.bat
if "%opcion%"=="0" exit /b

if /i not "%opcion%"=="0" (
    echo.
    echo Presiona cualquier tecla para volver al menu...
    pause >nul
    goto menu
)

echo Opcion no valida. Intenta de nuevo.
goto menu