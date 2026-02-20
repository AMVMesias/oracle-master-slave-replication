INSERT INTO empleados (id, nombre, departamento, salario, nodo_origen) 
VALUES (1, 'Juan Perez', 'Sistemas', 5500.00, 'MASTER');

INSERT INTO empleados (id, nombre, departamento, salario, nodo_origen) 
VALUES (2, 'Maria Garcia', 'Ventas', 4200.00, 'MASTER');

INSERT INTO empleados (id, nombre, departamento, salario, nodo_origen) 
VALUES (3, 'Carlos Lopez', 'Marketing', 4800.00, 'MASTER');

INSERT INTO productos (producto_id, nombre_producto, precio, stock, categoria) 
VALUES (101, 'Laptop Dell', 1200.00, 50, 'Tecnologia');

INSERT INTO productos (producto_id, nombre_producto, precio, stock, categoria) 
VALUES (102, 'Mouse Logitech', 25.99, 200, 'Accesorios');

COMMIT;
SELECT 'Datos de prueba insertados desde MASTER' FROM DUAL;
EXIT;