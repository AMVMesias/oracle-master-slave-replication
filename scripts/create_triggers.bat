echo ========================================
echo Configurando replicacion Master-Slave con triggers...
echo ========================================

echo.
echo === LIMPIANDO TRIGGERS Y LINKS EXISTENTES ===
echo Eliminando configuracion previa...

REM Crear script para eliminar triggers (ignorar errores)
echo WHENEVER SQLERROR CONTINUE; > temp_clean.sql
echo DROP TRIGGER trg_empleados_repl; >> temp_clean.sql
echo DROP TRIGGER trg_productos_repl; >> temp_clean.sql
echo DROP DATABASE LINK slave1_link; >> temp_clean.sql
echo DROP DATABASE LINK slave2_link; >> temp_clean.sql
echo DROP DATABASE LINK master_link; >> temp_clean.sql
echo SELECT 'Limpieza completada' FROM DUAL; >> temp_clean.sql
echo EXIT; >> temp_clean.sql

REM Limpiar en todos los nodos
docker cp temp_clean.sql oracle-master:/tmp/clean.sql
docker exec oracle-master sqlplus maestro/maestro123@localhost:1521/FREEPDB1 @/tmp/clean.sql 2>nul

docker cp temp_clean.sql oracle-slave1:/tmp/clean.sql
docker exec oracle-slave1 sqlplus maestro/maestro123@localhost:1521/FREEPDB1 @/tmp/clean.sql 2>nul

docker cp temp_clean.sql oracle-slave2:/tmp/clean.sql
docker exec oracle-slave2 sqlplus maestro/maestro123@localhost:1521/FREEPDB1 @/tmp/clean.sql 2>nul

echo.
echo === OTORGANDO PERMISOS NECESARIOS ===
echo Otorgando permisos para database links y triggers...

REM Crear script de permisos para SYS
echo ALTER SESSION SET "_ORACLE_SCRIPT"=true; > temp_sys_grants.sql
echo GRANT CREATE DATABASE LINK TO maestro; >> temp_sys_grants.sql
echo GRANT CREATE TRIGGER TO maestro; >> temp_sys_grants.sql
echo GRANT CREATE ANY TRIGGER TO maestro; >> temp_sys_grants.sql
echo GRANT DROP ANY TRIGGER TO maestro; >> temp_sys_grants.sql
echo EXIT; >> temp_sys_grants.sql

REM Aplicar permisos en todos los nodos como SYS
docker cp temp_sys_grants.sql oracle-master:/tmp/sys_grants.sql
docker exec oracle-master sqlplus sys/Oradoc_db1@localhost:1521/FREEPDB1 AS SYSDBA @/tmp/sys_grants.sql 2>nul

docker cp temp_sys_grants.sql oracle-slave1:/tmp/sys_grants.sql
docker exec oracle-slave1 sqlplus sys/Oradoc_db1@localhost:1521/FREEPDB1 AS SYSDBA @/tmp/sys_grants.sql 2>nul

docker cp temp_sys_grants.sql oracle-slave2:/tmp/sys_grants.sql
docker exec oracle-slave2 sqlplus sys/Oradoc_db1@localhost:1521/FREEPDB1 AS SYSDBA @/tmp/sys_grants.sql 2>nul

echo.
echo === CREANDO DATABASE LINKS SOLO EN MASTER ===
echo Creando enlaces desde MASTER hacia SLAVE1 y SLAVE2...

REM Solo crear links en MASTER - los slaves no necesitan links para esta configuracion
echo CREATE DATABASE LINK slave1_link CONNECT TO maestro IDENTIFIED BY maestro123 USING 'oracle-slave1:1521/FREEPDB1'; > temp_master_links.sql
echo CREATE DATABASE LINK slave2_link CONNECT TO maestro IDENTIFIED BY maestro123 USING 'oracle-slave2:1521/FREEPDB1'; >> temp_master_links.sql
echo SELECT 'Database links creados en MASTER' FROM DUAL; >> temp_master_links.sql
echo EXIT; >> temp_master_links.sql

