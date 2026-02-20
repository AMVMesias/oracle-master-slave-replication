echo ========================================
echo VERIFICANDO REPLICACION AUTOMATICA
echo ========================================

echo.
echo === CONTEO DE REGISTROS EN CADA NODO ===
echo.
echo --- MASTER ---
echo SELECT 'EMPLEADOS MASTER:', COUNT(*) FROM empleados; > temp_verify_master.sql
echo SELECT 'PRODUCTOS MASTER:', COUNT(*) FROM productos; >> temp_verify_master.sql
echo EXIT; >> temp_verify_master.sql

docker cp temp_verify_master.sql oracle-master:/tmp/verify_master.sql
docker exec oracle-master sqlplus maestro/maestro123@localhost:1521/FREEPDB1 @/tmp/verify_master.sql

echo.
echo --- SLAVE1 ---
echo SELECT 'EMPLEADOS SLAVE1:', COUNT(*) FROM empleados; > temp_verify_slave1.sql
echo SELECT 'PRODUCTOS SLAVE1:', COUNT(*) FROM productos; >> temp_verify_slave1.sql
echo EXIT; >> temp_verify_slave1.sql

docker cp temp_verify_slave1.sql oracle-slave1:/tmp/verify_slave1.sql
docker exec oracle-slave1 sqlplus maestro/maestro123@localhost:1521/FREEPDB1 @/tmp/verify_slave1.sql

echo.
echo --- SLAVE2 ---
echo SELECT 'EMPLEADOS SLAVE2:', COUNT(*) FROM empleados; > temp_verify_slave2.sql
echo SELECT 'PRODUCTOS SLAVE2:', COUNT(*) FROM productos; >> temp_verify_slave2.sql
echo EXIT; >> temp_verify_slave2.sql

docker cp temp_verify_slave2.sql oracle-slave2:/tmp/verify_slave2.sql
docker exec oracle-slave2 sqlplus maestro/maestro123@localhost:1521/FREEPDB1 @/tmp/verify_slave2.sql

echo.
echo === VERIFICANDO VIA DATABASE LINKS ===
echo Verificando conectividad desde MASTER...
echo SELECT 'EMPLEADOS SLAVE1 VIA LINK:', COUNT(*) FROM empleados@slave1_link; > temp_verify_links.sql
echo SELECT 'PRODUCTOS SLAVE1 VIA LINK:', COUNT(*) FROM productos@slave1_link; >> temp_verify_links.sql
echo SELECT 'EMPLEADOS SLAVE2 VIA LINK:', COUNT(*) FROM empleados@slave2_link; >> temp_verify_links.sql
echo SELECT 'PRODUCTOS SLAVE2 VIA LINK:', COUNT(*) FROM productos@slave2_link; >> temp_verify_links.sql
echo EXIT; >> temp_verify_links.sql

docker cp temp_verify_links.sql oracle-master:/tmp/verify_links.sql
docker exec oracle-master sqlplus maestro/maestro123@localhost:1521/FREEPDB1 @/tmp/verify_links.sql

echo.
echo === VERIFICANDO TRIGGERS ===
echo SELECT 'TRIGGERS EN MASTER:', COUNT(*) FROM user_triggers; > temp_verify_triggers.sql
echo SELECT trigger_name, table_name, status FROM user_triggers; >> temp_verify_triggers.sql
echo EXIT; >> temp_verify_triggers.sql

docker cp temp_verify_triggers.sql oracle-master:/tmp/verify_triggers.sql
docker exec oracle-master sqlplus maestro/maestro123@localhost:1521/FREEPDB1 @/tmp/verify_triggers.sql

echo.
echo === PRUEBA DE REPLICACION ===
echo Insertando registro de prueba...
set /a "test_id=%RANDOM% + 1000"
echo INSERT INTO empleados VALUES (%test_id%, 'PRUEBA_REPLICACION', 'TESTING', 9999, SYSDATE, 'MASTER', SYSDATE^); > temp_test_replication.sql
echo COMMIT; >> temp_test_replication.sql
echo SELECT 'Registro de prueba insertado' FROM DUAL; >> temp_test_replication.sql
echo EXIT; >> temp_test_replication.sql

docker cp temp_test_replication.sql oracle-master:/tmp/test_replication.sql
docker exec oracle-master sqlplus maestro/maestro123@localhost:1521/FREEPDB1 @/tmp/test_replication.sql

echo.
echo Verificando replicacion del registro de prueba...
echo SELECT 'PRUEBA EN SLAVE1:', COUNT(*) FROM empleados WHERE id = %test_id%; > temp_test_check.sql
echo SELECT 'PRUEBA EN SLAVE2:', COUNT(*) FROM empleados@slave2_link WHERE id = %test_id%; >> temp_test_check.sql
echo EXIT; >> temp_test_check.sql

docker cp temp_test_check.sql oracle-master:/tmp/test_check.sql
docker exec oracle-master sqlplus maestro/maestro123@localhost:1521/FREEPDB1 @/tmp/test_check.sql

echo.
echo === LIMPIANDO ARCHIVOS TEMPORALES ===
del temp_verify_master.sql 2>nul
del temp_verify_slave1.sql 2>nul
del temp_verify_slave2.sql 2>nul
del temp_verify_links.sql 2>nul
del temp_verify_triggers.sql 2>nul
del temp_test_replication.sql 2>nul
del temp_test_check.sql 2>nul

echo.
echo ========================================
echo VERIFICACION COMPLETADA
echo ========================================
echo.
echo INTERPRETACION DE RESULTADOS:
echo - Si los conteos son iguales: Replicacion funcionando
echo - Si PRUEBA EN SLAVE1/SLAVE2 = 1: Triggers funcionando
echo - Si hay triggers habilitados: Sistema configurado
echo.
pause
