REM filepath: c:\Users\mesia\Desktop\Universidad\BD Avanzada\P2\proyecto\oracle-replication\scripts\check_components.bat
echo.
echo ========================================
echo VERIFICANDO COMPONENTES DE REPLICACION
echo ========================================

echo.
echo === ESTADO DE CONTENEDORES ===
docker ps --filter name=oracle --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo.
echo === USUARIOS EXISTENTES ===
echo En MASTER:
echo ALTER SESSION SET CONTAINER = FREEPDB1; > check_users_master.sql
echo SELECT username, account_status FROM dba_users WHERE username IN ('MAESTRO'); >> check_users_master.sql
echo EXIT; >> check_users_master.sql
docker exec -i oracle-master sqlplus -S / as sysdba < check_users_master.sql

echo En SLAVE1:
echo ALTER SESSION SET CONTAINER = FREEPDB1; > check_users_slave1.sql
echo SELECT username, account_status FROM dba_users WHERE username IN ('ESCLAVO1', 'MAESTRO'); >> check_users_slave1.sql
echo EXIT; >> check_users_slave1.sql
docker exec -i oracle-slave1 sqlplus -S / as sysdba < check_users_slave1.sql

echo En SLAVE2:
echo ALTER SESSION SET CONTAINER = FREEPDB1; > check_users_slave2.sql
echo SELECT username, account_status FROM dba_users WHERE username IN ('ESCLAVO2', 'MAESTRO'); >> check_users_slave2.sql
echo EXIT; >> check_users_slave2.sql
docker exec -i oracle-slave2 sqlplus -S / as sysdba < check_users_slave2.sql

echo.
echo === TABLAS EXISTENTES ===
echo En MASTER (usuario maestro):
echo SELECT table_name FROM user_tables ORDER BY table_name; > check_tables_master.sql
echo EXIT; >> check_tables_master.sql
docker exec -i oracle-master sqlplus -S maestro/maestro123@localhost:1521/FREEPDB1 < check_tables_master.sql

echo En SLAVE1 (usuario maestro):
echo SELECT table_name FROM user_tables ORDER BY table_name; > check_tables_slave1.sql
echo EXIT; >> check_tables_slave1.sql
docker exec -i oracle-slave1 sqlplus -S maestro/maestro123@localhost:1521/FREEPDB1 < check_tables_slave1.sql

echo En SLAVE2 (usuario maestro):
echo SELECT table_name FROM user_tables ORDER BY table_name; > check_tables_slave2.sql
echo EXIT; >> check_tables_slave2.sql
docker exec -i oracle-slave2 sqlplus -S maestro/maestro123@localhost:1521/FREEPDB1 < check_tables_slave2.sql

echo.
echo === PERMISOS DE LECTURA EN SLAVES ===
echo SLAVE1 (esclavo1 puede ver):
echo SELECT table_name FROM all_tables WHERE owner = 'MAESTRO' ORDER BY table_name; > check_perms_slave1.sql
echo EXIT; >> check_perms_slave1.sql
docker exec -i oracle-slave1 sqlplus -S esclavo1/esclavo123@localhost:1521/FREEPDB1 < check_perms_slave1.sql

echo SLAVE2 (esclavo2 puede ver):
echo SELECT table_name FROM all_tables WHERE owner = 'MAESTRO' ORDER BY table_name; > check_perms_slave2.sql
echo EXIT; >> check_perms_slave2.sql
docker exec -i oracle-slave2 sqlplus -S esclavo2/esclavo123@localhost:1521/FREEPDB1 < check_perms_slave2.sql

echo.
echo === DATABASE LINKS ===
echo En MASTER (como SYS):
echo ALTER SESSION SET CONTAINER = FREEPDB1; > check_links.sql
echo SELECT db_link, host FROM dba_db_links WHERE owner = 'SYS'; >> check_links.sql
echo EXIT; >> check_links.sql
docker exec -i oracle-master sqlplus -S / as sysdba < check_links.sql

echo.
echo === TRIGGERS DE REPLICACION ===
echo En MASTER (como SYS):
echo ALTER SESSION SET CONTAINER = FREEPDB1; > check_triggers.sql
echo SELECT trigger_name, status, table_name FROM dba_triggers WHERE trigger_name LIKE '%EMPLEADOS%'; >> check_triggers.sql
echo EXIT; >> check_triggers.sql
docker exec -i oracle-master sqlplus -S / as sysdba < check_triggers.sql

echo.
echo === CONTEO DE REGISTROS ===
echo MASTER (maestro):
echo SELECT 'MASTER: ' ^|^| COUNT(*) as registros FROM empleados; > count_master.sql
echo EXIT; >> count_master.sql
docker exec -i oracle-master sqlplus -S maestro/maestro123@localhost:1521/FREEPDB1 < count_master.sql

echo SLAVE1 (esclavo1):
echo SELECT 'SLAVE1: ' ^|^| COUNT(*) as registros FROM maestro.empleados; > count_slave1.sql
echo EXIT; >> count_slave1.sql
docker exec -i oracle-slave1 sqlplus -S esclavo1/esclavo123@localhost:1521/FREEPDB1 < count_slave1.sql

echo SLAVE2 (esclavo2):
echo SELECT 'SLAVE2: ' ^|^| COUNT(*) as registros FROM maestro.empleados; > count_slave2.sql
echo EXIT; >> count_slave2.sql
docker exec -i oracle-slave2 sqlplus -S esclavo2/esclavo123@localhost:1521/FREEPDB1 < count_slave2.sql

echo.
echo === PRUEBA DE CONECTIVIDAD DE DATABASE LINKS ===
echo Probando conexiones desde MASTER:
echo ALTER SESSION SET CONTAINER = FREEPDB1; > test_links.sql
echo SELECT 'SLAVE1 Link:' FROM DUAL; >> test_links.sql
echo SELECT COUNT(*) as registros_via_link FROM maestro.empleados@slave1_link; >> test_links.sql
echo SELECT 'SLAVE2 Link:' FROM DUAL; >> test_links.sql
echo SELECT COUNT(*) as registros_via_link FROM maestro.empleados@slave2_link; >> test_links.sql
echo EXIT; >> test_links.sql
docker exec -i oracle-master sqlplus -S / as sysdba < test_links.sql

REM Limpiar archivos
del check_users_master.sql check_users_slave1.sql check_users_slave2.sql 2>nul
del check_tables_master.sql check_tables_slave1.sql check_tables_slave2.sql 2>nul
del check_perms_slave1.sql check_perms_slave2.sql check_links.sql check_triggers.sql 2>nul
del count_master.sql count_slave1.sql count_slave2.sql test_links.sql 2>nul

echo.
echo ========================================
echo VERIFICACION DE COMPONENTES COMPLETADA
echo ========================================
echo.
echo RESUMEN DE ARQUITECTURA:
echo ========================================
echo MASTER (puerto 1521):
echo + Usuario: maestro/maestro123 (Lectura/Escritura)
echo + Tablas: empleados, productos
echo + Database Links: slave1_link, slave2_link
echo + Triggers: Replicacion automatica
echo.
echo SLAVE1 (puerto 1522):
echo + Usuario maestro: Recibe replicacion
echo + Usuario esclavo1: Solo lectura
echo + Tablas: maestro.empleados, maestro.productos
echo.
echo SLAVE2 (puerto 1523):
echo + Usuario maestro: Recibe replicacion
echo + Usuario esclavo2: Solo lectura
echo + Tablas: maestro.empleados, maestro.productos
echo ========================================
pause
exit /b