echo ========================================
echo Configurando triggers de failover robustos...
echo ========================================

echo.
echo === CONFIGURANDO TRIGGERS EN SLAVE1 PARA FAILOVER ===
echo Configurando SLAVE1 para detectar failover y replicar a SLAVE2...

echo.
echo --- Otorgando permisos en SLAVE1 ---
echo ALTER SESSION SET "_ORACLE_SCRIPT"=true; > temp_slave1_setup.sql
echo GRANT CREATE DATABASE LINK TO maestro; >> temp_slave1_setup.sql
echo GRANT CREATE TRIGGER TO maestro; >> temp_slave1_setup.sql
echo EXIT; >> temp_slave1_setup.sql

docker cp temp_slave1_setup.sql oracle-slave1:/tmp/slave1_setup.sql
docker exec oracle-slave1 sqlplus sys/Oradoc_db1@localhost:1521/FREEPDB1 AS SYSDBA @/tmp/slave1_setup.sql 2>nul

echo.
echo --- Creando database links en SLAVE1 ---
echo DROP DATABASE LINK slave2_failover_link; > temp_slave1_links.sql
echo DROP DATABASE LINK master_link; >> temp_slave1_links.sql
echo CREATE DATABASE LINK slave2_failover_link CONNECT TO maestro IDENTIFIED BY maestro123 USING 'oracle-slave2:1521/FREEPDB1'; >> temp_slave1_links.sql
echo CREATE DATABASE LINK master_link CONNECT TO maestro IDENTIFIED BY maestro123 USING 'oracle-master:1521/FREEPDB1'; >> temp_slave1_links.sql
echo SELECT 'Database links creados en SLAVE1' FROM dual; >> temp_slave1_links.sql
echo EXIT; >> temp_slave1_links.sql

docker cp temp_slave1_links.sql oracle-slave1:/tmp/slave1_links.sql
docker exec oracle-slave1 sqlplus maestro/maestro123@localhost:1521/FREEPDB1 @/tmp/slave1_links.sql

echo.
echo --- Eliminando triggers existentes en SLAVE1 ---
echo DROP TRIGGER trg_productos_failover; > temp_slave1_drop.sql
echo DROP TRIGGER trg_empleados_failover; >> temp_slave1_drop.sql
echo EXIT; >> temp_slave1_drop.sql

docker cp temp_slave1_drop.sql oracle-slave1:/tmp/slave1_drop.sql
docker exec oracle-slave1 sqlplus maestro/maestro123@localhost:1521/FREEPDB1 @/tmp/slave1_drop.sql 2>nul

echo.
echo --- Creando triggers de failover en SLAVE1 ---
echo CREATE OR REPLACE TRIGGER trg_productos_failover > temp_slave1_triggers.sql
echo AFTER INSERT OR UPDATE OR DELETE ON productos >> temp_slave1_triggers.sql
echo FOR EACH ROW >> temp_slave1_triggers.sql
echo WHEN (USER = 'MAESTRO'^) >> temp_slave1_triggers.sql
echo DECLARE >> temp_slave1_triggers.sql
echo   v_master_active NUMBER := 0; >> temp_slave1_triggers.sql
echo BEGIN >> temp_slave1_triggers.sql
echo   -- Verificar si MASTER esta activo >> temp_slave1_triggers.sql
echo   BEGIN >> temp_slave1_triggers.sql
echo     EXECUTE IMMEDIATE 'SELECT 1 FROM dual@master_link' INTO v_master_active; >> temp_slave1_triggers.sql
echo   EXCEPTION >> temp_slave1_triggers.sql
echo     WHEN OTHERS THEN >> temp_slave1_triggers.sql
echo       v_master_active := 0; >> temp_slave1_triggers.sql
echo   END; >> temp_slave1_triggers.sql
echo   -- Solo replicar si MASTER no esta activo >> temp_slave1_triggers.sql
echo   IF v_master_active = 0 THEN >> temp_slave1_triggers.sql
echo     IF INSERTING THEN >> temp_slave1_triggers.sql
echo       BEGIN >> temp_slave1_triggers.sql
echo         INSERT INTO productos@slave2_failover_link >> temp_slave1_triggers.sql
echo         VALUES (:NEW.producto_id, :NEW.nombre_producto, :NEW.precio, :NEW.stock, :NEW.categoria^); >> temp_slave1_triggers.sql
echo       EXCEPTION WHEN OTHERS THEN NULL; END; >> temp_slave1_triggers.sql
echo     ELSIF UPDATING THEN >> temp_slave1_triggers.sql
echo       BEGIN >> temp_slave1_triggers.sql
echo         UPDATE productos@slave2_failover_link SET >> temp_slave1_triggers.sql
echo           nombre_producto = :NEW.nombre_producto, >> temp_slave1_triggers.sql
echo           precio = :NEW.precio, >> temp_slave1_triggers.sql
echo           stock = :NEW.stock, >> temp_slave1_triggers.sql
echo           categoria = :NEW.categoria >> temp_slave1_triggers.sql
echo         WHERE producto_id = :NEW.producto_id; >> temp_slave1_triggers.sql
echo       EXCEPTION WHEN OTHERS THEN NULL; END; >> temp_slave1_triggers.sql
echo     ELSIF DELETING THEN >> temp_slave1_triggers.sql
echo       BEGIN >> temp_slave1_triggers.sql
echo         DELETE FROM productos@slave2_failover_link >> temp_slave1_triggers.sql
echo         WHERE producto_id = :OLD.producto_id; >> temp_slave1_triggers.sql
echo       EXCEPTION WHEN OTHERS THEN NULL; END; >> temp_slave1_triggers.sql
echo     END IF; >> temp_slave1_triggers.sql
echo   END IF; >> temp_slave1_triggers.sql
echo END; >> temp_slave1_triggers.sql
echo / >> temp_slave1_triggers.sql
echo. >> temp_slave1_triggers.sql

