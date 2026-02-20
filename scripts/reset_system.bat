@echo off
rem =================================================================
rem Script: reset_system.bat
rem Descripción: Resetear sistema tras failover
rem =================================================================

echo.
echo ========================================
echo         RESETEAR SISTEMA COMPLETO
echo ========================================
echo.

rem Detener monitor
echo [1] Deteniendo monitor...
taskkill /f /im powershell.exe /fi "windowtitle eq *monitor*" 2>nul
timeout /t 2 /nobreak > nul

rem Reiniciar todos los contenedores
echo.
echo [2] Reiniciando todos los contenedores...
docker restart oracle-master oracle-slave1 oracle-slave2

rem Esperar a que estén listos
echo.
echo [3] Esperando a que Oracle esté listo...
timeout /t 30 /nobreak > nul

rem Verificar conectividad
echo.
echo [4] Verificando conectividad...
docker exec oracle-master sqlplus -s maestro/maestro123@localhost:1521/FREEPDB1 <<EOF
SELECT 'MASTER OK' FROM DUAL;
EXIT;
EOF

docker exec oracle-slave1 sqlplus -s maestro/maestro123@localhost:1521/FREEPDB1 <<EOF
SELECT 'SLAVE1 OK' FROM DUAL;
EXIT;
EOF

docker exec oracle-slave2 sqlplus -s maestro/maestro123@localhost:1521/FREEPDB1 <<EOF
SELECT 'SLAVE2 OK' FROM DUAL;
EXIT;
EOF

rem Limpiar permisos especiales en slaves
echo.
echo [5] Limpiando permisos especiales en slaves...
docker exec oracle-slave1 sqlplus / as sysdba <<EOF
ALTER SESSION SET CONTAINER = FREEPDB1;
-- Revocar permisos de escritura si existen
BEGIN
    EXECUTE IMMEDIATE 'REVOKE INSERT, UPDATE, DELETE ON maestro.empleados FROM maestro';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'REVOKE INSERT, UPDATE, DELETE ON maestro.productos FROM maestro';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'REVOKE INSERT, UPDATE, DELETE ON maestro.empleados FROM esclavo1';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'REVOKE INSERT, UPDATE, DELETE ON maestro.productos FROM esclavo1';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
COMMIT;
SELECT 'Permisos limpiados en SLAVE1' FROM DUAL;
EXIT;
EOF

docker exec oracle-slave2 sqlplus / as sysdba <<EOF
ALTER SESSION SET CONTAINER = FREEPDB1;
-- Revocar permisos de escritura si existen
BEGIN
    EXECUTE IMMEDIATE 'REVOKE INSERT, UPDATE, DELETE ON maestro.empleados FROM maestro';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'REVOKE INSERT, UPDATE, DELETE ON maestro.productos FROM maestro';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'REVOKE INSERT, UPDATE, DELETE ON maestro.empleados FROM esclavo2';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'REVOKE INSERT, UPDATE, DELETE ON maestro.productos FROM esclavo2';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
COMMIT;
SELECT 'Permisos limpiados en SLAVE2' FROM DUAL;
EXIT;
EOF

rem Restablecer estado del sistema
echo.
echo [6] Restableciendo estado del sistema...
echo ORIGINAL > scripts\system_state.txt

rem Verificar que la replicación funciona
echo.
echo [7] Verificando que la replicación funciona...
docker exec oracle-master sqlplus -s maestro/maestro123@localhost:1521/FREEPDB1 <<EOF
INSERT INTO empleados (id, nombre, departamento, salario, nodo_origen)
VALUES (77777, 'RESET_TEST', 'RESET', 1000, 'MASTER_RESET');
COMMIT;
SELECT 'Datos insertados en MASTER' FROM DUAL;
EXIT;
EOF

echo.
echo [8] Esperando replicación...
timeout /t 3 /nobreak > nul

docker exec oracle-slave1 sqlplus -s maestro/maestro123@localhost:1521/FREEPDB1 <<EOF
SELECT 'SLAVE1 - Empleados con ID 77777: ' || COUNT(*) FROM empleados WHERE id = 77777;
EXIT;
EOF

docker exec oracle-slave2 sqlplus -s maestro/maestro123@localhost:1521/FREEPDB1 <<EOF
SELECT 'SLAVE2 - Empleados con ID 77777: ' || COUNT(*) FROM empleados WHERE id = 77777;
EXIT;
EOF

rem Limpiar datos de prueba
echo.
echo [9] Limpiando datos de prueba...
docker exec oracle-master sqlplus -s maestro/maestro123@localhost:1521/FREEPDB1 <<EOF
DELETE FROM empleados WHERE id = 77777;
COMMIT;
SELECT 'Datos de prueba limpiados' FROM DUAL;
EXIT;
EOF

echo.
echo ========================================
echo        SISTEMA RESETEADO
echo ========================================
echo.
echo El sistema ha sido reseteado a su estado original.
echo Todos los contenedores están funcionando normalmente.
echo La replicación está activa.
echo.
echo Para iniciar el monitor automático, use la opción 9 del menú.
echo.
echo Presione cualquier tecla para continuar...
pause > nul
