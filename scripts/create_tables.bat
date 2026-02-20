REM filepath: c:\Users\mesia\Desktop\Universidad\BD Avanzada\P2\proyecto\oracle-replication\scripts\create_tables.bat
echo ========================================
echo Creando tablas con estrategia simplificada...
echo ========================================

echo.
echo === ELIMINANDO TABLAS EXISTENTES (si existen) ===
echo DROP TABLE empleados CASCADE CONSTRAINTS; > drop_tables.sql
echo DROP TABLE productos CASCADE CONSTRAINTS; >> drop_tables.sql
echo SELECT 'Tablas eliminadas (si existian)' FROM DUAL; >> drop_tables.sql
echo EXIT; >> drop_tables.sql

echo Limpiando MASTER...
docker exec -i oracle-master sqlplus maestro/maestro123@localhost:1521/FREEPDB1 < drop_tables.sql 2>nul

echo.
echo === CREANDO TABLAS EN MASTER ===
echo Creando estructura de tablas desde MASTER...
docker exec -i oracle-master sqlplus maestro/maestro123@localhost:1521/FREEPDB1 < sql/tables.sql

echo.
echo === CREANDO USUARIO MAESTRO EN SLAVES ===
echo Creando usuario maestro en SLAVE1...
echo ALTER SESSION SET CONTAINER = FREEPDB1; > create_maestro_slave1.sql
echo CREATE USER maestro IDENTIFIED BY maestro123; >> create_maestro_slave1.sql
echo GRANT CONNECT, RESOURCE TO maestro; >> create_maestro_slave1.sql
echo ALTER USER maestro QUOTA UNLIMITED ON USERS; >> create_maestro_slave1.sql
echo SELECT 'Usuario maestro creado en SLAVE1' FROM DUAL; >> create_maestro_slave1.sql
echo EXIT; >> create_maestro_slave1.sql

docker exec -i oracle-slave1 sqlplus / as sysdba < create_maestro_slave1.sql 2>nul

echo Creando usuario maestro en SLAVE2...
echo ALTER SESSION SET CONTAINER = FREEPDB1; > create_maestro_slave2.sql
echo CREATE USER maestro IDENTIFIED BY maestro123; >> create_maestro_slave2.sql
echo GRANT CONNECT, RESOURCE TO maestro; >> create_maestro_slave2.sql
echo ALTER USER maestro QUOTA UNLIMITED ON USERS; >> create_maestro_slave2.sql
echo SELECT 'Usuario maestro creado en SLAVE2' FROM DUAL; >> create_maestro_slave2.sql
echo EXIT; >> create_maestro_slave2.sql

docker exec -i oracle-slave2 sqlplus / as sysdba < create_maestro_slave2.sql 2>nul

echo.
echo === CREANDO TABLAS EN SLAVES ===
echo Creando tablas en SLAVE1...
docker exec -i oracle-slave1 sqlplus maestro/maestro123@localhost:1521/FREEPDB1 < sql/tables.sql

echo Creando tablas en SLAVE2...
docker exec -i oracle-slave2 sqlplus maestro/maestro123@localhost:1521/FREEPDB1 < sql/tables.sql

echo.
echo === OTORGANDO PERMISOS DE LECTURA ===
echo GRANT SELECT ON maestro.empleados TO esclavo1; > grant_perms_slave1.sql
echo GRANT SELECT ON maestro.productos TO esclavo1; >> grant_perms_slave1.sql
echo SELECT 'Permisos otorgados a esclavo1' FROM DUAL; >> grant_perms_slave1.sql
echo EXIT; >> grant_perms_slave1.sql

echo GRANT SELECT ON maestro.empleados TO esclavo2; > grant_perms_slave2.sql
echo GRANT SELECT ON maestro.productos TO esclavo2; >> grant_perms_slave2.sql
echo SELECT 'Permisos otorgados a esclavo2' FROM DUAL; >> grant_perms_slave2.sql
echo EXIT; >> grant_perms_slave2.sql

docker exec -i oracle-slave1 sqlplus maestro/maestro123@localhost:1521/FREEPDB1 < grant_perms_slave1.sql
docker exec -i oracle-slave2 sqlplus maestro/maestro123@localhost:1521/FREEPDB1 < grant_perms_slave2.sql

REM Limpiar archivos temporales
del drop_tables.sql create_maestro_slave1.sql create_maestro_slave2.sql grant_perms_slave1.sql grant_perms_slave2.sql 2>nul

echo.
echo ========================================
echo TABLAS CREADAS EXITOSAMENTE:
echo + MASTER: maestro.empleados, maestro.productos
echo + SLAVE1: maestro.empleados, maestro.productos
echo + SLAVE2: maestro.empleados, maestro.productos
echo + PERMISOS: esclavo1/esclavo2 pueden leer
echo ========================================
pause
exit /b