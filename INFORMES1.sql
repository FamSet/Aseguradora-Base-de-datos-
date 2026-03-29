/*
Autores:
  Aranda Marron Fernando 
  Chacon Jaral Hugo Emanuel
  Gutierrez Nolasco Emiliano 
Descripción: Informes sql (estadisticas)
Fecha: 30/11/2025
El presente script contiene un conjunto de consultas SQL 
diseñadas para generar informes estadísticos clave dentro
de la base de datos ASEGURADORA. Estas consultas permiten 
analizar información relevante sobre pólizas, clientes, corredores, 
siniestros y tipos de seguro. Los reportes incluyen métricas 
como pólizas activas, primas generadas, cotizaciones, siniestros, 
renovaciones y otros indicadores operativos.

El objetivo principal es proporcionar una visión completa 
y actualizada del comportamiento de la aseguradora, facilitando 
la toma de decisiones y el monitoreo del desempeño comercial
y operativo.


*/


use ASEGURADORA06
go

-- ESTADISTICAS y/o INFORMES 1-7
SELECT 
    co.ID_CORREDOR,
    co.NOMBRE 
        + ' ' + co.APELLIDOPAT
        + ISNULL(' ' + co.APELLIDOMAT, '') AS NombreCorredor,
    cl.ID_CLIENTE,
    cl.NOMBRE 
        + ' ' + cl.APELLIDO_P
        + ISNULL(' ' + cl.APELLIDO_M, '') AS NombreCliente,
    p.NUM_POLIZA,
    p.FECHA_FIN
FROM Operaciones.POLIZA p
JOIN Personas.CLIENTE cl
    ON p.ID_CLIENTE = cl.ID_CLIENTE
JOIN Personas.CORREDOR co
    ON p.ID_CORREDOR = co.ID_CORREDOR
WHERE p.ESTADO_POLIZA = 'ACTIVA'
ORDER BY co.ID_CORREDOR, p.NUM_POLIZA;

--2
SELECT 
    co.ID_CORREDOR,
    co.NOMBRE 
        + ' ' + co.APELLIDOPAT
        + ISNULL(' ' + co.APELLIDOMAT, '') AS NombreCorredor,
    SUM(p.MONTO_PRIMA_TOT) AS TotalPrimasTrimestre
FROM Operaciones.POLIZA p
JOIN Personas.CORREDOR co
    ON p.ID_CORREDOR = co.ID_CORREDOR
WHERE p.FECHA_INICIO >= DATEADD(MONTH, -3, CAST(GETDATE() AS DATE))
GROUP BY 
    co.ID_CORREDOR,
    co.NOMBRE,
    co.APELLIDOPAT,
    co.APELLIDOMAT
ORDER BY TotalPrimasTrimestre DESC;

--3
SELECT 
    ts.NOMBRE AS TipoSeguro,
    COUNT(cot.NUM_COTIZACION) AS CotizacionesPendientes
FROM Operaciones.COTIZACION cot
JOIN Seguros.TIPO_SEGURO ts
    ON ts.NUM_COTIZACION = cot.NUM_COTIZACION
WHERE cot.FECHA_COTIZ >= DATEADD(DAY, -60, CAST(GETDATE() AS DATE))
  AND cot.ESTADO IN ('PENDIENTE', 'ABIERTA')
GROUP BY ts.NOMBRE
ORDER BY CotizacionesPendientes DESC;


--4
SELECT 
    cl.ID_CLIENTE,
    cl.NOMBRE 
        + ' ' + cl.APELLIDO_P
        + ISNULL(' ' + cl.APELLIDO_M, '') AS NombreCliente
FROM Personas.CLIENTE cl
JOIN Operaciones.POLIZA p
    ON cl.ID_CLIENTE = p.ID_CLIENTE
WHERE p.CLAVE_SEGURO IN ('100', '200')   -- 100 = Vida, 200 = Retiro
GROUP BY 
    cl.ID_CLIENTE,
    cl.NOMBRE,
    cl.APELLIDO_P,
    cl.APELLIDO_M
HAVING COUNT(DISTINCT p.CLAVE_SEGURO) = 2;

--5
SELECT 
    p.NUM_POLIZA,
    p.SALDO_PENDIENTE,
    p.FECHA_FIN AS FechaVencimiento
FROM Operaciones.POLIZA p
WHERE p.SALDO_PENDIENTE > 0
ORDER BY p.FECHA_FIN, p.NUM_POLIZA;

--6

SELECT 
    ts.NOMBRE AS TipoSeguro,
    AVG(s.MONTO_INDEMNIZ) AS IndemnizacionPromedio,
    COUNT(*) AS TotalSiniestros
FROM Operaciones.SINIESTRO s
JOIN Operaciones.POLIZA p
    ON s.NUM_POLIZA = p.NUM_POLIZA
