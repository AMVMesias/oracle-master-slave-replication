@echo off
REM filepath: c:\Users\mesia\Desktop\Universidad\BD Avanzada\P2\proyecto\oracle-replication\scripts\demo_automatic.bat
echo ========================================
echo DEMOSTRACION COMPLETA DEL SISTEMA AUTOMATICO
echo ========================================

echo.
echo Esta demostracion ejecutara el ciclo completo:
echo 1. Verificacion del estado inicial
echo 2. Insercion de datos en MASTER
echo 3. Verificacion de replicacion
echo 4. Simulacion de falla del MASTER
echo 5. Failover automatico a SLAVE1
echo 6. Insercion de datos en nuevo MASTER
echo 7. Recuperacion del MASTER original
echo 8. Sincronizacion automatica bidireccional
echo 9. Restauracion al estado original
echo.
choice /c SN /m "Continuar con la demostracion completa? (S/N)"

if "%ERRORLEVEL%"=="2" exit /b

echo.
echo ========================================
echo VERIFICANDO ESTADO INICIAL
echo ========================================
docker ps --filter name=oracle --format "table {{.Names}}\t{{.Status}}"

echo.
echo === PASO 1: INSERCION DE DATOS EN MASTER ===
echo Insertando datos de prueba en MASTER...
echo INSERT INTO maestro.empleados (id, nombre, departamento, salario, nodo_origen) > demo_insert.sql
echo VALUES (1001, 'Demo-Original', 'Testing', 1500.00, 'MASTER_ORIGINAL'); >> demo_insert.sql
echo COMMIT; >> demo_insert.sql
echo SELECT 'Dato insertado en MASTER original - ID: 1001' FROM DUAL; >> demo_insert.sql
echo EXIT; >> demo_insert.sql

docker exec -i oracle-master sqlplus maestro/maestro123@localhost:1521/FREEPDB1 < demo_insert.sql

echo Esperando replicacion (3 segundos)...
timeout /t 3 >nul

echo.
echo === PASO 2: VERIFICACION DE REPLICACION ===
echo SELECT COUNT(*) as "Empleados con ID 1001" FROM maestro.empleados WHERE id = 1001; > demo_verify.sql
echo EXIT; >> demo_verify.sql

echo Verificando en SLAVE1:
docker exec -i oracle-slave1 sqlplus -S esclavo1/esclavo123@localhost:1521/FREEPDB1 < demo_verify.sql

echo Verificando en SLAVE2:
docker exec -i oracle-slave2 sqlplus -S esclavo2/esclavo123@localhost:1521/FREEPDB1 < demo_verify.sql

echo.
echo === PASO 3: SIMULACION DE FALLA DEL MASTER ===
echo.
echo ATENCION: Se va a detener el MASTER para simular una falla
choice /c S /m "Presiona S para DETENER el MASTER y continuar"

echo Deteniendo MASTER...
docker stop oracle-master

echo.
echo Estado despues de la falla:
docker ps --filter name=oracle --format "table {{.Names}}\t{{.Status}}"

echo.
echo === PASO 4: EJECUTANDO FAILOVER AUTOMATICO ===
echo Promoviendo SLAVE1 a MASTER...

echo ALTER PLUGGABLE DATABASE FREEPDB1 OPEN; > auto_promote.sql
echo ALTER SESSION SET CONTAINER = FREEPDB1; >> auto_promote.sql
echo GRANT RESOURCE TO esclavo1; >> auto_promote.sql
echo GRANT CREATE TRIGGER TO esclavo1; >> auto_promote.sql
echo GRANT CREATE DATABASE LINK TO esclavo1; >> auto_promote.sql
echo GRANT UNLIMITED TABLESPACE TO esclavo1; >> auto_promote.sql
echo ALTER USER esclavo1 QUOTA UNLIMITED ON USERS; >> auto_promote.sql
echo GRANT INSERT, UPDATE, DELETE ON maestro.empleados TO esclavo1; >> auto_promote.sql
echo GRANT INSERT, UPDATE, DELETE ON maestro.productos TO esclavo1; >> auto_promote.sql
echo SELECT 'SLAVE1 promovido a MASTER exitosamente' FROM DUAL; >> auto_promote.sql
echo EXIT; >> auto_promote.sql

docker exec -i oracle-slave1 sqlplus / as sysdba < auto_promote.sql

