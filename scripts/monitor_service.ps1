$ErrorActionPreference = "SilentlyContinue"
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$logFile = Join-Path $scriptPath "monitor.log"
$stateFile = Join-Path $scriptPath "system_state.txt"

function Write-MonitorLog {
    param($message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $message"
    Add-Content -Path $logFile -Value $logMessage
    Write-Host $logMessage
}

function Get-ContainerStatus {
    param($containerName)
    try {
        $status = docker inspect --format='{{.State.Status}}' $containerName 2>$null
        return $status
    } catch {
        return "not_found"
    }
}

function Test-OracleConnection {
    param($containerName, $user, $password)
    try {
        $tempFile = New-TemporaryFile
        "SELECT 1 FROM DUAL;" | Out-File -FilePath $tempFile.FullName -Encoding ASCII
        "EXIT;" | Out-File -FilePath $tempFile.FullName -Encoding ASCII -Append
        
        $result = docker exec $containerName sqlplus -S "$user/$password@localhost:1521/FREEPDB1" @$tempFile.FullName 2>$null
        Remove-Item $tempFile.FullName -Force -ErrorAction SilentlyContinue
        
        return $result -match "1"
    } catch {
        return $false
    }
}

function Perform-Failover {
    # Verificar si ya estamos en failover
    $currentState = Get-Content $stateFile -ErrorAction SilentlyContinue
    if ($currentState -eq "FAILOVER" -or $currentState -eq "SLAVE2_FAILOVER") {
        Write-MonitorLog "FAILOVER ya en progreso, saltando..."
        return
    }
    
    Write-MonitorLog "=== INICIANDO FAILOVER AUTOMATICO ==="
    
    # Verificar qué slaves están disponibles
    $slave1Status = Get-ContainerStatus "oracle-slave1"
    $slave2Status = Get-ContainerStatus "oracle-slave2"
    
    if ($slave1Status -eq "running") {
        # SLAVE1 disponible - Failover normal
        "FAILOVER" | Out-File -FilePath $stateFile -Encoding ASCII
        Write-MonitorLog "Promoviendo SLAVE1 a MASTER..."
        
        # Otorgar permisos de escritura a SLAVE1
        $tempSqlFile = New-TemporaryFile
        $promoteScript = @"
ALTER PLUGGABLE DATABASE FREEPDB1 OPEN;
ALTER SESSION SET CONTAINER = FREEPDB1;
-- Otorgar permisos básicos al usuario maestro
GRANT RESOURCE TO maestro;
GRANT CREATE TRIGGER TO maestro;
GRANT CREATE DATABASE LINK TO maestro;
GRANT UNLIMITED TABLESPACE TO maestro;
ALTER USER maestro QUOTA UNLIMITED ON USERS;
-- Otorgar permisos de escritura sobre las tablas del usuario maestro
GRANT INSERT, UPDATE, DELETE ON maestro.empleados TO maestro;
GRANT INSERT, UPDATE, DELETE ON maestro.productos TO maestro;
-- También otorgar permisos al usuario esclavo1 para que pueda actuar como maestro
GRANT INSERT, UPDATE, DELETE ON maestro.empleados TO esclavo1;
GRANT INSERT, UPDATE, DELETE ON maestro.productos TO esclavo1;
COMMIT;
-- Verificar permisos conectandose como maestro
CONNECT maestro/maestro123@localhost:1521/FREEPDB1;
-- Verificar que las tablas existen y se puede insertar
SELECT COUNT(*) FROM empleados;
SELECT COUNT(*) FROM productos;
-- Probar inserción para verificar permisos
INSERT INTO empleados (id, nombre, departamento, salario, nodo_origen)
VALUES (99999, 'TEST_FAILOVER', 'TEST', 1000, 'SLAVE1_PROMOTED');
COMMIT;
DELETE FROM empleados WHERE id = 99999;
COMMIT;
SELECT 'SLAVE1 promovido a MASTER - Permisos verificados y funcionales' FROM DUAL;
EXIT;
"@
        $promoteScript | Out-File -FilePath $tempSqlFile.FullName -Encoding ASCII
        docker cp $tempSqlFile.FullName oracle-slave1:/tmp/promote.sql
        docker exec oracle-slave1 sqlplus / as sysdba '@/tmp/promote.sql'
        Remove-Item $tempSqlFile.FullName -Force -ErrorAction SilentlyContinue
        
        # Ejecutar automáticamente la configuración de replicación bidireccional
        Write-MonitorLog "Configurando replicación bidireccional automáticamente..."
        $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
        $bidirectionalScript = Join-Path $scriptPath "smart_bidirectional_setup.bat"
        if (Test-Path $bidirectionalScript) {
            try {
                & cmd /c $bidirectionalScript
                Write-MonitorLog "Replicación bidireccional SLAVE1→SLAVE2 configurada automáticamente"
            } catch {
                Write-MonitorLog "Error configurando replicación bidireccional: $($_.Exception.Message)"
            }
        }
        
    } elseif ($slave2Status -eq "running") {
        # Solo SLAVE2 disponible - Failover de emergencia
        "SLAVE2_FAILOVER" | Out-File -FilePath $stateFile -Encoding ASCII
        Write-MonitorLog "EMERGENCIA: Solo SLAVE2 disponible - Promoviendo SLAVE2 a MASTER..."
        
        # Otorgar permisos de escritura a SLAVE2
        $tempSqlFile = New-TemporaryFile
        $promoteScript = @"
ALTER PLUGGABLE DATABASE FREEPDB1 OPEN;
ALTER SESSION SET CONTAINER = FREEPDB1;
-- Otorgar permisos básicos al usuario maestro
GRANT RESOURCE TO maestro;
GRANT CREATE TRIGGER TO maestro;
GRANT CREATE DATABASE LINK TO maestro;
GRANT UNLIMITED TABLESPACE TO maestro;
ALTER USER maestro QUOTA UNLIMITED ON USERS;
-- Otorgar permisos de escritura sobre las tablas del usuario maestro
GRANT INSERT, UPDATE, DELETE ON maestro.empleados TO maestro;
GRANT INSERT, UPDATE, DELETE ON maestro.productos TO maestro;
-- También otorgar permisos al usuario esclavo2 para que pueda actuar como maestro
GRANT INSERT, UPDATE, DELETE ON maestro.empleados TO esclavo2;
GRANT INSERT, UPDATE, DELETE ON maestro.productos TO esclavo2;
COMMIT;
-- Verificar permisos conectandose como maestro
CONNECT maestro/maestro123@localhost:1521/FREEPDB1;
-- Verificar que las tablas existen y se puede insertar
SELECT COUNT(*) FROM empleados;
SELECT COUNT(*) FROM productos;
-- Probar inserción para verificar permisos
INSERT INTO empleados (id, nombre, departamento, salario, nodo_origen)
VALUES (99998, 'TEST_FAILOVER_S2', 'TEST', 1000, 'SLAVE2_PROMOTED');
COMMIT;
DELETE FROM empleados WHERE id = 99998;
COMMIT;
SELECT 'SLAVE2 promovido a MASTER (EMERGENCIA) - Permisos verificados y funcionales' FROM DUAL;
EXIT;
"@
        $promoteScript | Out-File -FilePath $tempSqlFile.FullName -Encoding ASCII
        docker cp $tempSqlFile.FullName oracle-slave2:/tmp/promote.sql
        docker exec oracle-slave2 sqlplus / as sysdba '@/tmp/promote.sql'
        Remove-Item $tempSqlFile.FullName -Force -ErrorAction SilentlyContinue
        
    } else {
        Write-MonitorLog "ERROR CRITICO: Ningun SLAVE disponible para failover"
        return
    }
    
    Write-MonitorLog "=== FAILOVER COMPLETADO ==="
}

function Perform-Recovery {
    # Verificar si ya estamos en modo original
    $currentState = Get-Content $stateFile -ErrorAction SilentlyContinue
    if ($currentState -eq "ORIGINAL") {
        Write-MonitorLog "RECOVERY ya completado, saltando..."
        return
    }
    
    Write-MonitorLog "=== INICIANDO RECUPERACION AUTOMATICA ==="
    Write-MonitorLog "Estado actual: $currentState"
    
    # Cambiar estado inmediatamente para evitar ejecuciones múltiples
    "RECOVERING" | Out-File -FilePath $stateFile -Encoding ASCII
    
    # Determinar desde dónde sincronizar
    $syncContainer = "oracle-slave1"
    if ($currentState -eq "SLAVE2_FAILOVER") {
        $syncContainer = "oracle-slave2"
        Write-MonitorLog "Sincronizando desde SLAVE2 (failover de emergencia)"
    } else {
        Write-MonitorLog "Sincronizando desde SLAVE1 (failover normal)"
    }
    
    # Sincronizar datos desde el slave activo hacia MASTER
    Write-MonitorLog "Sincronizando datos desde $syncContainer hacia MASTER..."
    
    $tempSyncFile = New-TemporaryFile
    $syncSQL = @"
ALTER SESSION SET CONTAINER = FREEPDB1;
-- Eliminar enlace si existe
BEGIN
    EXECUTE IMMEDIATE 'DROP DATABASE LINK temp_sync_link';
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END;
/
-- Crear enlace temporal
CREATE DATABASE LINK temp_sync_link
CONNECT TO maestro IDENTIFIED BY maestro123
USING '${syncContainer}:1521/FREEPDB1';
-- Limpiar tablas
DELETE FROM empleados;
DELETE FROM productos;
-- Sincronizar datos
INSERT INTO empleados
SELECT * FROM empleados@temp_sync_link;
INSERT INTO productos
SELECT * FROM productos@temp_sync_link;
COMMIT;
-- Limpiar enlace
DROP DATABASE LINK temp_sync_link;
SELECT 'Datos sincronizados desde $syncContainer' FROM DUAL;
EXIT;
"@
    $syncSQL | Out-File -FilePath $tempSyncFile.FullName -Encoding ASCII
    
    docker cp $tempSyncFile.FullName oracle-master:/tmp/sync.sql
    docker exec oracle-master sqlplus / as sysdba '@/tmp/sync.sql'
    Remove-Item $tempSyncFile.FullName -Force -ErrorAction SilentlyContinue
    
    # Restaurar permisos originales en MASTER
    Write-MonitorLog "Restaurando permisos originales en MASTER..."
    
    $tempRestoreFile = New-TemporaryFile
    $restoreSQL = @"
ALTER SESSION SET CONTAINER = FREEPDB1;
-- Otorgar permisos completos al maestro sobre sus propias tablas
GRANT ALL PRIVILEGES ON maestro.empleados TO maestro;
GRANT ALL PRIVILEGES ON maestro.productos TO maestro;
-- Restaurar permisos de solo lectura para slaves
GRANT SELECT ON maestro.empleados TO esclavo1;
GRANT SELECT ON maestro.productos TO esclavo1;
GRANT SELECT ON maestro.empleados TO esclavo2;
GRANT SELECT ON maestro.productos TO esclavo2;
COMMIT;
SELECT 'Permisos restaurados en MASTER' FROM DUAL;
EXIT;
"@
    $restoreSQL | Out-File -FilePath $tempRestoreFile.FullName -Encoding ASCII
    
    docker cp $tempRestoreFile.FullName oracle-master:/tmp/restore.sql
    docker exec oracle-master sqlplus / as sysdba '@/tmp/restore.sql'
    Remove-Item $tempRestoreFile.FullName -Force -ErrorAction SilentlyContinue
    
    # Limpiar configuración de failover en los slaves
    Write-MonitorLog "Limpiando configuracion de failover en slaves..."
    
    $tempCleanupFile = New-TemporaryFile
    $cleanupSQL = @"
ALTER SESSION SET CONTAINER = FREEPDB1;
-- Revocar permisos básicos que se otorgaron
BEGIN
    EXECUTE IMMEDIATE 'REVOKE RESOURCE FROM maestro';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'REVOKE CREATE TRIGGER FROM maestro';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'REVOKE CREATE DATABASE LINK FROM maestro';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'REVOKE UNLIMITED TABLESPACE FROM maestro';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
-- Revocar permisos de escritura otorgados durante failover
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
SELECT 'Permisos de failover revocados completamente' FROM DUAL;
EXIT;
"@
    $cleanupSQL | Out-File -FilePath $tempCleanupFile.FullName -Encoding ASCII
    
    # Limpiar ambos slaves
    foreach ($slave in @("oracle-slave1", "oracle-slave2")) {
        docker cp $tempCleanupFile.FullName "${slave}:/tmp/cleanup.sql"
        docker exec $slave sqlplus / as sysdba '@/tmp/cleanup.sql' 2>$null
    }
    
    Remove-Item $tempCleanupFile.FullName -Force -ErrorAction SilentlyContinue
    
    # Actualizar estado
    "ORIGINAL" | Out-File -FilePath $stateFile -Encoding ASCII
    Write-MonitorLog "=== RECUPERACION COMPLETADA ==="
}

# Bucle principal de monitoreo
Write-MonitorLog "=== MONITOR AUTOMATICO INICIADO ==="
"ORIGINAL" | Out-File -FilePath $stateFile -Encoding ASCII

$lastMasterStatus = "running"
$lastSlave1Status = "running"
$lastSlave2Status = "running"

while ($true) {
    try {
        # Verificar estado de contenedores
        $masterStatus = Get-ContainerStatus "oracle-master"
        $slave1Status = Get-ContainerStatus "oracle-slave1"
        $slave2Status = Get-ContainerStatus "oracle-slave2"
        
        $currentState = Get-Content $stateFile -ErrorAction SilentlyContinue
        if (-not $currentState) { $currentState = "ORIGINAL" }
        
        # Lógica de failover automático
        if ($currentState -eq "ORIGINAL") {
            if ($masterStatus -ne "running" -and $lastMasterStatus -eq "running") {
                Write-MonitorLog "MASTER CAIDO - Iniciando failover automatico..."
                if ($slave1Status -eq "running" -or $slave2Status -eq "running") {
                    Perform-Failover
                } else {
                    Write-MonitorLog "ERROR CRITICO: Ningun SLAVE disponible para failover"
                }
            }
        }
        
        # Lógica de recuperación automática
        if ($currentState -eq "FAILOVER" -or $currentState -eq "SLAVE2_FAILOVER") {
            if ($masterStatus -eq "running" -and $lastMasterStatus -ne "running") {
                Write-MonitorLog "MASTER RECUPERADO - Iniciando recuperacion automatica..."
                Start-Sleep -Seconds 45  # Esperar a que Oracle inicie completamente
                
                # Verificar múltiples veces que Oracle esté listo
                $retries = 0
                $maxRetries = 12
                $oracleReady = $false
                
                while ($retries -lt $maxRetries -and -not $oracleReady) {
                    Write-MonitorLog "Verificando si Oracle esta listo... Intento $($retries + 1)/$maxRetries"
                    $oracleReady = Test-OracleConnection "oracle-master" "maestro" "maestro123"
                    if (-not $oracleReady) {
                        Start-Sleep -Seconds 15
                        $retries++
                    }
                }
                
                if ($oracleReady) {
                    Write-MonitorLog "Oracle esta listo - Iniciando sincronizacion..."
                    Perform-Recovery
                } else {
                    Write-MonitorLog "TIMEOUT: Oracle no esta listo despues de $($maxRetries * 15) segundos"
                }
            }
        }
        
        # Manejo de failover secundario (si SLAVE1 cae y solo queda SLAVE2)
        if ($currentState -eq "FAILOVER" -and $slave1Status -ne "running" -and $slave2Status -eq "running") {
            Write-MonitorLog "SLAVE1 CAIDO durante failover - Cambiando a SLAVE2_FAILOVER..."
            "SLAVE2_FAILOVER" | Out-File -FilePath $stateFile -Encoding ASCII
        }
        
        # Actualizar estados anteriores
        $lastMasterStatus = $masterStatus
        $lastSlave1Status = $slave1Status
        $lastSlave2Status = $slave2Status
        
        # Log de estado cada minuto
        $now = Get-Date
        if ($now.Second -eq 0) {
            Write-MonitorLog "Estado: $currentState | Master: $masterStatus | Slave1: $slave1Status | Slave2: $slave2Status"
        }
        
        Start-Sleep -Seconds 5
        
    } catch {
        Write-MonitorLog "ERROR en monitoreo: $($_.Exception.Message)"
        Start-Sleep -Seconds 30
    }
}
