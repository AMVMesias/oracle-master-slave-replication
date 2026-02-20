@echo off
echo ========================================================
echo CONFIGURACION AUTOMATICA DEL SISTEMA
echo ========================================================
echo.
echo Este script configurara todo el sistema automaticamente
echo para que puedas hacer failover/recovery desde Docker Desktop
echo.
echo Pasos que se ejecutaran:
echo 1. Inicializar contenedores Oracle
echo 2. Crear usuarios
echo 3. Crear tablas
echo 4. Crear enlaces de base de datos
echo 5. Crear triggers
echo 6. Insertar datos iniciales
echo 7. Verificar replicacion
echo 8. Iniciar monitor automatico
echo 9. Configurar triggers bidireccionales inteligentes
echo.
set /p confirm="¿Continuar? (S/N): "
if /i not "%confirm%"=="S" (
    echo Operacion cancelada.
    goto end
)

echo.
echo ========================================================
echo EJECUTANDO CONFIGURACION AUTOMATICA...
echo ========================================================

echo.
echo [1/8] Inicializando contenedores Oracle...
call scripts\init_containers.bat
if errorlevel 1 (
    echo ERROR: No se pudieron inicializar los contenedores
    goto end
)

echo.
echo [2/8] Creando usuarios...
call scripts\create_users.bat
if errorlevel 1 (
    echo ERROR: No se pudieron crear los usuarios
    goto end
)

echo.
echo [3/8] Creando tablas...
call scripts\create_tables.bat
if errorlevel 1 (
    echo ERROR: No se pudieron crear las tablas
    goto end
)

echo.
echo [4/8] Creando enlaces de base de datos...
call scripts\create_links.bat
if errorlevel 1 (
    echo ERROR: No se pudieron crear los enlaces
    goto end
)

echo.
echo [5/8] Creando triggers...
call scripts\create_triggers.bat
if errorlevel 1 (
    echo ERROR: No se pudieron crear los triggers
    goto end
)

echo.
echo [6/8] Insertando datos iniciales...
call scripts\insert_data_simple.bat
if errorlevel 1 (
    echo ERROR: No se pudieron insertar los datos
    goto end
)

echo.
echo [7/8] Verificando replicacion...
call scripts\verify.bat
if errorlevel 1 (
    echo ERROR: La verificacion de replicacion fallo
    goto end
)

echo.
echo [8/9] Iniciando monitor automatico...
call scripts\start_monitor.bat
if errorlevel 1 (
    echo ERROR: No se pudo iniciar el monitor
    goto end
)

echo.
echo [9/10] Configurando sistema de replicacion bidireccional inteligente...
echo Creando sistema automatico para replicacion bidireccional durante failover...