echo CREATE OR REPLACE TRIGGER trg_empleados_failover >> temp_slave1_triggers.sql
echo AFTER INSERT OR UPDATE OR DELETE ON empleados >> temp_slave1_triggers.sql
echo FOR EACH ROW >> temp_slave1_triggers.sql
echo WHEN (USER = 'MAESTRO'^) >> temp_slave1_triggers.sql
echo DECLARE >> temp_slave1_triggers.sql
echo   v_master_active NUMBER := 0; >> temp_slave1_triggers.sql
echo BEGIN >> temp_slave1_triggers.sql
echo   -- Verificar si MASTER esta activo >> temp_slave1_triggers.sql
echo   BEGIN >> temp_slave1_triggers.sql
echo     EXECUTE IMMEDIATE 'SELECT 1 FROM dual@master_link' INTO v_master_active; >> temp_slave1_triggers.sql
echo   EXCEPTION >> temp_slave1_triggers.sql
echo     WHEN OTHERS THEN >> temp_slave1_triggers.sql
echo       v_master_active := 0; >> temp_slave1_triggers.sql
echo   END; >> temp_slave1_triggers.sql
echo   -- Solo replicar si MASTER no esta activo >> temp_slave1_triggers.sql
echo   IF v_master_active = 0 THEN >> temp_slave1_triggers.sql
echo     IF INSERTING THEN >> temp_slave1_triggers.sql
echo       BEGIN >> temp_slave1_triggers.sql
echo         INSERT INTO empleados@slave2_failover_link >> temp_slave1_triggers.sql
echo         VALUES (:NEW.id, :NEW.nombre, :NEW.departamento, :NEW.salario, >> temp_slave1_triggers.sql
echo                 :NEW.fecha_ingreso, :NEW.nodo_origen, :NEW.fecha_modificacion^); >> temp_slave1_triggers.sql
echo       EXCEPTION WHEN OTHERS THEN NULL; END; >> temp_slave1_triggers.sql
echo     ELSIF UPDATING THEN >> temp_slave1_triggers.sql
echo       BEGIN >> temp_slave1_triggers.sql
echo         UPDATE empleados@slave2_failover_link SET >> temp_slave1_triggers.sql
echo           nombre = :NEW.nombre, >> temp_slave1_triggers.sql
echo           departamento = :NEW.departamento, >> temp_slave1_triggers.sql
echo           salario = :NEW.salario, >> temp_slave1_triggers.sql
echo           fecha_modificacion = :NEW.fecha_modificacion >> temp_slave1_triggers.sql
echo         WHERE id = :NEW.id; >> temp_slave1_triggers.sql
echo       EXCEPTION WHEN OTHERS THEN NULL; END; >> temp_slave1_triggers.sql
echo     ELSIF DELETING THEN >> temp_slave1_triggers.sql
echo       BEGIN >> temp_slave1_triggers.sql
echo         DELETE FROM empleados@slave2_failover_link >> temp_slave1_triggers.sql
echo         WHERE id = :OLD.id; >> temp_slave1_triggers.sql
echo       EXCEPTION WHEN OTHERS THEN NULL; END; >> temp_slave1_triggers.sql
echo     END IF; >> temp_slave1_triggers.sql
echo   END IF; >> temp_slave1_triggers.sql
echo END; >> temp_slave1_triggers.sql
echo / >> temp_slave1_triggers.sql
echo. >> temp_slave1_triggers.sql

