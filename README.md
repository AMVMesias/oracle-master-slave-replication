<p align="center">
  <img src="https://img.shields.io/badge/Oracle-F80000?style=for-the-badge&logo=oracle&logoColor=white" alt="Oracle"/>
  <img src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker"/>
  <img src="https://img.shields.io/badge/PowerShell-5391FE?style=for-the-badge&logo=powershell&logoColor=white" alt="PowerShell"/>
  <img src="https://img.shields.io/badge/PL%2FSQL-F80000?style=for-the-badge&logo=oracle&logoColor=white" alt="PL/SQL"/>
</p>

# 🗄️ Replicación Oracle Master-Slave

Implementación completa de **replicación de Base de Datos Oracle** en topología Master-Slave usando contenedores Docker, triggers PL/SQL y scripts de failover automatizado.

## 📋 Descripción

Sistema de replicación que incluye:

- **1 Master** + **2 Slaves** Oracle ejecutándose en contenedores Docker
- **Replicación basada en triggers** que captura operaciones INSERT, UPDATE y DELETE
- **Database Links** conectando el master a las instancias slave
- **Failover automatizado** con recuperación y re-sincronización
- **Monitoreo continuo** con dashboard de estado

## 🏗️ Arquitectura

```
┌─────────────────────┐
│   ORACLE MASTER     │
│   (Puerto 1521)     │
│                     │
│  ┌───────────────┐  │       Database Links
│  │  Triggers     │──┼──────────────────────────┐
│  │  (DML Capture)│──┼───────────────┐          │
│  └───────────────┘  │               │          │
└─────────────────────┘               │          │
                                      ▼          ▼
                          ┌──────────────┐  ┌──────────────┐
                          │ ORACLE       │  │ ORACLE       │
                          │ SLAVE 1      │  │ SLAVE 2      │
                          │ (Puerto 1522)│  │ (Puerto 1523)│
                          └──────────────┘  └──────────────┘
```

## 🚀 Inicio Rápido

### Requisitos

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) instalado y en ejecución
- Windows con PowerShell
- ~12 GB RAM disponible (4 GB por contenedor Oracle)

### Configuración Automática

```bash
# Ejecutar el punto de entrada principal
main.bat

# Seleccionar opción A para configuración automática
# El sistema maneja todo:
#   ✓ Creación de contenedores
#   ✓ Configuración de usuarios y privilegios
#   ✓ Creación de Database Links
#   ✓ Creación de tablas y despliegue de triggers
#   ✓ Verificación de replicación
```

### Configuración Paso a Paso

```bash
# 1. Inicializar contenedores Docker
scripts/init_containers.bat

# 2. Crear usuarios de base de datos
scripts/create_users.bat

# 3. Configurar Database Links
scripts/create_links.bat

# 4. Crear tablas en todos los nodos
scripts/create_tables.bat

# 5. Desplegar triggers de replicación
scripts/create_triggers.bat

# 6. Insertar datos de prueba y verificar
scripts/insert_data.bat
scripts/verify.bat
```

## 📁 Estructura del Proyecto

```
oracle-master-slave-replication/
├── main.bat                          # 🎯 Punto de entrada (menú interactivo)
├── create_failover_triggers.sql      # Triggers de failover
├── test_replication.sql              # Consultas de prueba
│
├── sql/
│   ├── tables.sql                    # Esquema: empleados, productos
│   ├── triggers.sql                  # Triggers de replicación (PL/SQL)
│   └── test_data.sql                 # Datos de prueba
│
└── scripts/
    ├── setup.bat                     # Configuración inicial
    ├── init_containers.bat           # Crear contenedores Docker
    ├── create_users.bat              # Usuarios y privilegios
    ├── create_links.bat              # Database Links a slaves
    ├── create_tables.bat             # Creación de tablas
    ├── create_triggers.bat           # Despliegue de triggers
    ├── insert_data.bat               # Carga de datos de prueba
    │
    ├── verify.bat                    # Verificación completa
    ├── verify_replication.bat        # Verificación rápida
    ├── check_components.bat          # Chequeo de salud del sistema
    ├── system_status.bat             # Reporte detallado de estado
    │
    ├── demo_automatic.bat            # Demostración automatizada
    ├── setup_automatic_system.bat    # Setup automático completo
    │
    ├── failover_test.bat             # Pruebas de failover
    ├── setup_failover_triggers_robust.bat  # Triggers de failover robusto
    │
    ├── monitor_service.ps1           # Monitoreo continuo (PowerShell)
    ├── start_monitor.bat             # Iniciar monitoreo
    ├── stop_monitor.bat              # Detener monitoreo
    │
    ├── reset_system.bat              # Reset completo
    └── clean_system.bat              # Limpieza de recursos
```

## ⚙️ Cómo Funciona la Replicación

Cada tabla tiene un trigger `AFTER INSERT OR UPDATE OR DELETE` que:

1. **Captura** la operación DML en el master
2. **Reenvía** la misma operación vía Database Links a ambos slaves
3. **Maneja errores** — una falla en un slave no bloquea al master

```sql
CREATE OR REPLACE TRIGGER trg_empleados_repl
AFTER INSERT OR UPDATE OR DELETE ON empleados
FOR EACH ROW
BEGIN
  IF INSERTING THEN
    INSERT INTO empleados@slave1_link VALUES (:NEW.id, :NEW.nombre, ...);
    INSERT INTO empleados@slave2_link VALUES (:NEW.id, :NEW.nombre, ...);
  ELSIF UPDATING THEN
    UPDATE empleados@slave1_link SET nombre = :NEW.nombre ... WHERE id = :NEW.id;
    UPDATE empleados@slave2_link SET nombre = :NEW.nombre ... WHERE id = :NEW.id;
  ELSIF DELETING THEN
    DELETE FROM empleados@slave1_link WHERE id = :OLD.id;
    DELETE FROM empleados@slave2_link WHERE id = :OLD.id;
  END IF;
END;
```

### Failover y Recuperación

- **Detección**: Monitoreo continuo detecta fallas en slaves
- **Failover**: Triggers se reconfiguran para enrutar tráfico a slaves sanos
- **Recuperación**: Cuando un slave vuelve, los datos se re-sincronizan

## 🧪 Pruebas

```bash
# Prueba completa de replicación
scripts/verify.bat

# Probar escenarios de failover
scripts/failover_test.bat

# Monitorear replicación en tiempo real
scripts/start_monitor.bat
```

## 🛠️ Tecnologías

| Tecnología | Uso |
|---|---|
| **Oracle Database Free** | Motor de base de datos (imagen Docker) |
| **Docker** | Orquestación de contenedores |
| **PL/SQL** | Lógica de replicación con triggers |
| **Database Links** | Conectividad entre instancias |
| **Batch / PowerShell** | Scripts de automatización |

## 📝 Licencia

Este proyecto está bajo la Licencia MIT — ver el archivo [LICENSE](LICENSE) para más detalles.
