-- Probar inserción en SLAVE1 con replicación automática a SLAVE2
SELECT 'Insertando datos de prueba en SLAVE1...' as info FROM DUAL;

-- Insertar empleado (las fechas se asignan automáticamente)
INSERT INTO maestro.empleados (id, nombre, departamento, salario, nodo_origen) 
VALUES (700, 'Test Replicacion', 'QA', 4000, 'SLAVE1_FAILOVER');

-- Insertar producto
INSERT INTO maestro.productos (producto_id, nombre_producto, precio, stock, categoria) 
VALUES (200, 'Mouse Inalambrico', 25, 50, 'Tecnología');

COMMIT;

SELECT 'Datos insertados en SLAVE1' as info FROM DUAL;

-- Verificar conteos después de la inserción
SELECT COUNT(*) as empleados_slave1 FROM maestro.empleados;
SELECT COUNT(*) as productos_slave1 FROM maestro.productos;

-- Verificar que se replicaron a SLAVE2 vía database link
SELECT COUNT(*) as empleados_slave2 FROM maestro.empleados@slave2_failover_link;
SELECT COUNT(*) as productos_slave2 FROM maestro.productos@slave2_failover_link;

-- Mostrar el último empleado insertado
SELECT 'Último empleado en SLAVE1:' as info FROM DUAL;
SELECT id, nombre, nodo_origen FROM maestro.empleados WHERE id = 700;

SELECT 'Último empleado en SLAVE2 via link:' as info FROM DUAL;
SELECT id, nombre, nodo_origen FROM maestro.empleados@slave2_failover_link WHERE id = 700;

-- Mostrar el último producto insertado
SELECT 'Último producto en SLAVE1:' as info FROM DUAL;
SELECT producto_id, nombre_producto FROM maestro.productos WHERE producto_id = 200;

SELECT 'Último producto en SLAVE2 via link:' as info FROM DUAL;
SELECT producto_id, nombre_producto FROM maestro.productos@slave2_failover_link WHERE producto_id = 200;

EXIT;
