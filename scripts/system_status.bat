@echo off
REM filepath: c:\Users\mesia\Desktop\Universidad\BD Avanzada\P2\proyecto\oracle-replication\scripts\system_status.bat
echo ========================================
echo ESTADO DEL SISTEMA DE REPLICACION
echo ========================================

echo.
echo === ESTADO DE CONTENEDORES ===
docker ps --filter name=oracle --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo.
echo === ESTADO DEL MONITOR ===
if exist system_state.txt (
    set /p estado=<system_state.txt
    echo Estado actual: %estado%
    if "%estado%"=="ORIGINAL" (
        echo 🟢 Sistema en modo normal: MASTER activo, SLAVES solo lectura
    ) else if "%estado%"=="FAILOVER" (
        echo 🔴 Sistema en modo failover: SLAVE1 es el MASTER activo
    ) else (
        echo ⚪ Estado desconocido
    )
) else (
    echo Monitor: DETENIDO
    echo ⚠️  Para activar el monitoreo automatico, usa la opcion 9
)

echo.
echo === CONECTIVIDAD DE BASES DE DATOS ===
echo Probando conectividad a todas las bases de datos...

REM Test Master
echo SELECT 'MASTER-OK' FROM DUAL; > test_conn.sql
echo EXIT; >> test_conn.sql
docker exec oracle-master sqlplus -S / as sysdba < test_conn.sql >nul 2>&1
if %ERRORLEVEL%==0 (
    echo ✅ MASTER: Conectado y funcionando
) else (
    echo ❌ MASTER: No disponible o con problemas
)

REM Test Slave1
docker exec oracle-slave1 sqlplus -S / as sysdba < test_conn.sql >nul 2>&1
if %ERRORLEVEL%==0 (
    echo ✅ SLAVE1: Conectado y funcionando
) else (
    echo ❌ SLAVE1: No disponible o con problemas
)

REM Test Slave2
docker exec oracle-slave2 sqlplus -S / as sysdba < test_conn.sql >nul 2>&1
if %ERRORLEVEL%==0 (
    echo ✅ SLAVE2: Conectado y funcionando
) else (
    echo ❌ SLAVE2: No disponible o con problemas
)

del test_conn.sql 2>nul

echo.
echo === SINCRONIZACION DE DATOS ===
echo Verificando que todos los nodos tengan los mismos datos...

REM Crear query para conteo
echo SELECT COUNT(*) as "Total" FROM maestro.empleados; > count_query.sql
echo EXIT; >> count_query.sql

echo Contando registros en cada nodo:
set master_count=0
set slave1_count=0
set slave2_count=0

REM Obtener conteos (simplificado para mostrar)
echo MASTER:
for /f "tokens=*" %%i in ('docker exec oracle-master sqlplus -S maestro/maestro123@localhost:1521/FREEPDB1 ^< count_query.sql 2^>nul ^| findstr /r "^[0-9]*$"') do set master_count=%%i

echo SLAVE1:
for /f "tokens=*" %%i in ('docker exec oracle-slave1 sqlplus -S esclavo1/esclavo123@localhost:1521/FREEPDB1 ^< count_query.sql 2^>nul ^| findstr /r "^[0-9]*$"') do set slave1_count=%%i

echo SLAVE2:
for /f "tokens=*" %%i in ('docker exec oracle-slave2 sqlplus -S esclavo2/esclavo123@localhost:1521/FREEPDB1 ^< count_query.sql 2^>nul ^| findstr /r "^[0-9]*$"') do set slave2_count=%%i

echo.
echo Resultados:
echo - MASTER: %master_count% empleados
echo - SLAVE1: %slave1_count% empleados  
echo - SLAVE2: %slave2_count% empleados

if "%master_count%"=="%slave1_count%" if "%slave1_count%"=="%slave2_count%" (
    echo ✅ Sincronizacion: PERFECTA - Todos los nodos tienen los mismos datos
) else (
    echo ⚠️  Sincronizacion: DESINCRONIZADA - Los nodos tienen datos diferentes
)

del count_query.sql 2>nul

echo.
echo === PRUEBA DE FUNCIONALIDAD ===
echo Verificando que la replicacion funcione correctamente...

REM Obtener timestamp para crear un ID único
for /f "tokens=1-3 delims=: " %%a in ('time /t') do set timestamp=%%a%%b%%c
set test_id=9%timestamp:~-3%

echo Insertando dato de prueba (ID: %test_id%) en MASTER...
echo INSERT INTO maestro.empleados (id, nombre, departamento, salario, nodo_origen) > test_insert.sql
echo VALUES (%test_id%, 'Test-Status', 'Monitoring', 1000.00, 'STATUS_TEST'); >> test_insert.sql
echo COMMIT; >> test_insert.sql
echo EXIT; >> test_insert.sql

docker exec -i oracle-master sqlplus maestro/maestro123@localhost:1521/FREEPDB1 < test_insert.sql >nul 2>&1

echo Esperando replicacion (3 segundos)...
timeout /t 3 >nul

echo Verificando replicacion en SLAVES...
echo SELECT COUNT(*) FROM maestro.empleados WHERE id = %test_id%; > test_verify.sql
echo EXIT; >> test_verify.sql

set test_slave1=0
set test_slave2=0

for /f "tokens=*" %%i in ('docker exec oracle-slave1 sqlplus -S esclavo1/esclavo123@localhost:1521/FREEPDB1 ^< test_verify.sql 2^>nul ^| findstr /r "^[0-9]*$"') do set test_slave1=%%i
for /f "tokens=*" %%i in ('docker exec oracle-slave2 sqlplus -S esclavo2/esclavo123@localhost:1521/FREEPDB1 ^< test_verify.sql 2^>nul ^| findstr /r "^[0-9]*$"') do set test_slave2=%%i

if "%test_slave1%"=="1" if "%test_slave2%"=="1" (
    echo ✅ Replicacion: FUNCIONANDO - El dato se replico correctamente
) else (
    echo ❌ Replicacion: PROBLEMAS - El dato no se replico correctamente
)

REM Limpiar dato de prueba
echo DELETE FROM maestro.empleados WHERE id = %test_id%; > test_cleanup.sql
echo COMMIT; >> test_cleanup.sql
echo EXIT; >> test_cleanup.sql

docker exec -i oracle-master sqlplus maestro/maestro123@localhost:1521/FREEPDB1 < test_cleanup.sql >nul 2>&1

del test_insert.sql test_verify.sql test_cleanup.sql 2>nul

echo.
echo === LOG DE MONITOREO ===
if exist monitor.log (
    echo Mostrando ultimos 5 eventos del log:
    powershell -Command "Get-Content monitor.log | Select-Object -Last 5"
) else (
    echo No hay log de monitoreo disponible
    echo El monitor automatico no esta activo
)

echo.
echo ========================================
echo RESUMEN DEL ESTADO
echo ========================================
echo Para obtener informacion detallada en tiempo real:
echo - Opcion 9: Iniciar monitor automatico
echo - Opcion 12: Ejecutar demostracion completa
echo - Docker: docker ps --filter name=oracle
echo ========================================
pause