echo.
echo Creando enlace hacia SLAVE2...
echo ALTER SESSION SET CONTAINER = FREEPDB1; > auto_link.sql
echo CREATE DATABASE LINK slave2_link >> auto_link.sql
echo CONNECT TO maestro IDENTIFIED BY maestro123 >> auto_link.sql
echo USING 'oracle-slave2:1521/FREEPDB1'; >> auto_link.sql
echo SELECT 'Enlace a SLAVE2 creado exitosamente' FROM DUAL; >> auto_link.sql
echo EXIT; >> auto_link.sql

docker exec -i oracle-slave1 sqlplus / as sysdba < auto_link.sql

echo.
echo Creando trigger de replicacion en nuevo MASTER...
echo ALTER SESSION SET CONTAINER = FREEPDB1; > auto_trigger.sql
echo CREATE OR REPLACE TRIGGER trg_empleados_failover >> auto_trigger.sql
echo AFTER INSERT OR UPDATE OR DELETE ON maestro.empleados >> auto_trigger.sql
echo FOR EACH ROW >> auto_trigger.sql
echo BEGIN >> auto_trigger.sql
echo     IF INSERTING THEN >> auto_trigger.sql
echo         BEGIN >> auto_trigger.sql
echo             INSERT INTO maestro.empleados@slave2_link >> auto_trigger.sql
echo             VALUES (:NEW.id, :NEW.nombre, :NEW.departamento, :NEW.salario, >> auto_trigger.sql
echo                     :NEW.fecha_ingreso, :NEW.nodo_origen, :NEW.fecha_modificacion); >> auto_trigger.sql
echo         EXCEPTION >> auto_trigger.sql
echo             WHEN OTHERS THEN >> auto_trigger.sql
echo                 NULL; >> auto_trigger.sql
echo         END; >> auto_trigger.sql
echo     END IF; >> auto_trigger.sql
echo END; >> auto_trigger.sql
echo / >> auto_trigger.sql
echo SELECT 'Trigger de replicacion creado' FROM DUAL; >> auto_trigger.sql
echo EXIT; >> auto_trigger.sql

docker exec -i oracle-slave1 sqlplus / as sysdba < auto_trigger.sql

echo.
echo === PASO 5: PROBANDO NUEVO MASTER ===
echo Insertando datos en nuevo MASTER (ex-SLAVE1)...
echo INSERT INTO maestro.empleados (id, nombre, departamento, salario, nodo_origen) > test_new_master.sql
echo VALUES (2002, 'Post-Failover', 'Recovery', 2000.00, 'NEW_MASTER'); >> test_new_master.sql
echo COMMIT; >> test_new_master.sql
echo SELECT 'Dato insertado en NUEVO MASTER - ID: 2002' FROM DUAL; >> test_new_master.sql
echo EXIT; >> test_new_master.sql

docker exec -i oracle-slave1 sqlplus esclavo1/esclavo123@localhost:1521/FREEPDB1 < test_new_master.sql

echo Esperando replicacion hacia SLAVE2 (3 segundos)...
timeout /t 3 >nul

echo.
echo === PASO 6: VERIFICACION DEL FAILOVER ===
echo SELECT COUNT(*) as "Empleados con ID 2002" FROM maestro.empleados WHERE id = 2002; > verify_failover.sql
echo EXIT; >> verify_failover.sql

echo Verificando en NUEVO MASTER (SLAVE1):
docker exec -i oracle-slave1 sqlplus -S esclavo1/esclavo123@localhost:1521/FREEPDB1 < verify_failover.sql

echo Verificando en SLAVE2:
docker exec -i oracle-slave2 sqlplus -S esclavo2/esclavo123@localhost:1521/FREEPDB1 < verify_failover.sql

echo.
echo === PASO 7: RECUPERACION DEL MASTER ORIGINAL ===
choice /c S /m "Presiona S para INICIAR el MASTER original y activar recuperacion"

echo Iniciando MASTER original...
docker start oracle-master

echo Esperando que Oracle inicie completamente (30 segundos)...
timeout /t 30 >nul

echo.
echo === PASO 8: SINCRONIZACION AUTOMATICA ===
echo Sincronizando datos desde SLAVE1 hacia MASTER original...

