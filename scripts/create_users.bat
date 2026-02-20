REM filepath: c:\Users\mesia\Desktop\Universidad\BD Avanzada\P2\proyecto\oracle-replication\scripts\create_users.bat
echo ========================================
echo Creando usuarios con permisos diferenciados...
echo ========================================

echo.
echo === CREANDO USUARIO MAESTRO (LECTURA/ESCRITURA) ===
echo ALTER PLUGGABLE DATABASE FREEPDB1 OPEN; > create_master_user.sql
echo ALTER SESSION SET CONTAINER = FREEPDB1; >> create_master_user.sql
echo CREATE USER maestro IDENTIFIED BY maestro123; >> create_master_user.sql
echo GRANT CONNECT, RESOURCE TO maestro; >> create_master_user.sql
echo GRANT CREATE DATABASE LINK TO maestro; >> create_master_user.sql
echo GRANT CREATE TRIGGER TO maestro; >> create_master_user.sql
echo GRANT UNLIMITED TABLESPACE TO maestro; >> create_master_user.sql
echo ALTER USER maestro QUOTA UNLIMITED ON USERS; >> create_master_user.sql
echo SELECT 'Usuario MAESTRO creado: LECTURA/ESCRITURA' FROM DUAL; >> create_master_user.sql
echo EXIT; >> create_master_user.sql

echo Creando usuario MASTER con permisos completos...
docker exec -i oracle-master sqlplus / as sysdba < create_master_user.sql 2>nul | findstr /v "ORA-65019"

echo.
echo === CREANDO USUARIO ESCLAVO1 (SOLO LECTURA) ===
echo ALTER PLUGGABLE DATABASE FREEPDB1 OPEN; > create_slave1_user.sql
echo ALTER SESSION SET CONTAINER = FREEPDB1; >> create_slave1_user.sql
echo CREATE USER esclavo1 IDENTIFIED BY esclavo123; >> create_slave1_user.sql
echo GRANT CONNECT TO esclavo1; >> create_slave1_user.sql
echo GRANT SELECT ANY TABLE TO esclavo1; >> create_slave1_user.sql
echo GRANT CREATE DATABASE LINK TO esclavo1; >> create_slave1_user.sql
echo -- NO SE OTORGA RESOURCE NI INSERT/UPDATE/DELETE >> create_slave1_user.sql
echo ALTER USER esclavo1 QUOTA 0 ON USERS; >> create_slave1_user.sql
echo SELECT 'Usuario ESCLAVO1 creado: SOLO LECTURA' FROM DUAL; >> create_slave1_user.sql
echo EXIT; >> create_slave1_user.sql

echo Creando usuario SLAVE1 con permisos de solo lectura...
docker exec -i oracle-slave1 sqlplus / as sysdba < create_slave1_user.sql 2>nul | findstr /v "ORA-65019"

echo.
echo === CREANDO USUARIO ESCLAVO2 (SOLO LECTURA) ===
echo ALTER PLUGGABLE DATABASE FREEPDB1 OPEN; > create_slave2_user.sql
echo ALTER SESSION SET CONTAINER = FREEPDB1; >> create_slave2_user.sql
echo CREATE USER esclavo2 IDENTIFIED BY esclavo123; >> create_slave2_user.sql
echo GRANT CONNECT TO esclavo2; >> create_slave2_user.sql
echo GRANT SELECT ANY TABLE TO esclavo2; >> create_slave2_user.sql
echo GRANT CREATE DATABASE LINK TO esclavo2; >> create_slave2_user.sql
echo -- NO SE OTORGA RESOURCE NI INSERT/UPDATE/DELETE >> create_slave2_user.sql
echo ALTER USER esclavo2 QUOTA 0 ON USERS; >> create_slave2_user.sql
echo SELECT 'Usuario ESCLAVO2 creado: SOLO LECTURA' FROM DUAL; >> create_slave2_user.sql
echo EXIT; >> create_slave2_user.sql

echo Creando usuario SLAVE2 con permisos de solo lectura...
docker exec -i oracle-slave2 sqlplus / as sysdba < create_slave2_user.sql 2>nul | findstr /v "ORA-65019"

REM Limpiar archivos temporales
del create_master_user.sql create_slave1_user.sql create_slave2_user.sql 2>nul

echo.
echo ========================================
echo USUARIOS CREADOS CON PERMISOS DIFERENCIADOS:
echo ========================================
echo + MAESTRO: LECTURA/ESCRITURA completa
echo + ESCLAVO1: SOLO LECTURA
echo + ESCLAVO2: SOLO LECTURA
echo ========================================
pause
exit /b