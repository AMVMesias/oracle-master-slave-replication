REM filepath: c:\Users\mesia\Desktop\Universidad\BD Avanzada\P2\proyecto\oracle-replication\scripts\insert_data.bat
@echo off
echo.
echo ========================================
echo INSERTANDO DATOS DE PRUEBA...
echo ========================================

REM Verificar estado del sistema
set "STATE_FILE=scripts\system_state.txt"
set "CURRENT_STATE=ORIGINAL"

if exist "%STATE_FILE%" (
    for /f "tokens=*" %%a in ('type "%STATE_FILE%" 2^>nul') do set "CURRENT_STATE=%%a"
)

if "%CURRENT_STATE%"=="FAILOVER" (
    echo.
    echo MODO FAILOVER DETECTADO
    echo Insertando datos en SLAVE1 (actuando como MASTER)...
    echo.
    
    REM Crear archivo SQL para insertar en SLAVE1
    echo INSERT INTO empleados (id, nombre, departamento, salario, nodo_origen) > insert_data_failover.sql
    echo VALUES (TRUNC(DBMS_RANDOM.VALUE(1000,9999)), 'Empleado Failover', 'Emergencia', 3000.00, 'SLAVE1'); >> insert_data_failover.sql
    echo INSERT INTO empleados (id, nombre, departamento, salario, nodo_origen) >> insert_data_failover.sql
    echo VALUES (TRUNC(DBMS_RANDOM.VALUE(1000,9999)), 'Admin Temporal', 'Sistemas', 5000.00, 'SLAVE1'); >> insert_data_failover.sql
    echo. >> insert_data_failover.sql
    echo INSERT INTO productos (producto_id, nombre_producto, precio, stock, categoria) >> insert_data_failover.sql
    echo VALUES (TRUNC(DBMS_RANDOM.VALUE(500,999)), 'Producto Failover', 99.99, 10, 'Emergencia'); >> insert_data_failover.sql
    echo:>> insert_data_failover.sql
    echo COMMIT; >> insert_data_failover.sql
    echo SELECT 'Datos insertados en SLAVE1 (modo FAILOVER)' FROM DUAL; >> insert_data_failover.sql
    echo EXIT; >> insert_data_failover.sql
    
    docker exec -i oracle-slave1 sqlplus esclavo1/esclavo123@localhost:1521/FREEPDB1 < insert_data_failover.sql
    del insert_data_failover.sql 2>nul
    
    echo.
    echo Datos insertados correctamente en SLAVE1
    echo Los datos se replicaran a SLAVE2 automaticamente
    
) else (
    echo.
    echo MODO NORMAL DETECTADO
    echo Insertando datos en MASTER...
    echo.
    
    REM Crear archivo SQL temporal con los datos
    echo INSERT INTO empleados (id, nombre, departamento, salario, nodo_origen) > insert_data_normal.sql
    echo VALUES (TRUNC(DBMS_RANDOM.VALUE(1,999)), 'Juan Perez', 'Sistemas', 5500.00, 'MASTER'); >> insert_data_normal.sql
    echo INSERT INTO empleados (id, nombre, departamento, salario, nodo_origen) >> insert_data_normal.sql
    echo VALUES (TRUNC(DBMS_RANDOM.VALUE(1,999)), 'Maria Garcia', 'Ventas', 4200.00, 'MASTER'); >> insert_data_normal.sql
    echo INSERT INTO empleados (id, nombre, departamento, salario, nodo_origen) >> insert_data_normal.sql
    echo VALUES (TRUNC(DBMS_RANDOM.VALUE(1,999)), 'Carlos Lopez', 'Marketing', 4800.00, 'MASTER'); >> insert_data_normal.sql
    echo:>> insert_data_normal.sql
    echo INSERT INTO productos (producto_id, nombre_producto, precio, stock, categoria) >> insert_data_normal.sql
    echo VALUES (TRUNC(DBMS_RANDOM.VALUE(100,499)), 'Laptop Dell', 1200.00, 50, 'Tecnologia'); >> insert_data_normal.sql
    echo INSERT INTO productos (producto_id, nombre_producto, precio, stock, categoria) >> insert_data_normal.sql
    echo VALUES (TRUNC(DBMS_RANDOM.VALUE(100,499)), 'Mouse Logitech', 25.99, 200, 'Accesorios'); >> insert_data_normal.sql
    echo:>> insert_data_normal.sql
    echo COMMIT; >> insert_data_normal.sql
    echo SELECT 'Datos insertados en MASTER' FROM DUAL; >> insert_data_normal.sql
    echo EXIT; >> insert_data_normal.sql
    
    docker exec -i oracle-master sqlplus maestro/maestro123@localhost:1521/FREEPDB1 < insert_data_normal.sql
    del insert_data_normal.sql 2>nul
    
    echo.
    echo Datos insertados correctamente en MASTER
    echo Los datos se replicaran a SLAVE1 y SLAVE2 automaticamente
)

REM Verificar replicacion después de insertar
echo.
echo ========================================
echo VERIFICANDO REPLICACION...
echo ========================================

REM Crear archivo SQL para verificar SLAVE1
echo SELECT 'EMPLEADOS EN SLAVE1:' FROM DUAL; > check_slave1.sql
echo SELECT id, nombre, departamento, salario, nodo_origen FROM maestro.empleados ORDER BY id; >> check_slave1.sql
echo SELECT 'PRODUCTOS EN SLAVE1:' FROM DUAL; >> check_slave1.sql
echo SELECT producto_id, nombre_producto, precio, stock, categoria FROM maestro.productos ORDER BY producto_id; >> check_slave1.sql
echo EXIT; >> check_slave1.sql

REM Crear archivo SQL para verificar SLAVE2
echo SELECT 'EMPLEADOS EN SLAVE2:' FROM DUAL; > check_slave2.sql
echo SELECT id, nombre, departamento, salario, nodo_origen FROM maestro.empleados ORDER BY id; >> check_slave2.sql
echo SELECT 'PRODUCTOS EN SLAVE2:' FROM DUAL; >> check_slave2.sql
echo SELECT producto_id, nombre_producto, precio, stock, categoria FROM maestro.productos ORDER BY producto_id; >> check_slave2.sql
echo EXIT; >> check_slave2.sql

echo.
echo Verificando replicacion en SLAVE1...
docker exec -i oracle-slave1 sqlplus -S esclavo1/esclavo123@localhost:1521/FREEPDB1 < check_slave1.sql

echo.
echo Verificando replicacion en SLAVE2...
docker exec -i oracle-slave2 sqlplus -S esclavo2/esclavo123@localhost:1521/FREEPDB1 < check_slave2.sql

REM Limpiar archivos temporales
del check_slave1.sql 2>nul
del check_slave2.sql 2>nul

echo.
echo ========================================
echo INSERCION COMPLETADA
echo ========================================