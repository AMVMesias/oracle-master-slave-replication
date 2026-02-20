@echo off
REM filepath: c:\Users\mesia\Desktop\Universidad\BD Avanzada\P2\proyecto\oracle-replication\scripts\init_containers.bat
echo ========================================
echo INICIALIZACION DE CONTENEDORES ORACLE
echo ========================================

echo PASO 1: Limpiando entorno anterior...
docker stop oracle-master oracle-slave1 oracle-slave2 2>nul
docker rm oracle-master oracle-slave1 oracle-slave2 2>nul
docker network rm master-slave-network 2>nul

echo PASO 2: Creando red personalizada...
docker network create master-slave-network

echo PASO 3: Creando contenedores Oracle...
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

echo.
echo Estado de contenedores:
docker ps --filter name=oracle --format "table {{.Names}}\t{{.Status}}"

echo.
echo ========================================
echo CONTENEDORES INICIALIZADOS
echo ========================================
echo.
echo IMPORTANTE: Las bases de datos se estan inicializando...
echo Este proceso puede tomar 10-15 minutos.
echo.
echo Para continuar con la configuracion:
echo 1. Espera a que Oracle inicie completamente en todos los contenedores
echo 2. Ejecuta los pasos 1-5 del menu para configurar usuarios, tablas, etc.
echo 3. Inicia el monitor automatico (opcion 9)
echo.
echo ========================================
pause