REM Crear script inteligente que se ejecuta automaticamente durante failover
echo @echo off > scripts\smart_bidirectional_setup.bat
echo REM Sistema automatico de replicacion bidireccional >> scripts\smart_bidirectional_setup.bat
echo if not exist "scripts\system_state.txt" exit /b 0 >> scripts\smart_bidirectional_setup.bat
echo set /p ESTADO=^<scripts\system_state.txt >> scripts\smart_bidirectional_setup.bat
echo. >> scripts\smart_bidirectional_setup.bat
echo if "%%ESTADO%%"=="FAILOVER" ( >> scripts\smart_bidirectional_setup.bat
echo   echo Configurando replicacion SLAVE1 ^-^> SLAVE2... >> scripts\smart_bidirectional_setup.bat
echo   echo CREATE DATABASE LINK slave2_failover_link CONNECT TO maestro IDENTIFIED BY maestro123 USING 'oracle-slave2:1521/FREEPDB1'; ^> temp_smart_link.sql >> scripts\smart_bidirectional_setup.bat
echo   echo EXIT; ^>^> temp_smart_link.sql >> scripts\smart_bidirectional_setup.bat
echo   docker cp temp_smart_link.sql oracle-slave1:/tmp/smart_link.sql 2^>nul >> scripts\smart_bidirectional_setup.bat
echo   docker exec oracle-slave1 sqlplus maestro/maestro123@localhost:1521/FREEPDB1 @/tmp/smart_link.sql 2^>nul >> scripts\smart_bidirectional_setup.bat
echo. >> scripts\smart_bidirectional_setup.bat
echo   echo CREATE OR REPLACE TRIGGER trg_empleados_failover ^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo   AFTER INSERT OR UPDATE OR DELETE ON maestro.empleados ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo   FOR EACH ROW ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo   DECLARE ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo     PRAGMA AUTONOMOUS_TRANSACTION; ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo   BEGIN ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo     IF INSERTING THEN ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo       BEGIN ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo         INSERT INTO maestro.empleados@slave2_failover_link VALUES ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo         (:NEW.id, :NEW.nombre, :NEW.departamento, :NEW.salario, ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo          :NEW.fecha_ingreso, :NEW.nodo_origen, :NEW.fecha_modificacion^^); ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo       EXCEPTION WHEN OTHERS THEN NULL; END; ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo     ELSIF UPDATING THEN ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo       BEGIN ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo         UPDATE maestro.empleados@slave2_failover_link SET ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo           nombre = :NEW.nombre, departamento = :NEW.departamento, ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo           salario = :NEW.salario, fecha_modificacion = :NEW.fecha_modificacion ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo         WHERE id = :NEW.id; ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo       EXCEPTION WHEN OTHERS THEN NULL; END; ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo     ELSIF DELETING THEN ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo       BEGIN ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo         DELETE FROM maestro.empleados@slave2_failover_link WHERE id = :OLD.id; ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo       EXCEPTION WHEN OTHERS THEN NULL; END; ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo     END IF; ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo     COMMIT; ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo   END; ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo   / ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo CREATE OR REPLACE TRIGGER trg_productos_failover ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo   AFTER INSERT OR UPDATE OR DELETE ON maestro.productos ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo   FOR EACH ROW ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo   DECLARE ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo     PRAGMA AUTONOMOUS_TRANSACTION; ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo   BEGIN ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo     IF INSERTING THEN ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo       BEGIN ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo         INSERT INTO maestro.productos@slave2_failover_link VALUES ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo         (:NEW.producto_id, :NEW.nombre_producto, :NEW.precio, :NEW.stock, :NEW.categoria^^); ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo       EXCEPTION WHEN OTHERS THEN NULL; END; ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo     ELSIF UPDATING THEN ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo       BEGIN ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo         UPDATE maestro.productos@slave2_failover_link SET ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo           nombre_producto = :NEW.nombre_producto, precio = :NEW.precio, ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo           stock = :NEW.stock, categoria = :NEW.categoria ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo         WHERE producto_id = :NEW.producto_id; ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo       EXCEPTION WHEN OTHERS THEN NULL; END; ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo     ELSIF DELETING THEN ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo       BEGIN ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo         DELETE FROM maestro.productos@slave2_failover_link WHERE producto_id = :OLD.producto_id; ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo       EXCEPTION WHEN OTHERS THEN NULL; END; ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo     END IF; ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo     COMMIT; ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo   END; ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo   / ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   echo EXIT; ^>^> temp_smart_triggers.sql >> scripts\smart_bidirectional_setup.bat
echo   docker cp temp_smart_triggers.sql oracle-slave1:/tmp/smart_triggers.sql 2^>nul >> scripts\smart_bidirectional_setup.bat
echo   docker exec oracle-slave1 sqlplus maestro/maestro123@localhost:1521/FREEPDB1 @/tmp/smart_triggers.sql 2^>nul >> scripts\smart_bidirectional_setup.bat
echo   del temp_smart_*.sql 2^>nul >> scripts\smart_bidirectional_setup.bat
echo   echo Replicacion bidireccional SLAVE1 ^-^> SLAVE2 configurada >> scripts\smart_bidirectional_setup.bat
echo ^) >> scripts\smart_bidirectional_setup.bat
echo. >> scripts\smart_bidirectional_setup.bat
echo if "%%ESTADO%%"=="SLAVE2_FAILOVER" ( >> scripts\smart_bidirectional_setup.bat
echo   echo Configurando replicacion SLAVE2 ^-^> SLAVE1... >> scripts\smart_bidirectional_setup.bat
echo   echo Sistema en modo emergencia con SLAVE2 activo >> scripts\smart_bidirectional_setup.bat
echo ^) >> scripts\smart_bidirectional_setup.bat

echo.
echo [10/10] Ejecutando configuracion inteligente inicial...
call scripts\smart_bidirectional_setup.bat 2>nul

echo.
echo ========================================================
echo SISTEMA COMPLETO CONFIGURADO EXITOSAMENTE
echo ========================================================
echo.
echo ✓ Replicacion Master-Slave automatica
echo ✓ Monitor automatico de failover/recovery  
echo ✓ Sistema inteligente de replicacion bidireccional
echo ✓ Sincronizacion automatica en todos los modos
echo.
echo ========================================
echo COMO USAR EL SISTEMA:
echo ========================================
echo.
echo === MODO NORMAL ===
echo 1. Conectarse a MASTER: docker exec -it oracle-master sqlplus maestro/maestro123@localhost:1521/FREEPDB1
echo 2. Insertar datos (se replican automaticamente a SLAVE1 y SLAVE2)
echo.
echo === FAILOVER AUTOMATICO ===
echo 1. Para el contenedor oracle-master en Docker Desktop
echo 2. El sistema detecta el fallo y activa SLAVE1 como MASTER
echo 3. ¡LA REPLICACION BIDIRECCIONAL SE CONFIGURA AUTOMATICAMENTE!
echo 4. Conectarse a SLAVE1: docker exec -it oracle-slave1 sqlplus esclavo1/esclavo123@localhost:1521/FREEPDB1
echo 5. Insertar datos en SLAVE1 (se replican automaticamente a SLAVE2)
echo.
echo === RECOVERY AUTOMATICO ===
echo 1. Encender oracle-master en Docker Desktop
echo 2. El sistema detecta la recuperacion y sincroniza automaticamente
echo.
echo === COMANDOS UTILES ===
echo Ver estado: docker ps --filter name=oracle
echo Ver logs monitor: type scripts\monitor.log
echo Estado sistema: type scripts\system_state.txt
echo.
echo ¡SISTEMA LISTO PARA USAR! Todo es automatico.
echo ¡La replicacion bidireccional se activa automáticamente durante failover!
echo.

:end
pause
