REM filepath: c:\Users\mesia\Desktop\Universidad\BD Avanzada\P2\proyecto\oracle-replication\scripts\setup.bat
echo ========================================================
echo ORACLE MASTER-SLAVE REPLICATION - SETUP COMPLETO
echo ========================================================

echo PASO 1: Limpiando entorno anterior y creando contenedores...
docker stop oracle-master oracle-slave1 oracle-slave2 2>nul
docker rm oracle-master oracle-slave1 oracle-slave2 2>nul
docker network rm master-slave-network 2>nul

echo Creando red personalizada...
docker network create master-slave-network

echo Creando Oracle MASTER (puerto 1521)...
docker run -d ^
  --name oracle-master ^
  --network master-slave-network ^
  -p 1521:1521 ^
  -e ORACLE_PASSWORD=MasterPass123 ^
  container-registry.oracle.com/database/free:latest

echo Creando Oracle SLAVE1 (puerto 1522)...
docker run -d ^
  --name oracle-slave1 ^
  --network master-slave-network ^
  -p 1522:1521 ^
  -e ORACLE_PASSWORD=SlavePass123 ^
  container-registry.oracle.com/database/free:latest

echo Creando Oracle SLAVE2 (puerto 1523)...
docker run -d ^
  --name oracle-slave2 ^
  --network master-slave-network ^
  -p 1523:1521 ^
  -e ORACLE_PASSWORD=SlavePass123 ^
  container-registry.oracle.com/database/free:latest

echo Contenedores creados. Estado actual:
docker ps --filter name=oracle

echo.
echo IMPORTANTE: Las bases de datos se estan inicializando...
echo Este proceso puede tomar 10-15 minutos.
echo.
choice /c S /m "Presiona S cuando estes listo para continuar con la configuracion automatica"

echo.
echo ========================================
echo CONFIGURACION AUTOMATICA COMPLETA
echo ========================================

echo PASO 2: Creando usuarios...
call scripts\create_users.bat

echo PASO 3: Creando tablas...
call scripts\create_tables.bat

echo PASO 4: Creando enlaces de base de datos...
call scripts\create_links.bat

echo PASO 5: Creando triggers de replicacion...
call scripts\create_triggers.bat

echo PASO 6: Insertando datos de prueba...
call scripts\insert_data.bat

echo.
echo ========================================
echo SETUP COMPLETO - SISTEMA LISTO!
echo ========================================
echo + MASTER: Lectura/Escritura (puerto 1521)
echo + SLAVE1: Solo Lectura (puerto 1522)
echo + SLAVE2: Solo Lectura (puerto 1523)
echo + Replicacion: Activa y funcionando
echo + Datos de prueba: Insertados
echo.
echo CREDENCIALES:
echo - MASTER: maestro/maestro123 (LECTURA/ESCRITURA)
echo - SLAVE1: esclavo1/esclavo123 (SOLO LECTURA)
echo - SLAVE2: esclavo2/esclavo123 (SOLO LECTURA)
echo.
echo Usa la opcion 7 para verificar replicacion
echo Usa la opcion 8 para ver componentes
echo Usa la opcion 9 para probar restricciones
echo ========================================
pause
exit /b