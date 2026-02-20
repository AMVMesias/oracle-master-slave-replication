-- Crear trigger para empleados
CREATE OR REPLACE TRIGGER trg_empleados_failover
  AFTER INSERT OR UPDATE OR DELETE ON maestro.empleados
  FOR EACH ROW
  DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    IF INSERTING THEN
      BEGIN
        INSERT INTO maestro.empleados@slave2_failover_link VALUES
        (:NEW.id, :NEW.nombre, :NEW.departamento, :NEW.salario,
         :NEW.fecha_ingreso, :NEW.nodo_origen, :NEW.fecha_modificacion);
      EXCEPTION WHEN OTHERS THEN NULL; END;
    ELSIF UPDATING THEN
      BEGIN
        UPDATE maestro.empleados@slave2_failover_link SET
          nombre = :NEW.nombre, departamento = :NEW.departamento,
          salario = :NEW.salario, fecha_modificacion = :NEW.fecha_modificacion
        WHERE id = :NEW.id;
      EXCEPTION WHEN OTHERS THEN NULL; END;
    ELSIF DELETING THEN
      BEGIN
        DELETE FROM maestro.empleados@slave2_failover_link WHERE id = :OLD.id;
      EXCEPTION WHEN OTHERS THEN NULL; END;
    END IF;
    COMMIT;
  END;
/

-- Crear trigger para productos
CREATE OR REPLACE TRIGGER trg_productos_failover
  AFTER INSERT OR UPDATE OR DELETE ON maestro.productos
  FOR EACH ROW
  DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    IF INSERTING THEN
      BEGIN
        INSERT INTO maestro.productos@slave2_failover_link VALUES
        (:NEW.producto_id, :NEW.nombre_producto, :NEW.precio, :NEW.stock, :NEW.categoria);
      EXCEPTION WHEN OTHERS THEN NULL; END;
    ELSIF UPDATING THEN
      BEGIN
        UPDATE maestro.productos@slave2_failover_link SET
          nombre_producto = :NEW.nombre_producto, precio = :NEW.precio,
          stock = :NEW.stock, categoria = :NEW.categoria
        WHERE producto_id = :NEW.producto_id;
      EXCEPTION WHEN OTHERS THEN NULL; END;
    ELSIF DELETING THEN
      BEGIN
        DELETE FROM maestro.productos@slave2_failover_link WHERE producto_id = :OLD.producto_id;
      EXCEPTION WHEN OTHERS THEN NULL; END;
    END IF;
    COMMIT;
  END;
/

-- Verificar que los triggers se crearon
SELECT 'Triggers de failover creados:' as info FROM DUAL;
SELECT trigger_name, status FROM user_triggers WHERE trigger_name LIKE '%FAILOVER%';

-- Sincronizar datos existentes
SELECT 'Sincronizando datos existentes...' as info FROM DUAL;

-- Insertar empleados que no están en SLAVE2
INSERT INTO maestro.empleados@slave2_failover_link
SELECT * FROM maestro.empleados e
WHERE NOT EXISTS (
  SELECT 1 FROM maestro.empleados@slave2_failover_link s 
  WHERE s.id = e.id
);

-- Insertar productos que no están en SLAVE2  
INSERT INTO maestro.productos@slave2_failover_link
SELECT * FROM maestro.productos p
WHERE NOT EXISTS (
  SELECT 1 FROM maestro.productos@slave2_failover_link s 
  WHERE s.producto_id = p.producto_id
);

COMMIT;

SELECT 'Sincronización completada' as info FROM DUAL;

-- Verificar conteos finales
SELECT COUNT(*) as empleados_slave1 FROM maestro.empleados;
SELECT COUNT(*) as empleados_slave2 FROM maestro.empleados@slave2_failover_link;
SELECT COUNT(*) as productos_slave1 FROM maestro.productos;  
SELECT COUNT(*) as productos_slave2 FROM maestro.productos@slave2_failover_link;

EXIT;