docker cp temp_master_links.sql oracle-master:/tmp/master_links.sql
docker exec oracle-master sqlplus maestro/maestro123@localhost:1521/FREEPDB1 @/tmp/master_links.sql

echo.
echo === CREANDO TRIGGERS SOLO EN MASTER ===
echo Creando triggers de replicacion en MASTER...

REM Crear triggers simples y efectivos solo en MASTER
echo CREATE OR REPLACE TRIGGER trg_empleados_repl > temp_master_triggers.sql
echo   AFTER INSERT OR UPDATE OR DELETE ON empleados >> temp_master_triggers.sql
echo   FOR EACH ROW >> temp_master_triggers.sql
echo   DECLARE >> temp_master_triggers.sql
echo     PRAGMA AUTONOMOUS_TRANSACTION; >> temp_master_triggers.sql
echo   BEGIN >> temp_master_triggers.sql
echo     IF INSERTING THEN >> temp_master_triggers.sql
echo       BEGIN >> temp_master_triggers.sql
echo         INSERT INTO empleados@slave1_link VALUES >> temp_master_triggers.sql
echo         (:NEW.id, :NEW.nombre, :NEW.departamento, :NEW.salario, >> temp_master_triggers.sql
echo          :NEW.fecha_ingreso, :NEW.nodo_origen, :NEW.fecha_modificacion^); >> temp_master_triggers.sql
echo       EXCEPTION WHEN OTHERS THEN NULL; END; >> temp_master_triggers.sql
echo       BEGIN >> temp_master_triggers.sql
echo         INSERT INTO empleados@slave2_link VALUES >> temp_master_triggers.sql
echo         (:NEW.id, :NEW.nombre, :NEW.departamento, :NEW.salario, >> temp_master_triggers.sql
echo          :NEW.fecha_ingreso, :NEW.nodo_origen, :NEW.fecha_modificacion^); >> temp_master_triggers.sql
echo       EXCEPTION WHEN OTHERS THEN NULL; END; >> temp_master_triggers.sql
echo     ELSIF UPDATING THEN >> temp_master_triggers.sql
echo       BEGIN >> temp_master_triggers.sql
echo         UPDATE empleados@slave1_link SET >> temp_master_triggers.sql
echo           nombre = :NEW.nombre, departamento = :NEW.departamento, >> temp_master_triggers.sql
echo           salario = :NEW.salario, fecha_modificacion = :NEW.fecha_modificacion >> temp_master_triggers.sql
echo         WHERE id = :NEW.id; >> temp_master_triggers.sql
echo       EXCEPTION WHEN OTHERS THEN NULL; END; >> temp_master_triggers.sql
echo       BEGIN >> temp_master_triggers.sql
echo         UPDATE empleados@slave2_link SET >> temp_master_triggers.sql
echo           nombre = :NEW.nombre, departamento = :NEW.departamento, >> temp_master_triggers.sql
echo           salario = :NEW.salario, fecha_modificacion = :NEW.fecha_modificacion >> temp_master_triggers.sql
echo         WHERE id = :NEW.id; >> temp_master_triggers.sql
echo       EXCEPTION WHEN OTHERS THEN NULL; END; >> temp_master_triggers.sql
echo     ELSIF DELETING THEN >> temp_master_triggers.sql
echo       BEGIN >> temp_master_triggers.sql
echo         DELETE FROM empleados@slave1_link WHERE id = :OLD.id; >> temp_master_triggers.sql
echo       EXCEPTION WHEN OTHERS THEN NULL; END; >> temp_master_triggers.sql
echo       BEGIN >> temp_master_triggers.sql
echo         DELETE FROM empleados@slave2_link WHERE id = :OLD.id; >> temp_master_triggers.sql
echo       EXCEPTION WHEN OTHERS THEN NULL; END; >> temp_master_triggers.sql
echo     END IF; >> temp_master_triggers.sql
echo     COMMIT; >> temp_master_triggers.sql
echo   END; >> temp_master_triggers.sql
echo   / >> temp_master_triggers.sql
echo. >> temp_master_triggers.sql
echo CREATE OR REPLACE TRIGGER trg_productos_repl >> temp_master_triggers.sql
echo   AFTER INSERT OR UPDATE OR DELETE ON productos >> temp_master_triggers.sql
echo   FOR EACH ROW >> temp_master_triggers.sql
echo   DECLARE >> temp_master_triggers.sql
echo     PRAGMA AUTONOMOUS_TRANSACTION; >> temp_master_triggers.sql
echo   BEGIN >> temp_master_triggers.sql
echo     IF INSERTING THEN >> temp_master_triggers.sql
echo       BEGIN >> temp_master_triggers.sql
echo         INSERT INTO productos@slave1_link VALUES >> temp_master_triggers.sql
echo         (:NEW.producto_id, :NEW.nombre_producto, :NEW.precio, :NEW.stock, :NEW.categoria^); >> temp_master_triggers.sql
echo       EXCEPTION WHEN OTHERS THEN NULL; END; >> temp_master_triggers.sql
echo       BEGIN >> temp_master_triggers.sql
echo         INSERT INTO productos@slave2_link VALUES >> temp_master_triggers.sql
echo         (:NEW.producto_id, :NEW.nombre_producto, :NEW.precio, :NEW.stock, :NEW.categoria^); >> temp_master_triggers.sql
echo       EXCEPTION WHEN OTHERS THEN NULL; END; >> temp_master_triggers.sql
echo     ELSIF UPDATING THEN >> temp_master_triggers.sql
echo       BEGIN >> temp_master_triggers.sql
echo         UPDATE productos@slave1_link SET >> temp_master_triggers.sql
echo           nombre_producto = :NEW.nombre_producto, precio = :NEW.precio, >> temp_master_triggers.sql
echo           stock = :NEW.stock, categoria = :NEW.categoria >> temp_master_triggers.sql
echo         WHERE producto_id = :NEW.producto_id; >> temp_master_triggers.sql
echo       EXCEPTION WHEN OTHERS THEN NULL; END; >> temp_master_triggers.sql
echo       BEGIN >> temp_master_triggers.sql
echo         UPDATE productos@slave2_link SET >> temp_master_triggers.sql
echo           nombre_producto = :NEW.nombre_producto, precio = :NEW.precio, >> temp_master_triggers.sql
echo           stock = :NEW.stock, categoria = :NEW.categoria >> temp_master_triggers.sql
echo         WHERE producto_id = :NEW.producto_id; >> temp_master_triggers.sql
echo       EXCEPTION WHEN OTHERS THEN NULL; END; >> temp_master_triggers.sql
echo     ELSIF DELETING THEN >> temp_master_triggers.sql
echo       BEGIN >> temp_master_triggers.sql
echo         DELETE FROM productos@slave1_link WHERE producto_id = :OLD.producto_id; >> temp_master_triggers.sql
echo       EXCEPTION WHEN OTHERS THEN NULL; END; >> temp_master_triggers.sql
echo       BEGIN >> temp_master_triggers.sql
echo         DELETE FROM productos@slave2_link WHERE producto_id = :OLD.producto_id; >> temp_master_triggers.sql
echo       EXCEPTION WHEN OTHERS THEN NULL; END; >> temp_master_triggers.sql
echo     END IF; >> temp_master_triggers.sql
echo     COMMIT; >> temp_master_triggers.sql
echo   END; >> temp_master_triggers.sql
echo   / >> temp_master_triggers.sql
echo SELECT 'Triggers de replicacion creados en MASTER' FROM DUAL; >> temp_master_triggers.sql
echo EXIT; >> temp_master_triggers.sql

