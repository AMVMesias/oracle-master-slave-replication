REM filepath: c:\Users\mesia\Desktop\Universidad\BD Avanzada\P2\proyecto\oracle-replication\scripts\create_links.bat
echo ========================================
echo Creando enlaces de base de datos...
echo ========================================

echo.
echo === ELIMINANDO ENLACES EXISTENTES ===
echo ALTER SESSION SET CONTAINER = FREEPDB1; > drop_links.sql
echo DROP DATABASE LINK slave1_link; >> drop_links.sql
echo DROP DATABASE LINK slave2_link; >> drop_links.sql
echo SELECT 'Enlaces eliminados' FROM DUAL; >> drop_links.sql
echo EXIT; >> drop_links.sql

echo Eliminando enlaces existentes...
docker exec -i oracle-master sqlplus / as sysdba < drop_links.sql 2>nul

echo.
echo === CREANDO ENLACES CORRECTOS ===
echo Creando enlaces desde MASTER usando SYS...

REM Crear archivo SQL para los enlaces
echo ALTER SESSION SET CONTAINER = FREEPDB1; > create_db_links.sql
echo -- Enlace a SLAVE1 usando usuario maestro >> create_db_links.sql
echo CREATE DATABASE LINK slave1_link >> create_db_links.sql
echo CONNECT TO maestro IDENTIFIED BY maestro123 >> create_db_links.sql
echo USING 'oracle-slave1:1521/FREEPDB1'; >> create_db_links.sql
echo. >> create_db_links.sql
echo -- Enlace a SLAVE2 usando usuario maestro >> create_db_links.sql
echo CREATE DATABASE LINK slave2_link >> create_db_links.sql
echo CONNECT TO maestro IDENTIFIED BY maestro123 >> create_db_links.sql
echo USING 'oracle-slave2:1521/FREEPDB1'; >> create_db_links.sql
echo. >> create_db_links.sql
echo -- Probar enlaces >> create_db_links.sql
echo SELECT 'Probando SLAVE1:' FROM DUAL; >> create_db_links.sql
echo SELECT SYSDATE FROM dual@slave1_link; >> create_db_links.sql
echo SELECT 'Probando SLAVE2:' FROM DUAL; >> create_db_links.sql
echo SELECT SYSDATE FROM dual@slave2_link; >> create_db_links.sql
echo. >> create_db_links.sql
echo SELECT 'Database links creados exitosamente' FROM DUAL; >> create_db_links.sql
echo EXIT; >> create_db_links.sql

docker exec -i oracle-master sqlplus / as sysdba < create_db_links.sql

del drop_links.sql create_db_links.sql 2>nul

echo.
echo ========================================
echo DATABASE LINKS CREADOS EXITOSAMENTE
echo + MASTER -> SLAVE1 (slave1_link con usuario maestro)
echo + MASTER -> SLAVE2 (slave2_link con usuario maestro)
echo ========================================
pause
exit /b