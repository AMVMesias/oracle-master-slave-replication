echo ========================================
echo VERIFICACION FINAL VIA DATABASE LINKS
echo ========================================

echo SELECT 'EMPLEADOS SLAVE1 VIA LINK:', COUNT(*) FROM empleados@slave1_link; > temp_link_final.sql
echo SELECT 'PRODUCTOS SLAVE1 VIA LINK:', COUNT(*) FROM productos@slave1_link; >> temp_link_final.sql
echo SELECT 'EMPLEADOS SLAVE2 VIA LINK:', COUNT(*) FROM empleados@slave2_link; >> temp_link_final.sql
echo SELECT 'PRODUCTOS SLAVE2 VIA LINK:', COUNT(*) FROM productos@slave2_link; >> temp_link_final.sql
echo SELECT 'EMPLEADO ID 102 EN SLAVE1:', nombre FROM empleados@slave1_link WHERE id = 102; >> temp_link_final.sql
echo SELECT 'EMPLEADO ID 102 EN SLAVE2:', nombre FROM empleados@slave2_link WHERE id = 102; >> temp_link_final.sql
echo EXIT; >> temp_link_final.sql

docker cp temp_link_final.sql oracle-master:/tmp/link_final.sql
docker exec oracle-master sqlplus maestro/maestro123@localhost:1521/FREEPDB1 @/tmp/link_final.sql

del temp_link_final.sql 2>nul

echo.
echo ========================================
echo REPLICACION COMPLETAMENTE FUNCIONAL
echo ========================================
pause