JOIN Seguros.TIPO_SEGURO ts
    ON p.CLAVE_SEGURO = ts.CLAVE_SEGURO
WHERE MONTH(s.FECHA_HORA) = MONTH(DATEADD(MONTH, -1, GETDATE()))
  AND YEAR(s.FECHA_HORA)  = YEAR(DATEADD(MONTH, -1, GETDATE()))
GROUP BY ts.NOMBRE;

--7
SELECT 
    v.MARCA,
    v.MODELO,
    COUNT(*) AS VehiculosAsegurados
FROM Seguros.VEHICULO v
GROUP BY v.MARCA, v.MODELO
ORDER BY v.MARCA, v.MODELO;

--ESTADISTICAS 1-10

SELECT COUNT(DISTINCT C.ID_CLIENTE) AS ClientesActivos
FROM Personas.CLIENTE C
JOIN Operaciones.POLIZA P
    ON C.ID_CLIENTE = P.ID_CLIENTE
WHERE P.ESTADO_POLIZA = 'ACTIVA';

SELECT TS.NOMBRE,
       COUNT(*) AS PolizasActivas
FROM Operaciones.POLIZA P
JOIN Seguros.TIPO_SEGURO TS
    ON P.CLAVE_SEGURO = TS.CLAVE_SEGURO
WHERE P.ESTADO_POLIZA = 'ACTIVA'
GROUP BY TS.NOMBRE;

SELECT TS.NOMBRE,
       AVG(P.MONTO_PRIMA_TOT) AS PromedioMontoAsegurado
FROM Operaciones.POLIZA P
JOIN Seguros.TIPO_SEGURO TS
       ON P.CLAVE_SEGURO = TS.CLAVE_SEGURO
GROUP BY TS.NOMBRE;
--4
SELECT SUM(MONTO_PRIMA_TOT) AS IngresosUltimoMes
FROM Operaciones.POLIZA
WHERE FECHA_INICIO >= DATEADD(MONTH, -1, GETDATE());

SELECT CAUSA,
       COUNT(*) AS TotalSiniestros
FROM Operaciones.SINIESTRO
WHERE FECHA_HORA >= DATEADD(YEAR, -1, GETDATE())
GROUP BY CAUSA;

SELECT CP.CIUDAD,
       COUNT(C.ID_CLIENTE) AS TotalClientes
FROM Personas.CLIENTE C
JOIN Personas.DIRECCIONCP CP
     ON C.ID_CLIENTE = CP.ID_CLIENTE
GROUP BY CP.CIUDAD
ORDER BY TotalClientes DESC;

SELECT TOP 5 
       CO.NOMBRE
       + ' ' + CO.APELLIDOPAT
       + CASE 
            WHEN CO.APELLIDOMAT IS NULL THEN '' 
            ELSE ' ' + CO.APELLIDOMAT 
         END AS Corredor,
       SUM(P.MONTO_PRIMA_TOT) AS TotalPrimaVendida
FROM Operaciones.POLIZA P
JOIN Personas.CORREDOR CO
     ON P.ID_CORREDOR = CO.ID_CORREDOR
GROUP BY CO.NOMBRE, CO.APELLIDOPAT, CO.APELLIDOMAT
ORDER BY TotalPrimaVendida DESC;

--8
SELECT 
    /* Porcentaje de pagos atrasados sobre el total de pagos */
    (
        SELECT COUNT(*)
        FROM Operaciones.PAGO P
        JOIN Operaciones.POLIZA Z
             ON P.NUM_POLIZA = Z.NUM_POLIZA
        WHERE P.FECHA_PAGO > Z.FECHA_FIN   -- pago realizado después de que terminó la póliza
    ) * 100.0
    /
    (
        SELECT COUNT(*)
        FROM Operaciones.PAGO
    ) AS PorcentajeAtraso;

SELECT AVG(DATEDIFF(YEAR, C.FECHA_NACIMIENTO, GETDATE())) AS EdadPromedio
FROM Operaciones.POLIZA P
JOIN Personas.CLIENTE C
     ON P.ID_CLIENTE = C.ID_CLIENTE
WHERE P.CLAVE_SEGURO = '100';   

---10
SELECT 
    /* Porcentaje de pagos atrasados sobre el total de pagos */
    (
        SELECT COUNT(*)
        FROM Operaciones.PAGO P
        JOIN Operaciones.POLIZA Z
             ON P.NUM_POLIZA = Z.NUM_POLIZA
        WHERE P.FECHA_PAGO > Z.FECHA_FIN   -- pago realizado después de que terminó la póliza
    ) * 100.0
    /
    (
        SELECT COUNT(*)
        FROM Operaciones.PAGO
    ) AS PorcentajeAtraso;	