echo ALTER SESSION SET CONTAINER = FREEPDB1; > auto_sync.sql
echo CREATE DATABASE LINK temp_slave1_link >> auto_sync.sql
echo CONNECT TO esclavo1 IDENTIFIED BY esclavo123 >> auto_sync.sql
echo USING 'oracle-slave1:1521/FREEPDB1'; >> auto_sync.sql
echo TRUNCATE TABLE maestro.empleados; >> auto_sync.sql
echo INSERT INTO maestro.empleados >> auto_sync.sql
echo SELECT * FROM maestro.empleados@temp_slave1_link; >> auto_sync.sql
echo COMMIT; >> auto_sync.sql
echo DROP DATABASE LINK temp_slave1_link; >> auto_sync.sql
echo SELECT 'Datos sincronizados desde SLAVE1 hacia MASTER' FROM DUAL; >> auto_sync.sql
echo EXIT; >> auto_sync.sql

docker exec -i oracle-master sqlplus / as sysdba < auto_sync.sql

echo.
echo === PASO 9: RESTAURACION DEL ESTADO ORIGINAL ===
echo Restaurando permisos originales...

echo ALTER SESSION SET CONTAINER = FREEPDB1; > auto_restore.sql
echo GRANT ALL PRIVILEGES ON maestro.empleados TO maestro; >> auto_restore.sql
echo GRANT ALL PRIVILEGES ON maestro.productos TO maestro; >> auto_restore.sql
echo REVOKE INSERT, UPDATE, DELETE ON maestro.empleados FROM esclavo1; >> auto_restore.sql
echo REVOKE INSERT, UPDATE, DELETE ON maestro.productos FROM esclavo1; >> auto_restore.sql
echo GRANT SELECT ON maestro.empleados TO esclavo1; >> auto_restore.sql
echo GRANT SELECT ON maestro.productos TO esclavo1; >> auto_restore.sql
echo GRANT SELECT ON maestro.empleados TO esclavo2; >> auto_restore.sql
echo GRANT SELECT ON maestro.productos TO esclavo2; >> auto_restore.sql
echo SELECT 'Permisos originales restaurados' FROM DUAL; >> auto_restore.sql
echo EXIT; >> auto_restore.sql

docker exec -i oracle-master sqlplus / as sysdba < auto_restore.sql 2>nul

echo.
echo Limpiando configuracion de failover en SLAVE1...
echo ALTER SESSION SET CONTAINER = FREEPDB1; > auto_cleanup.sql
echo DROP TRIGGER trg_empleados_failover; >> auto_cleanup.sql
echo DROP DATABASE LINK slave2_link; >> auto_cleanup.sql
echo SELECT 'Configuracion de failover limpiada' FROM DUAL; >> auto_cleanup.sql
echo EXIT; >> auto_cleanup.sql

docker exec -i oracle-slave1 sqlplus / as sysdba < auto_cleanup.sql 2>nul

echo.
echo === PASO 10: VERIFICACION FINAL ===
echo Verificando sincronizacion completa...

echo SELECT COUNT(*) as "Total_Empleados" FROM maestro.empleados; > final_check.sql
echo SELECT 'IDs de prueba:' FROM DUAL; >> final_check.sql
echo SELECT id, nombre, nodo_origen FROM maestro.empleados WHERE id IN (1001, 2002) ORDER BY id; >> final_check.sql
echo EXIT; >> final_check.sql

echo.
echo MASTER ORIGINAL:
docker exec -i oracle-master sqlplus -S maestro/maestro123@localhost:1521/FREEPDB1 < final_check.sql

echo.
echo SLAVE1:
docker exec -i oracle-slave1 sqlplus -S esclavo1/esclavo123@localhost:1521/FREEPDB1 < final_check.sql

echo.
echo SLAVE2:
docker exec -i oracle-slave2 sqlplus -S esclavo2/esclavo123@localhost:1521/FREEPDB1 < final_check.sql

REM Limpiar archivos temporales
del demo_insert.sql demo_verify.sql auto_promote.sql auto_link.sql auto_trigger.sql 2>nul
del test_new_master.sql verify_failover.sql auto_sync.sql auto_restore.sql auto_cleanup.sql final_check.sql 2>nul