echo SELECT 'Triggers de failover creados en SLAVE1' FROM dual; >> temp_slave1_triggers.sql
echo EXIT; >> temp_slave1_triggers.sql

docker cp temp_slave1_triggers.sql oracle-slave1:/tmp/slave1_triggers.sql
docker exec oracle-slave1 sqlplus maestro/maestro123@localhost:1521/FREEPDB1 @/tmp/slave1_triggers.sql

echo.
echo === CONFIGURANDO TRIGGERS EN SLAVE2 PARA FAILOVER ===
echo Configurando SLAVE2 para detectar failover y replicar a SLAVE1...

echo.
echo --- Otorgando permisos en SLAVE2 ---
echo ALTER SESSION SET "_ORACLE_SCRIPT"=true; > temp_slave2_setup.sql
echo GRANT CREATE DATABASE LINK TO maestro; >> temp_slave2_setup.sql
echo GRANT CREATE TRIGGER TO maestro; >> temp_slave2_setup.sql
echo EXIT; >> temp_slave2_setup.sql

docker cp temp_slave2_setup.sql oracle-slave2:/tmp/slave2_setup.sql
docker exec oracle-slave2 sqlplus sys/Oradoc_db1@localhost:1521/FREEPDB1 AS SYSDBA @/tmp/slave2_setup.sql 2>nul

echo.
echo --- Creando database links en SLAVE2 ---
echo DROP DATABASE LINK slave1_failover_link; > temp_slave2_links.sql
echo DROP DATABASE LINK master_link; >> temp_slave2_links.sql
echo CREATE DATABASE LINK slave1_failover_link CONNECT TO maestro IDENTIFIED BY maestro123 USING 'oracle-slave1:1521/FREEPDB1'; >> temp_slave2_links.sql
echo CREATE DATABASE LINK master_link CONNECT TO maestro IDENTIFIED BY maestro123 USING 'oracle-master:1521/FREEPDB1'; >> temp_slave2_links.sql
echo SELECT 'Database links creados en SLAVE2' FROM dual; >> temp_slave2_links.sql
echo EXIT; >> temp_slave2_links.sql

docker cp temp_slave2_links.sql oracle-slave2:/tmp/slave2_links.sql
docker exec oracle-slave2 sqlplus maestro/maestro123@localhost:1521/FREEPDB1 @/tmp/slave2_links.sql

echo.
echo --- Eliminando triggers existentes en SLAVE2 ---
echo DROP TRIGGER trg_productos_failover; > temp_slave2_drop.sql
echo DROP TRIGGER trg_empleados_failover; >> temp_slave2_drop.sql
echo EXIT; >> temp_slave2_drop.sql

docker cp temp_slave2_drop.sql oracle-slave2:/tmp/slave2_drop.sql
docker exec oracle-slave2 sqlplus maestro/maestro123@localhost:1521/FREEPDB1 @/tmp/slave2_drop.sql 2>nul

