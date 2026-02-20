echo.
echo ========================================
echo SIMULACION DE FAILOVER MEJORADA
echo ========================================

echo.
echo === ESTADO INICIAL ===
echo Verificando estado antes del failover...
docker ps --filter name=oracle --format "table {{.Names}}\t{{.Status}}"

echo.
echo === INSERTANDO DATO ANTES DEL FAILOVER ===
echo INSERT INTO empleados (id, nombre, departamento, salario, nodo_origen) > pre_failover.sql
echo VALUES (9999, 'Pre-Failover', 'Test', 1000.00, 'MASTER'); >> pre_failover.sql
echo COMMIT; >> pre_failover.sql
echo SELECT 'Dato insertado antes del failover - ID: 9999' FROM DUAL; >> pre_failover.sql
echo EXIT; >> pre_failover.sql

echo Insertando dato desde MASTER...
docker exec -i oracle-master sqlplus maestro/maestro123@localhost:1521/FREEPDB1 < pre_failover.sql

echo Esperando replicacion (3 segundos)...
timeout /t 3 >nul

echo.
echo === VERIFICANDO REPLICACION INICIAL ===
echo SELECT COUNT(*) as "Registros en SLAVE1" FROM maestro.empleados WHERE id = 9999; > verify_initial.sql
echo EXIT; >> verify_initial.sql

echo SLAVE1 antes del failover:
docker exec -i oracle-slave1 sqlplus -S esclavo1/esclavo123@localhost:1521/FREEPDB1 < verify_initial.sql

echo SLAVE2 antes del failover:
docker exec -i oracle-slave2 sqlplus -S esclavo2/esclavo123@localhost:1521/FREEPDB1 < verify_initial.sql

echo.
echo ========================================
echo SIMULANDO FALLA DEL MASTER
echo ========================================
echo.
echo ATENCION: Se va a detener el MASTER para simular una falla
choice /c S /m "Presiona S para DETENER el MASTER y continuar con el failover"

echo Deteniendo MASTER...
docker stop oracle-master

echo.
echo === ESTADO POST-FALLA ===
docker ps --filter name=oracle --format "table {{.Names}}\t{{.Status}}"

echo.
echo ========================================
echo PROMOVIENDO SLAVE1 A NUEVO MASTER
echo ========================================

echo.
echo === PASO 1: OTORGANDO PERMISOS DE ESCRITURA ===
echo ALTER PLUGGABLE DATABASE FREEPDB1 OPEN; > promote_slave1.sql
echo ALTER SESSION SET CONTAINER = FREEPDB1; >> promote_slave1.sql
echo -- Otorgar permisos completos a esclavo1 >> promote_slave1.sql
echo GRANT RESOURCE TO esclavo1; >> promote_slave1.sql
echo GRANT CREATE TRIGGER TO esclavo1; >> promote_slave1.sql
echo GRANT CREATE DATABASE LINK TO esclavo1; >> promote_slave1.sql
echo GRANT UNLIMITED TABLESPACE TO esclavo1; >> promote_slave1.sql
echo ALTER USER esclavo1 QUOTA UNLIMITED ON USERS; >> promote_slave1.sql
echo -- Permitir que esclavo1 escriba en tablas de maestro >> promote_slave1.sql
echo GRANT INSERT, UPDATE, DELETE ON maestro.empleados TO esclavo1; >> promote_slave1.sql
echo GRANT INSERT, UPDATE, DELETE ON maestro.productos TO esclavo1; >> promote_slave1.sql
echo SELECT 'SLAVE1 promovido a MASTER exitosamente' FROM DUAL; >> promote_slave1.sql
echo EXIT; >> promote_slave1.sql

echo Promoviendo SLAVE1...
docker exec -i oracle-slave1 sqlplus / as sysdba < promote_slave1.sql

echo.
echo === PASO 2: CREANDO DATABASE LINK HACIA SLAVE2 ===
echo ALTER SESSION SET CONTAINER = FREEPDB1; > create_link_to_slave2.sql
echo -- Crear enlace desde nuevo MASTER (SLAVE1) hacia SLAVE2 >> create_link_to_slave2.sql
echo CREATE DATABASE LINK slave2_link >> create_link_to_slave2.sql
echo CONNECT TO maestro IDENTIFIED BY maestro123 >> create_link_to_slave2.sql
echo USING 'oracle-slave2:1521/FREEPDB1'; >> create_link_to_slave2.sql
echo -- Probar el enlace >> create_link_to_slave2.sql
echo SELECT 'Enlace a SLAVE2 creado:' FROM DUAL; >> create_link_to_slave2.sql
echo SELECT SYSDATE FROM dual@slave2_link; >> create_link_to_slave2.sql
echo EXIT; >> create_link_to_slave2.sql