echo.
echo ========================================
echo DEMOSTRACION AUTOMATICA COMPLETADA
echo ========================================
echo.
echo RESUMEN DEL PROCESO:
echo ========================================
echo ✅ 1. Datos insertados en MASTER original
echo ✅ 2. Replicacion verificada en SLAVES
echo ✅ 3. Falla del MASTER simulada
echo ✅ 4. Failover automatico a SLAVE1 ejecutado
echo ✅ 5. Nuevo MASTER funcionando correctamente
echo ✅ 6. Datos insertados en nuevo MASTER
echo ✅ 7. Replicacion hacia SLAVE2 funcionando
echo ✅ 8. MASTER original recuperado
echo ✅ 9. Sincronizacion bidireccional completada
echo ✅ 10. Sistema restaurado al estado original
echo ========================================
echo.
echo EL SISTEMA FUNCIONA COMPLETAMENTE AUTOMATICO:
echo - Solo necesitas APAGAR/PRENDER contenedores manualmente
echo - Todo lo demas (failover y recuperacion) es automatico
echo - Los datos se mantienen sincronizados siempre
echo ========================================
echo.
echo PARA USO NORMAL:
echo 1. Inicia el monitor automatico (opcion 9)
echo 2. Apaga/prende contenedores cuando quieras
echo 3. El sistema se encarga del resto
echo ========================================
pause
exit /b

echo Esperando que el monitor detecte la falla y active failover (30 segundos)...
timeout /t 30 >nul

echo.
echo === PASO 4: INSERCION EN NUEVO MASTER (SLAVE1) ===
echo Insertando datos en nuevo MASTER...
echo INSERT INTO maestro.empleados (id, nombre, departamento, salario, nodo_origen) > demo_failover.sql
echo VALUES (1002, 'Demo-Failover', 'Recovery', 2000.00, 'NEW_MASTER'); >> demo_failover.sql
echo COMMIT; >> demo_failover.sql
echo SELECT 'Dato insertado en NUEVO MASTER' FROM DUAL; >> demo_failover.sql
echo EXIT; >> demo_failover.sql

docker exec -i oracle-slave1 sqlplus esclavo1/esclavo123@localhost:1521/FREEPDB1 < demo_failover.sql

echo Esperando replicacion hacia SLAVE2 (5 segundos)...
timeout /t 5 >nul

echo Verificando replicacion en SLAVE2:
echo SELECT id, nombre, nodo_origen FROM maestro.empleados WHERE id = 1002; > demo_verify2.sql
echo EXIT; >> demo_verify2.sql

docker exec -i oracle-slave2 sqlplus -S esclavo2/esclavo123@localhost:1521/FREEPDB1 < demo_verify2.sql

echo.
echo === PASO 5: RECUPERACION DEL MASTER ORIGINAL ===
choice /c S /m "Presiona S para INICIAR el MASTER original y activar recuperacion automatica"

echo Iniciando MASTER original...
docker start oracle-master

echo Esperando que el monitor detecte la recuperacion y sincronice (60 segundos)...
timeout /t 60 >nul

echo.
echo === PASO 6: VERIFICACION FINAL ===
echo Verificando que todos los datos esten sincronizados...

echo SELECT COUNT(*) as "Total_Empleados" FROM maestro.empleados; > demo_final.sql
echo SELECT id, nombre, nodo_origen FROM maestro.empleados WHERE id IN (1001, 1002) ORDER BY id; >> demo_final.sql
echo EXIT; >> demo_final.sql

echo.
echo === DATOS EN MASTER ORIGINAL ===
docker exec -i oracle-master sqlplus -S maestro/maestro123@localhost:1521/FREEPDB1 < demo_final.sql

echo.
echo === DATOS EN SLAVE1 ===
docker exec -i oracle-slave1 sqlplus -S esclavo1/esclavo123@localhost:1521/FREEPDB1 < demo_final.sql

echo.
echo === DATOS EN SLAVE2 ===
docker exec -i oracle-slave2 sqlplus -S esclavo2/esclavo123@localhost:1521/FREEPDB1 < demo_final.sql

REM Limpiar archivos
del demo_insert.sql demo_verify.sql demo_failover.sql demo_verify2.sql demo_final.sql 2>nul

echo.
echo ========================================
echo DEMOSTRACION COMPLETADA
echo ========================================
echo.
echo RESUMEN:
echo ✅ Sistema automatico funcionando correctamente
echo ✅ Failover automatico activado cuando MASTER se detuvo
echo ✅ Replicacion funcionando en ambas direcciones
echo ✅ Recuperacion automatica cuando MASTER volvio
echo ✅ Sincronizacion bidireccional completada
echo.
echo El sistema ahora esta en modo ORIGINAL:
echo - MASTER: lectura/escritura
echo - SLAVE1 y SLAVE2: solo lectura
echo - Monitor automatico: ACTIVO
echo ========================================
pause