echo.
echo --- Creando triggers de failover en SLAVE2 ---
echo CREATE OR REPLACE TRIGGER trg_productos_failover > temp_slave2_triggers.sql
echo AFTER INSERT OR UPDATE OR DELETE ON productos >> temp_slave2_triggers.sql
echo FOR EACH ROW >> temp_slave2_triggers.sql
echo WHEN (USER = 'MAESTRO'^) >> temp_slave2_triggers.sql
echo DECLARE >> temp_slave2_triggers.sql
echo   v_master_active NUMBER := 0; >> temp_slave2_triggers.sql
echo BEGIN >> temp_slave2_triggers.sql
echo   -- Verificar si MASTER esta activo >> temp_slave2_triggers.sql
echo   BEGIN >> temp_slave2_triggers.sql
echo     EXECUTE IMMEDIATE 'SELECT 1 FROM dual@master_link' INTO v_master_active; >> temp_slave2_triggers.sql
echo   EXCEPTION >> temp_slave2_triggers.sql
echo     WHEN OTHERS THEN >> temp_slave2_triggers.sql
echo       v_master_active := 0; >> temp_slave2_triggers.sql
echo   END; >> temp_slave2_triggers.sql
echo   -- Solo replicar si MASTER no esta activo >> temp_slave2_triggers.sql
echo   IF v_master_active = 0 THEN >> temp_slave2_triggers.sql
echo     IF INSERTING THEN >> temp_slave2_triggers.sql
echo       BEGIN >> temp_slave2_triggers.sql
echo         INSERT INTO productos@slave1_failover_link >> temp_slave2_triggers.sql
echo         VALUES (:NEW.producto_id, :NEW.nombre_producto, :NEW.precio, :NEW.stock, :NEW.categoria^); >> temp_slave2_triggers.sql
echo       EXCEPTION WHEN OTHERS THEN NULL; END; >> temp_slave2_triggers.sql
echo     ELSIF UPDATING THEN >> temp_slave2_triggers.sql
echo       BEGIN >> temp_slave2_triggers.sql
echo         UPDATE productos@slave1_failover_link SET >> temp_slave2_triggers.sql
echo           nombre_producto = :NEW.nombre_producto, >> temp_slave2_triggers.sql
echo           precio = :NEW.precio, >> temp_slave2_triggers.sql
echo           stock = :NEW.stock, >> temp_slave2_triggers.sql
echo           categoria = :NEW.categoria >> temp_slave2_triggers.sql
echo         WHERE producto_id = :NEW.producto_id; >> temp_slave2_triggers.sql
echo       EXCEPTION WHEN OTHERS THEN NULL; END; >> temp_slave2_triggers.sql
echo     ELSIF DELETING THEN >> temp_slave2_triggers.sql
echo       BEGIN >> temp_slave2_triggers.sql
echo         DELETE FROM productos@slave1_failover_link >> temp_slave2_triggers.sql
echo         WHERE producto_id = :OLD.producto_id; >> temp_slave2_triggers.sql
echo       EXCEPTION WHEN OTHERS THEN NULL; END; >> temp_slave2_triggers.sql
echo     END IF; >> temp_slave2_triggers.sql
echo   END IF; >> temp_slave2_triggers.sql
echo END; >> temp_slave2_triggers.sql
echo / >> temp_slave2_triggers.sql
echo. >> temp_slave2_triggers.sql

echo SELECT 'Triggers de failover creados en SLAVE2' FROM dual; >> temp_slave2_triggers.sql
echo EXIT; >> temp_slave2_triggers.sql

docker cp temp_slave2_triggers.sql oracle-slave2:/tmp/slave2_triggers.sql
docker exec oracle-slave2 sqlplus maestro/maestro123@localhost:1521/FREEPDB1 @/tmp/slave2_triggers.sql

echo.
echo === VERIFICANDO CONFIGURACION ===
echo Verificando que los triggers se hayan creado correctamente...

echo.
echo --- Triggers en SLAVE1 ---
echo SELECT trigger_name, status FROM user_triggers WHERE trigger_name LIKE '%FAILOVER%'; > temp_verify.sql
echo EXIT; >> temp_verify.sql

docker cp temp_verify.sql oracle-slave1:/tmp/verify.sql
docker exec oracle-slave1 sqlplus maestro/maestro123@localhost:1521/FREEPDB1 @/tmp/verify.sql

echo.
echo --- Triggers en SLAVE2 ---
docker cp temp_verify.sql oracle-slave2:/tmp/verify.sql
docker exec oracle-slave2 sqlplus maestro/maestro123@localhost:1521/FREEPDB1 @/tmp/verify.sql

echo.
echo === LIMPIANDO ARCHIVOS TEMPORALES ===
del temp_slave1_setup.sql 2>nul
del temp_slave1_links.sql 2>nul
del temp_slave1_drop.sql 2>nul
del temp_slave1_triggers.sql 2>nul
del temp_slave2_setup.sql 2>nul
del temp_slave2_links.sql 2>nul
del temp_slave2_drop.sql 2>nul
del temp_slave2_triggers.sql 2>nul
del temp_verify.sql 2>nul

echo.
echo ========================================
echo CONFIGURACION DE TRIGGERS DE FAILOVER COMPLETADA
echo.
echo Configuracion aplicada:
echo + SLAVE1: Triggers para replicar a SLAVE2 durante failover
echo + SLAVE2: Triggers para replicar a SLAVE1 durante failover
echo + Deteccion automatica de estado del MASTER
echo + Manejo robusto de errores
echo ========================================
pause
