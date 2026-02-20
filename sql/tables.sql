CREATE TABLE empleados (
  id NUMBER PRIMARY KEY,
  nombre VARCHAR2(100),
  departamento VARCHAR2(50),
  salario NUMBER(10,2),
  fecha_ingreso DATE DEFAULT SYSDATE,
  nodo_origen VARCHAR2(20),
  fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE productos (
  producto_id NUMBER PRIMARY KEY,
  nombre_producto VARCHAR2(100),
  precio NUMBER(10,2),
  stock NUMBER,
  categoria VARCHAR2(50)
);

SELECT 'Tablas creadas exitosamente' FROM DUAL;
EXIT;