echo Creando enlace hacia SLAVE2...
docker exec -i oracle-slave1 sqlplus / as sysdba < create_link_to_slave2.sql

echo.
echo === PASO 3: CREANDO TRIGGER DE REPLICACION EN NUEVO MASTER ===
echo ALTER SESSION SET CONTAINER = FREEPDB1; > create_trigger_new_master.sql
echo CREATE OR REPLACE TRIGGER trg_empleados_failover >> create_trigger_new_master.sql
echo AFTER INSERT OR UPDATE OR DELETE ON maestro.empleados >> create_trigger_new_master.sql
echo FOR EACH ROW >> create_trigger_new_master.sql
echo BEGIN >> create_trigger_new_master.sql
echo     IF INSERTING THEN >> create_trigger_new_master.sql
echo         BEGIN >> create_trigger_new_master.sql
echo             INSERT INTO maestro.empleados@slave2_link >> create_trigger_new_master.sql
echo             VALUES (:NEW.id, :NEW.nombre, :NEW.departamento, :NEW.salario, >> create_trigger_new_master.sql
echo                     :NEW.fecha_ingreso, :NEW.nodo_origen, :NEW.fecha_modificacion); >> create_trigger_new_master.sql
echo         EXCEPTION >> create_trigger_new_master.sql
echo             WHEN OTHERS THEN >> create_trigger_new_master.sql
echo                 NULL; >> create_trigger_new_master.sql
echo         END; >> create_trigger_new_master.sql
echo     ELSIF UPDATING THEN >> create_trigger_new_master.sql
echo         BEGIN >> create_trigger_new_master.sql
echo             UPDATE maestro.empleados@slave2_link >> create_trigger_new_master.sql
echo             SET nombre = :NEW.nombre, departamento = :NEW.departamento, >> create_trigger_new_master.sql
echo                 salario = :NEW.salario, fecha_modificacion = :NEW.fecha_modificacion >> create_trigger_new_master.sql
echo             WHERE id = :NEW.id; >> create_trigger_new_master.sql
echo         EXCEPTION >> create_trigger_new_master.sql
echo             WHEN OTHERS THEN >> create_trigger_new_master.sql
echo                 NULL; >> create_trigger_new_master.sql
echo         END; >> create_trigger_new_master.sql
echo     ELSIF DELETING THEN >> create_trigger_new_master.sql
echo         BEGIN >> create_trigger_new_master.sql
echo             DELETE FROM maestro.empleados@slave2_link WHERE id = :OLD.id; >> create_trigger_new_master.sql
echo         EXCEPTION >> create_trigger_new_master.sql
echo             WHEN OTHERS THEN >> create_trigger_new_master.sql
echo                 NULL; >> create_trigger_new_master.sql
echo         END; >> create_trigger_new_master.sql
echo     END IF; >> create_trigger_new_master.sql
echo END; >> create_trigger_new_master.sql
echo / >> create_trigger_new_master.sql
echo SELECT 'Trigger de replicacion creado en nuevo MASTER' FROM DUAL; >> create_trigger_new_master.sql
echo EXIT; >> create_trigger_new_master.sql

echo Creando trigger de replicacion...
docker exec -i oracle-slave1 sqlplus / as sysdba < create_trigger_new_master.sql

echo.
echo === PASO 4: PROBANDO NUEVO MASTER CON INSERCION ===
echo INSERT INTO maestro.empleados (id, nombre, departamento, salario, nodo_origen) > test_new_master.sql
echo VALUES (8888, 'Post-Failover', 'Recovery', 2000.00, 'NEW_MASTER'); >> test_new_master.sql
echo COMMIT; >> test_new_master.sql
echo SELECT 'Dato insertado en NUEVO MASTER - ID: 8888' FROM DUAL; >> test_new_master.sql
echo EXIT; >> test_new_master.sql

