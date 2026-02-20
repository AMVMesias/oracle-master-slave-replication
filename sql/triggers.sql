-- CAMBIAR: link_slave1 → slave1_link
-- CAMBIAR: link_slave2 → slave2_link

CREATE OR REPLACE TRIGGER trg_empleados_repl 
AFTER INSERT OR UPDATE OR DELETE ON empleados 
FOR EACH ROW 
BEGIN 
  IF INSERTING THEN 
    BEGIN 
      INSERT INTO empleados@slave1_link VALUES 
      (:NEW.id, :NEW.nombre, :NEW.departamento, :NEW.salario, 
       :NEW.fecha_ingreso, :NEW.nodo_origen, :NEW.fecha_modificacion); 
    EXCEPTION WHEN OTHERS THEN NULL; END; 
    BEGIN 
      INSERT INTO empleados@slave2_link VALUES 
      (:NEW.id, :NEW.nombre, :NEW.departamento, :NEW.salario, 
       :NEW.fecha_ingreso, :NEW.nodo_origen, :NEW.fecha_modificacion); 
    EXCEPTION WHEN OTHERS THEN NULL; END; 
  ELSIF UPDATING THEN 
    UPDATE empleados@slave1_link SET 
      nombre = :NEW.nombre, salario = :NEW.salario, 
      departamento = :NEW.departamento,
      fecha_modificacion = :NEW.fecha_modificacion
    WHERE id = :NEW.id; 
    UPDATE empleados@slave2_link SET 
      nombre = :NEW.nombre, salario = :NEW.salario, 
      departamento = :NEW.departamento,
      fecha_modificacion = :NEW.fecha_modificacion
    WHERE id = :NEW.id; 
  ELSIF DELETING THEN 
    DELETE FROM empleados@slave1_link WHERE id = :OLD.id; 
    DELETE FROM empleados@slave2_link WHERE id = :OLD.id; 
  END IF; 
EXCEPTION WHEN OTHERS THEN 
  DBMS_OUTPUT.PUT_LINE('Error replicando empleados: ' || SQLERRM);
END; 
/

CREATE OR REPLACE TRIGGER trg_productos_repl 
AFTER INSERT OR UPDATE OR DELETE ON productos 
FOR EACH ROW 
BEGIN 
  IF INSERTING THEN 
    BEGIN
      INSERT INTO productos@slave1_link VALUES 
      (:NEW.producto_id, :NEW.nombre_producto, :NEW.precio, :NEW.stock, :NEW.categoria); 
    EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN
      INSERT INTO productos@slave2_link VALUES 
      (:NEW.producto_id, :NEW.nombre_producto, :NEW.precio, :NEW.stock, :NEW.categoria); 
    EXCEPTION WHEN OTHERS THEN NULL; END;
  ELSIF UPDATING THEN 
    UPDATE productos@slave1_link SET 
      nombre_producto = :NEW.nombre_producto, precio = :NEW.precio, 
      stock = :NEW.stock, categoria = :NEW.categoria 
    WHERE producto_id = :NEW.producto_id; 
    UPDATE productos@slave2_link SET 
      nombre_producto = :NEW.nombre_producto, precio = :NEW.precio, 
      stock = :NEW.stock, categoria = :NEW.categoria 
    WHERE producto_id = :NEW.producto_id; 
  ELSIF DELETING THEN 
    DELETE FROM productos@slave1_link WHERE producto_id = :OLD.producto_id; 
    DELETE FROM productos@slave2_link WHERE producto_id = :OLD.producto_id; 
  END IF; 
EXCEPTION WHEN OTHERS THEN 
  DBMS_OUTPUT.PUT_LINE('Error replicando productos: ' || SQLERRM);
END; 
/

SELECT 'Triggers de replicacion creados exitosamente' FROM DUAL;
EXIT;