docker cp temp_master_triggers.sql oracle-master:/tmp/master_triggers.sql
docker exec oracle-master sqlplus maestro/maestro123@localhost:1521/FREEPDB1 @/tmp/master_triggers.sql

echo.
echo === SINCRONIZANDO DATOS EXISTENTES ===
echo Sincronizando datos desde MASTER hacia SLAVES...

REM Sincronizar datos existentes desde MASTER hacia SLAVES
echo INSERT INTO empleados@slave1_link SELECT * FROM empleados; > temp_sync_data.sql
echo INSERT INTO productos@slave1_link SELECT * FROM productos; >> temp_sync_data.sql
echo INSERT INTO empleados@slave2_link SELECT * FROM empleados; >> temp_sync_data.sql
echo INSERT INTO productos@slave2_link SELECT * FROM productos; >> temp_sync_data.sql
echo COMMIT; >> temp_sync_data.sql
echo SELECT 'Datos sincronizados desde MASTER' FROM DUAL; >> temp_sync_data.sql
echo EXIT; >> temp_sync_data.sql

docker cp temp_sync_data.sql oracle-master:/tmp/sync_data.sql
docker exec oracle-master sqlplus maestro/maestro123@localhost:1521/FREEPDB1 @/tmp/sync_data.sql

echo.
echo === VERIFICANDO CONFIGURACION ===
echo Verificando triggers y database links...