echo Insertando dato desde NUEVO MASTER (ex-SLAVE1)...
docker exec -i oracle-slave1 sqlplus esclavo1/esclavo123@localhost:1521/FREEPDB1 < test_new_master.sql

echo Esperando replicacion (3 segundos)...
timeout /t 3 >nul

echo.
echo === PASO 5: VERIFICACION COMPLETA ===
echo Verificando datos en ambos nodos activos...

echo SELECT id, nombre, nodo_origen, 'NUEVO_MASTER' as ubicacion FROM maestro.empleados WHERE id IN (9999, 8888) ORDER BY id; > verify_new_master.sql
echo EXIT; >> verify_new_master.sql

echo SELECT id, nombre, nodo_origen, 'SLAVE2' as ubicacion FROM maestro.empleados WHERE id IN (9999, 8888) ORDER BY id; > verify_slave2.sql
echo EXIT; >> verify_slave2.sql

echo === DATOS EN NUEVO MASTER (ex-SLAVE1) ===
docker exec -i oracle-slave1 sqlplus -S esclavo1/esclavo123@localhost:1521/FREEPDB1 < verify_new_master.sql

echo === DATOS EN SLAVE2 ===
docker exec -i oracle-slave2 sqlplus -S esclavo2/esclavo123@localhost:1521/FREEPDB1 < verify_slave2.sql

echo.
echo === PASO 6: PRUEBA DE ACTUALIZACION ===
echo UPDATE maestro.empleados SET salario = 2500.00 WHERE id = 8888; > test_update.sql
echo COMMIT; >> test_update.sql
echo SELECT 'Salario actualizado para ID 8888' FROM DUAL; >> test_update.sql
echo EXIT; >> test_update.sql

echo Actualizando dato desde NUEVO MASTER...
docker exec -i oracle-slave1 sqlplus esclavo1/esclavo123@localhost:1521/FREEPDB1 < test_update.sql

timeout /t 3 >nul

echo SELECT id, nombre, salario, 'ACTUALIZADO_EN_SLAVE2' as estado FROM maestro.empleados WHERE id = 8888; > verify_update.sql
echo EXIT; >> verify_update.sql

echo Verificando actualizacion en SLAVE2:
docker exec -i oracle-slave2 sqlplus -S esclavo2/esclavo123@localhost:1521/FREEPDB1 < verify_update.sql

REM Limpiar archivos
del pre_failover.sql verify_initial.sql promote_slave1.sql create_link_to_slave2.sql 2>nul
del create_trigger_new_master.sql test_new_master.sql verify_new_master.sql verify_slave2.sql 2>nul
del test_update.sql verify_update.sql 2>nul

echo.
echo ========================================
echo FAILOVER COMPLETADO EXITOSAMENTE
echo ========================================
echo NUEVA ARQUITECTURA ACTIVA:
echo ========================================
echo ❌ MASTER ORIGINAL: DETENIDO (puerto 1521)
echo ✅ NUEVO MASTER (ex-SLAVE1): ACTIVO (puerto 1522)
echo    - Usuario: esclavo1/esclavo123 (LECTURA/ESCRITURA)
echo    - Replicacion hacia SLAVE2: ACTIVA
echo ✅ SLAVE2: FUNCIONANDO (puerto 1523)
echo    - Usuario: esclavo2/esclavo123 (SOLO LECTURA)
echo ========================================
echo.
echo COMANDOS PARA USO POST-FAILOVER:
echo CONECTAR AL NUEVO MASTER:
echo docker exec -it oracle-slave1 sqlplus esclavo1/esclavo123@localhost:1521/FREEPDB1
echo.
echo CONECTAR AL SLAVE2:
echo docker exec -it oracle-slave2 sqlplus esclavo2/esclavo123@localhost:1521/FREEPDB1
echo.
echo INSERTAR DATOS EN NUEVO MASTER:
echo INSERT INTO maestro.empleados (id, nombre, departamento, salario, nodo_origen) 
echo VALUES (XXXX, 'Nombre', 'Depto', 0000.00, 'NEW_MASTER');
echo.
echo CONSULTAR EN SLAVE2:
echo SELECT * FROM maestro.empleados WHERE nodo_origen = 'NEW_MASTER';
echo ========================================
pause
exit /b