REM Verificar MASTER
echo SELECT 'MASTER - Triggers: ' ^|^| COUNT(*) FROM user_triggers WHERE status = 'ENABLED'; > temp_verify_master.sql
echo SELECT 'MASTER - Links: ' ^|^| COUNT(*) FROM user_db_links; >> temp_verify_master.sql
echo SELECT 'MASTER - Empleados: ' ^|^| COUNT(*) FROM empleados; >> temp_verify_master.sql
echo SELECT 'MASTER - Productos: ' ^|^| COUNT(*) FROM productos; >> temp_verify_master.sql
echo EXIT; >> temp_verify_master.sql

docker cp temp_verify_master.sql oracle-master:/tmp/verify_master.sql
docker exec oracle-master sqlplus -s maestro/maestro123@localhost:1521/FREEPDB1 @/tmp/verify_master.sql

REM Verificar SLAVE1
echo SELECT 'SLAVE1 - Empleados: ' ^|^| COUNT(*) FROM empleados; > temp_verify_slave1.sql
echo SELECT 'SLAVE1 - Productos: ' ^|^| COUNT(*) FROM productos; >> temp_verify_slave1.sql
echo EXIT; >> temp_verify_slave1.sql

docker cp temp_verify_slave1.sql oracle-slave1:/tmp/verify_slave1.sql
docker exec oracle-slave1 sqlplus -s maestro/maestro123@localhost:1521/FREEPDB1 @/tmp/verify_slave1.sql

REM Verificar SLAVE2
echo SELECT 'SLAVE2 - Empleados: ' ^|^| COUNT(*) FROM empleados; > temp_verify_slave2.sql
echo SELECT 'SLAVE2 - Productos: ' ^|^| COUNT(*) FROM productos; >> temp_verify_slave2.sql
echo EXIT; >> temp_verify_slave2.sql

docker cp temp_verify_slave2.sql oracle-slave2:/tmp/verify_slave2.sql
docker exec oracle-slave2 sqlplus -s maestro/maestro123@localhost:1521/FREEPDB1 @/tmp/verify_slave2.sql

echo.
echo === LIMPIANDO ARCHIVOS TEMPORALES ===
del temp_*.sql 2>nul

echo.
echo ========================================
echo REPLICACION MASTER-SLAVE CONFIGURADA
echo ========================================
echo.
echo ✓ Triggers de replicacion creados en MASTER
echo ✓ Database links configurados desde MASTER
echo ✓ Datos sincronizados inicialmente
echo ✓ Replicacion automatica desde MASTER a SLAVES
echo.
echo IMPORTANTE: Solo el MASTER replica hacia los SLAVES
echo Para failover, use el script de monitoreo automatico
echo que configurara la replicacion bidireccional segun sea necesario
echo ========================================

echo.
echo Presione cualquier tecla para continuar...
pause >nul
