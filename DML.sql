/*
Autores:
  Aranda Marron Fernando 
  Chacon Jaral Hugo Emanuel
  Gutierrez Nolasco Emiliano 
Descripción: Módulo DML (funciones, triggers y vistas) adaptado a esquemas
Fecha: 30/11/2025

Esquemas usados:
  Personas: CLIENTE, CONTACTO, DIRECCION, DIRECCIONCP, BENEFICIARIO,
            CORREDOR, AJUSTADOR
  Seguros  : TIPO_SEGURO, SEGURO_VIDA, SEGURO_RETIRO, SEGURO_AUTO, VEHICULO
  Operaciones: COTIZACION, BITACORA_COTIZACIONES, POLIZA, PAGO, SINIESTRO
*/

USE ASEGURADORA06;
GO

----------------------------------------------------------
-- FUNCIONES
----------------------------------------------------------

-- FUNCION 1
-- Devuelve la edad del cliente al dia de hoy

CREATE FUNCTION Personas.fn_EdadClienteEnFecha
(
    @id_cliente INT,
    @fecha DATE
)
RETURNS INT
AS
BEGIN
    DECLARE @edad INT;

    SELECT @edad = DATEDIFF(YEAR, FECHA_NACIMIENTO, @fecha)
    FROM Personas.CLIENTE
    WHERE ID_CLIENTE = @id_cliente;

    RETURN @edad;
END;
GO
--COMPPROBACION
SELECT 
    ID_CLIENTE,
    NOMBRE,
    APELLIDO_P,
    FECHA_NACIMIENTO,
    Personas.fn_EdadClienteEnFecha(ID_CLIENTE, GETDATE()) AS EDAD_CALCULADA
FROM Personas.CLIENTE
WHERE ID_CLIENTE = 1;
GO


-- FUNCION 2
-- Días transcurridos desde que ocurrió un siniestro
CREATE FUNCTION Operaciones.fn_DiasTranscurridosSiniestro(@num_siniestro INT)
RETURNS INT
AS
BEGIN
    DECLARE @dias INT;

    SELECT @dias = DATEDIFF(DAY, FECHA_HORA, GETDATE())
    FROM Operaciones.SINIESTRO
    WHERE NUM_SINIESTRO = @num_siniestro;

    RETURN @dias;
END;
GO

-- Ver detalle del siniestro
SELECT NUM_SINIESTRO, FECHA_HORA
FROM Operaciones.SINIESTRO;

-- Usar uno de los siniestros existentes
SELECT 
    NUM_SINIESTRO,
    Operaciones.fn_DiasTranscurridosSiniestro(NUM_SINIESTRO) AS Dias_Transcurridos
FROM Operaciones.SINIESTRO
WHERE NUM_SINIESTRO = 3001;


-- FUNCION 3
-- Calcula el saldo pendiente de una póliza
CREATE FUNCTION Operaciones.fn_SaldoPendiente
(
    @num_poliza INT
)
RETURNS DECIMAL(14,2)
AS
BEGIN
    DECLARE @monto_prima DECIMAL(14,2);
    DECLARE @pagado DECIMAL(14,2);

    SELECT @monto_prima = MONTO_PRIMA_TOT
    FROM Operaciones.POLIZA
    WHERE NUM_POLIZA = @num_poliza;

    SELECT @pagado = ISNULL(SUM(MONTO_PAGADO),0)
    FROM Operaciones.PAGO
    WHERE NUM_POLIZA = @num_poliza;

    RETURN @monto_prima - @pagado;
END;
GO

-- Ver pagos de una póliza
SELECT *
FROM Operaciones.POLIZA

SELECT * 
FROM Operaciones.PAGO


-- Ejecutar la función
SELECT 
    NUM_POLIZA,
    Operaciones.fn_SaldoPendiente(NUM_POLIZA) AS Saldo_Calculado
FROM Operaciones.POLIZA
WHERE NUM_POLIZA = 2001;


----------------------------------------------------------
-- TRIGGERS
----------------------------------------------------------
--TRIGGER 1
-- Asegura que el total de porcentajes de beneficiarios no exceda 100%
CREATE TRIGGER Personas.trg_BeneficiariosMaximo100
ON Personas.BENEFICIARIO
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @id_cliente INT;
    DECLARE @clave_seguro VARCHAR(30);
    DECLARE @total_porc DECIMAL(7,2);

    SELECT TOP 1
        @id_cliente   = ID_CLIENTE,
        @clave_seguro = CLAVE_SEGURO
    FROM inserted;

    IF @id_cliente IS NULL OR @clave_seguro IS NULL
        RETURN;

    SELECT @total_porc = SUM(PORCENTAJE)
    FROM Personas.BENEFICIARIO
    WHERE ID_CLIENTE = @id_cliente
      AND CLAVE_SEGURO = @clave_seguro;

    IF @total_porc > 100
    BEGIN
        RAISERROR('La suma de porcentajes de beneficiarios no puede exceder 100.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO

-- COMPROBANDO FUNCIONAMIENTO PARA QUE DE ERROR

-- COMPROBACIÓN TRIGGER 1 
INSERT INTO Personas.BENEFICIARIO
(ID_BENEFICIARIO, APELLIDO_M, APELLIDO_P, NOMBRE, PARENTESCO, PORCENTAJE, CLAVE_SEGURO, ID_CLIENTE)
VALUES (9991, 'TEST', 'EXCESO', 'ERROR', 'HO', 120, '100', 1);
GO


--TRIGGER 2
-- Registra en bitácora cada cambio de estado en las cotizaciones
CREATE TRIGGER Operaciones.trg_BitacoraCotizacion
ON Operaciones.COTIZACION
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE 
        @num_cotizacion INT,
        @nuevo_estado VARCHAR(20),
        @id_bitacora INT;
    
    SELECT TOP 1
        @num_cotizacion = i.NUM_COTIZACION,
        @nuevo_estado   = i.ESTADO
    FROM inserted i
    JOIN deleted d ON d.NUM_COTIZACION = i.NUM_COTIZACION
    WHERE i.ESTADO <> d.ESTADO;

    IF @num_cotizacion IS NULL
        RETURN;

    SELECT @id_bitacora = ISNULL(MAX(ID_BITACORA),0) + 1
    FROM Operaciones.BITACORA_COTIZACIONES;

    INSERT INTO Operaciones.BITACORA_COTIZACIONES
        (ID_BITACORA, NUM_COTIZACION, FECHA_CAMBIO, NUEVO_ESTADO, OBSERVACIONES)
    VALUES
        (@id_bitacora, @num_cotizacion, GETDATE(), @nuevo_estado, 'Cambio de estado registrado automáticamente');
END;
GO

-- COMPROBACIÓN TRIGGER 2
-- Se busca una cotizacion con estado pendiente
SELECT * FROM operaciones.COTIZACION

UPDATE Operaciones.COTIZACION
SET ESTADO = 'APROBADA'
WHERE NUM_COTIZACION = 1006;
GO

SELECT * FROM Operaciones.BITACORA_COTIZACIONES
WHERE NUM_COTIZACION = 1006;
GO

--TRIGGER 3
-- Asigna automáticamente corredor según el rango de código postal

CREATE TRIGGER Personas.trg_AsignaCorredorZona
ON Personas.DIRECCIONCP
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE c
    SET c.ID_CORREDOR = cc.ID_CORREDOR
    FROM Personas.CLIENTE c
    JOIN inserted d
         ON c.ID_CLIENTE = d.ID_CLIENTE
    JOIN Personas.CP_CORREDOR cc
         ON d.ID_CPDIR BETWEEN cc.CP_INICIAL AND cc.CP_FINAL
    WHERE c.ID_CORREDOR IS NULL;
END;
GO

-- COMPROBACIÓN TRIGGER 3

/* 2) Insertar cliente SIN corredor (ID_CORREDOR = NULL) */
INSERT INTO Personas.CLIENTE
(ID_CLIENTE, RFC, CURP, TIPO_CLIENTE,
 NOMBRE, APELLIDO_P, APELLIDO_M, FECHA_NACIMIENTO, ID_CORREDOR)
VALUES
(11,
 'CLI810102ZZZ',      
 'CLI810121HDFXXX11', 
 'NATURAL',
 'JUAN', 'PRUEBA', 'TEST',
 '1981-01-01',
 NULL);              
GO

/* 3) Insertar la DIRECCIONCP PARA ESE MISMO CLIENTE (ID_CLIENTE=11),
      con un CP dentro del rango '01000'–'01999' */
INSERT INTO Personas.DIRECCIONCP
(ID_CPDIR, ESTADO, CIUDAD, ID_CLIENTE)
VALUES
('04200', 'CDMX', 'CDMX', 11);
GO


/* 4) Verificar que el trigger haya asignado corredor */
SELECT ID_CLIENTE, ID_CORREDOR
FROM Personas.CLIENTE
WHERE ID_CLIENTE = 11;
GO



--TRIGGER 4
-- Actualiza el saldo pendiente de una póliza tras registrar un pago
CREATE TRIGGER Operaciones.trg_ActualizaSaldoPendiente
ON Operaciones.PAGO
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @num_poliza INT;

    SELECT @num_poliza = NUM_POLIZA
    FROM inserted;

    UPDATE Operaciones.POLIZA
    SET SALDO_PENDIENTE = Operaciones.fn_SaldoPendiente(@num_poliza)
    WHERE NUM_POLIZA = @num_poliza;
END;
GO

-- COMPROBACIÓN TRIGGER 4
-- Insertar pago de prueba

INSERT INTO Operaciones.PAGO
(ID_PAGO, NUM_POLIZA, STSPAGO, NUM_PAGO, FECHA_PAGO, MONTO_PAGADO, METODO_PAGO)
VALUES (101, 2001, 'PAGADO', 1, GETDATE(), 500, 'TRANSFERENCIA');

SELECT * FROM Operaciones.PAGO
Select * FROM Operaciones.POLIZA
--TRIGGER 5
-- Impide contratar un seguro de vida (clave 100) si el cliente supera 80 años
CREATE TRIGGER Operaciones.trg_ValidaEdadContratacionVida
ON Operaciones.POLIZA
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN Personas.CLIENTE c
             ON i.ID_CLIENTE = c.ID_CLIENTE
        WHERE i.CLAVE_SEGURO = '100'
          AND DATEDIFF(YEAR, c.FECHA_NACIMIENTO, i.FECHA_INICIO) > 80
    )
    BEGIN
        RAISERROR('El cliente supera la edad máxima permitida para contratar un seguro de vida.', 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
GO

-- COMPROBANDO FUNCIONAMIENTO PARA QUE DE ERROR
INSERT INTO Operaciones.POLIZA
(NUM_POLIZA, ID_CLIENTE, ID_CORREDOR, CLAVE_SEGURO,
 FECHA_INICIO, FECHA_FIN, SALDO_PENDIENTE, MONTO_PRIMA_TOT, ESTADO_POLIZA)
VALUES (9001, 1, 1, '100','2100-01-01', '2101-01-01', 5000, 5000, 'ACTIVA');
Select * FROM Operaciones.POLIZA

----------------------------------------------------------
-- VISTAS
----------------------------------------------------------

-- Vista que muestra siniestros junto con los días transcurridos
CREATE VIEW Operaciones.v_SiniestrosConDias AS
SELECT s.*,
       Operaciones.fn_DiasTranscurridosSiniestro(s.NUM_SINIESTRO) AS DIAS_TRANSCURRIDOS
FROM Operaciones.SINIESTRO s;
GO

SELECT * FROM Operaciones.v_SiniestrosConDias

--------------------Resumen del cliente-------------------
/*        Cuántas pólizas tiene
		  Cuántos tipos de seguro distintos tiene
		  Número total de cotizaciones realizadas
		  Monto total de primas contratadas
		  Total pagado en todas sus pólizas
		  Saldo pendiente acumulado         */

CREATE OR ALTER VIEW vis_Cliente_Estadisticas
AS
SELECT
    c.ID_CLIENTE,
    c.NOMBRE,
    c.APELLIDO_P,
    c.APELLIDO_M,

    COUNT(DISTINCT p.NUM_POLIZA) AS NUM_POLIZAS,

    COUNT(DISTINCT p.CLAVE_SEGURO) AS TIPOS_SEGURO_DISTINTOS,

    COUNT(DISTINCT ct.NUM_COTIZACION) AS NUM_COTIZACIONES,

    SUM(ISNULL(p.MONTO_PRIMA_TOT, 0)) AS PRIMA_TOTAL,

    SUM(ISNULL(pg.MONTO_PAGADO, 0)) AS TOTAL_PAGADO,

    SUM(ISNULL(p.SALDO_PENDIENTE, 0)) AS SALDO_PENDIENTE_TOTAL

FROM Personas.CLIENTE c
LEFT JOIN Operaciones.POLIZA p
    ON p.ID_CLIENTE = c.ID_CLIENTE
LEFT JOIN Operaciones.COTIZACION ct
    ON ct.ID_CLIENTE = c.ID_CLIENTE
LEFT JOIN Operaciones.PAGO pg
    ON pg.NUM_POLIZA = p.NUM_POLIZA
GROUP BY
    c.ID_CLIENTE,
    c.NOMBRE,
    c.APELLIDO_P,
    c.APELLIDO_M;
GO

SELECT * FROM vis_Cliente_Estadisticas



--------------------Seguimiento del estatus financiero de cada póliza-------------------

/*        Total pagado
          Número de pagos
          Porcentaje pagado
          Si está al corriente o presenta atraso
          Monto restante                  */


CREATE OR ALTER VIEW vis_Poliza_Finanzas
AS
SELECT
    p.NUM_POLIZA,
    p.ID_CLIENTE,
    cl.NOMBRE + ' ' + cl.APELLIDO_P + ' ' + ISNULL(cl.APELLIDO_M,'') AS CLIENTE,
    p.MONTO_PRIMA_TOT,
    p.SALDO_PENDIENTE,

    SUM(ISNULL(pg.MONTO_PAGADO, 0)) AS TOTAL_PAGADO,

    COUNT(pg.ID_PAGO) AS NUM_PAGOS,

    CASE 
        WHEN p.MONTO_PRIMA_TOT = 0 THEN 0
        ELSE (SUM(ISNULL(pg.MONTO_PAGADO, 0)) * 100.0) / p.MONTO_PRIMA_TOT
    END AS PORCENTAJE_PAGADO,

    CASE 
        WHEN p.SALDO_PENDIENTE = 0 THEN 'LIQUIDADA'
        WHEN SUM(ISNULL(pg.MONTO_PAGADO, 0)) = 0 THEN 'SIN PAGOS'
        WHEN SUM(ISNULL(pg.MONTO_PAGADO, 0)) < p.MONTO_PRIMA_TOT * 0.5 THEN 'ATRASO'
        ELSE 'EN CURSO'
    END AS ESTATUS_FINANCIERO

FROM Operaciones.POLIZA p
JOIN Personas.CLIENTE cl
    ON cl.ID_CLIENTE = p.ID_CLIENTE
LEFT JOIN Operaciones.PAGO pg
    ON pg.NUM_POLIZA = p.NUM_POLIZA
GROUP BY
    p.NUM_POLIZA,
    p.ID_CLIENTE,
    cl.NOMBRE,
    cl.APELLIDO_P,
    cl.APELLIDO_M,
    p.MONTO_PRIMA_TOT,
    p.SALDO_PENDIENTE;
GO

SELECT * FROM vis_Poliza_Finanzas



/*========================================================
  sp_RegistrarCotizacion
========================================================*/
CREATE PROCEDURE Operaciones.sp_RegistrarCotizacion
    @id_cliente         INT,
    @fecha_cotiz        DATE,
    @monto_est_prima    DECIMAL(14,2),
    @estado             VARCHAR(40),
    @recordatorio       VARCHAR(400) = NULL,
    @vigencia_dias      VARCHAR(40),
    @num_cotizacion_out INT OUTPUT
AS
BEGIN
    

    -- 1) Validar que el cliente exista
    IF NOT EXISTS (
        SELECT 1
        FROM Personas.CLIENTE
        WHERE ID_CLIENTE = @id_cliente
    )
    BEGIN
        RAISERROR('El cliente indicado no existe.', 16, 1);
        RETURN;
    END;

    -- 2) Validar que el monto estimado de prima sea positivo
    IF @monto_est_prima <= 0
    BEGIN
        RAISERROR('El monto estimado de prima debe ser mayor que 0.', 16, 1);
        RETURN;
    END;

    -- 3) Obtener el siguiente número de cotización (consecutivo sencillo)
    SELECT @num_cotizacion_out = ISNULL(MAX(NUM_COTIZACION), 0) + 1
    FROM Operaciones.COTIZACION;

    -- 4) Insertar la nueva cotización
    INSERT INTO Operaciones.COTIZACION
        (NUM_COTIZACION,
         ID_CLIENTE,
         FECHA_COTIZ,
         MONTO_EST_PRIMA,
         ESTADO,
         RECORDATORIO,
         VIGENCIA_DIAS)
    VALUES
        (@num_cotizacion_out,
         @id_cliente,
         @fecha_cotiz,
         @monto_est_prima,
         @estado,
         @recordatorio,
         @vigencia_dias);
END;
GO

----Verificacion

DECLARE @nuevoCot INT;

EXEC Operaciones.sp_RegistrarCotizacion
    @id_cliente = 1,
    @fecha_cotiz = '2025-03-10',
    @monto_est_prima = 15000,
    @estado = 'PENDIENTE',
    @recordatorio = 'Cotización generada por SP',
    @vigencia_dias = '30',
    @num_cotizacion_out = @nuevoCot OUTPUT;

SELECT @nuevoCot AS NuevaCotizacion;

SELECT * FROM Operaciones.COTIZACION
/*========================================================
  sp_RegistrarPolizaVida
========================================================*/
CREATE PROCEDURE Operaciones.sp_RegistrarPolizaVida
    @id_cliente       INT,
    @id_corredor      INT,
    @fecha_inicio     DATE,
    @fecha_fin        DATE,
    @monto_prima_tot  DECIMAL(14,2),
    @num_poliza_out   INT OUTPUT
AS
BEGIN

    DECLARE @clave_seguro VARCHAR(30);
    SET @clave_seguro = '100';   -- Seguro de Vida

    -- Validar cliente
    IF NOT EXISTS (
        SELECT 1 FROM Personas.CLIENTE WHERE ID_CLIENTE = @id_cliente
    )
    BEGIN
        RAISERROR('El cliente indicado no existe.', 16, 1);
        RETURN;
    END;

    -- Validar corredor
    IF NOT EXISTS (
        SELECT 1 FROM Personas.CORREDOR WHERE ID_CORREDOR = @id_corredor
    )
    BEGIN
        RAISERROR('El corredor indicado no existe.', 16, 1);
        RETURN;
    END;

    -- Validar tipo de seguro
    IF NOT EXISTS (
        SELECT 1 FROM Seguros.TIPO_SEGURO WHERE CLAVE_SEGURO = @clave_seguro
    )
    BEGIN
        RAISERROR('El tipo de seguro de vida (100) no existe en TIPO_SEGURO.', 16, 1);
        RETURN;
    END;

    -- Validar prima positiva
    IF @monto_prima_tot <= 0
    BEGIN
        RAISERROR('El monto de la prima total debe ser mayor que 0.', 16, 1);
        RETURN;
    END;

    -- Validar vigencia lógica
    IF @fecha_fin <= @fecha_inicio
    BEGIN
        RAISERROR('La fecha de fin debe ser mayor que la fecha de inicio.', 16, 1);
        RETURN;
    END;

    -- Obtener siguiente número de póliza
    SELECT @num_poliza_out = ISNULL(MAX(NUM_POLIZA), 0) + 1
    FROM Operaciones.POLIZA;

    -- Insertar póliza de vida
    INSERT INTO Operaciones.POLIZA
        (NUM_POLIZA,
         ID_CLIENTE,
         ID_CORREDOR,
         CLAVE_SEGURO,
         FECHA_INICIO,
         FECHA_FIN,
         SALDO_PENDIENTE,
         MONTO_PRIMA_TOT,
         ESTADO_POLIZA)
    VALUES
        (@num_poliza_out,
         @id_cliente,
         @id_corredor,
         @clave_seguro,
         @fecha_inicio,
         @fecha_fin,
         @monto_prima_tot,
         @monto_prima_tot,
         'ACTIVA');
END;
GO

---verificacion

DECLARE @nuevaPolizaVida INT;

EXEC Operaciones.sp_RegistrarPolizaVida
    @id_cliente = 1,
    @id_corredor = 5,
    @fecha_inicio = '2025-04-01',
    @fecha_fin = '2026-04-01',
    @monto_prima_tot = 12000,
    @num_poliza_out = @nuevaPolizaVida OUTPUT;

SELECT @nuevaPolizaVida AS NuevaPolizaVida;

SELECT * FROM Operaciones.POLIZA
/*========================================================
  sp_RegistrarPolizaAuto
========================================================*/
CREATE PROCEDURE Operaciones.sp_RegistrarPolizaAuto
    @id_cliente       INT,
    @id_corredor      INT,
    @fecha_inicio     DATE,
    @fecha_fin        DATE,
    @monto_prima_tot  DECIMAL(14,2),
    @num_poliza_out   INT OUTPUT
AS
BEGIN

    DECLARE @clave_seguro VARCHAR(30);
    SET @clave_seguro = '300';   -- Seguro de Auto

    -- Validar cliente
    IF NOT EXISTS (
        SELECT 1 FROM Personas.CLIENTE WHERE ID_CLIENTE = @id_cliente
    )
    BEGIN
        RAISERROR('El cliente indicado no existe.', 16, 1);
        RETURN;
    END;

    -- Validar corredor
    IF NOT EXISTS (
        SELECT 1 FROM Personas.CORREDOR WHERE ID_CORREDOR = @id_corredor
    )
    BEGIN
        RAISERROR('El corredor indicado no existe.', 16, 1);
        RETURN;
    END;

    -- Validar tipo de seguro
    IF NOT EXISTS (
        SELECT 1 FROM Seguros.TIPO_SEGURO WHERE CLAVE_SEGURO = @clave_seguro
    )
    BEGIN
        RAISERROR('El tipo de seguro de auto (300) no existe en TIPO_SEGURO.', 16, 1);
        RETURN;
    END;

    -- Validar prima positiva
    IF @monto_prima_tot <= 0
    BEGIN
        RAISERROR('El monto de la prima total debe ser mayor que 0.', 16, 1);
        RETURN;
    END;

    -- Validar vigencia lógica
    IF @fecha_fin <= @fecha_inicio
    BEGIN
        RAISERROR('La fecha de fin debe ser mayor que la fecha de inicio.', 16, 1);
        RETURN;
    END;

    -- Obtener siguiente número de póliza
    SELECT @num_poliza_out = ISNULL(MAX(NUM_POLIZA), 0) + 1
    FROM Operaciones.POLIZA;

    -- Insertar póliza de auto
    INSERT INTO Operaciones.POLIZA
        (NUM_POLIZA,
         ID_CLIENTE,
         ID_CORREDOR,
         CLAVE_SEGURO,
         FECHA_INICIO,
         FECHA_FIN,
         SALDO_PENDIENTE,
         MONTO_PRIMA_TOT,
         ESTADO_POLIZA)
    VALUES
        (@num_poliza_out,
         @id_cliente,
         @id_corredor,
         @clave_seguro,
         @fecha_inicio,
         @fecha_fin,
         @monto_prima_tot,
         @monto_prima_tot,
         'ACTIVA');
END;
GO

DECLARE @nuevaPolizaAuto INT;

EXEC Operaciones.sp_RegistrarPolizaAuto
    @id_cliente = 2,
    @id_corredor = 6,
    @fecha_inicio = '2025-04-01',
    @fecha_fin = '2026-04-01',
    @monto_prima_tot = 14500,
    @num_poliza_out = @nuevaPolizaAuto OUTPUT;

SELECT @nuevaPolizaAuto AS NuevaPolizaAuto;

SELECT * FROM Operaciones.POLIZA

/*========================================================
  sp_RegistrarPolizaRetiro
========================================================*/
CREATE OR ALTER PROCEDURE Operaciones.sp_RegistrarPolizaRetiro
    @id_cliente       INT,
    @id_corredor      INT,
    @fecha_inicio     DATE,
    @fecha_fin        DATE,
    @monto_prima_tot  DECIMAL(14,2),
    @num_poliza_out   INT OUTPUT
AS
BEGIN

    DECLARE @clave_seguro VARCHAR(30);
    SET @clave_seguro = '200';   -- Seguro de Retiro

    -- Validar cliente
    IF NOT EXISTS (
        SELECT 1 FROM Personas.CLIENTE WHERE ID_CLIENTE = @id_cliente
    )
    BEGIN
        RAISERROR('El cliente indicado no existe.', 16, 1);
        RETURN;
    END;

    -- Validar corredor
    IF NOT EXISTS (
        SELECT 1 FROM Personas.CORREDOR WHERE ID_CORREDOR = @id_corredor
    )
    BEGIN
        RAISERROR('El corredor indicado no existe.', 16, 1);
        RETURN;
    END;

    -- Validar tipo de seguro
    IF NOT EXISTS (
        SELECT 1 FROM Seguros.TIPO_SEGURO WHERE CLAVE_SEGURO = @clave_seguro
    )
    BEGIN
        RAISERROR('El tipo de seguro de retiro (200) no existe en TIPO_SEGURO.', 16, 1);
        RETURN;
    END;

    -- Validar prima positiva
    IF @monto_prima_tot <= 0
    BEGIN
        RAISERROR('El monto de la prima total debe ser mayor que 0.', 16, 1);
        RETURN;
    END;

    -- Validar vigencia lógica
    IF @fecha_fin <= @fecha_inicio
    BEGIN
        RAISERROR('La fecha de fin debe ser mayor que la fecha de inicio.', 16, 1);
        RETURN;
    END;

    -- Obtener siguiente número de póliza
    SELECT @num_poliza_out = ISNULL(MAX(NUM_POLIZA), 0) + 1
    FROM Operaciones.POLIZA;

    -- Insertar póliza de retiro
    INSERT INTO Operaciones.POLIZA
        (NUM_POLIZA,
         ID_CLIENTE,
         ID_CORREDOR,
         CLAVE_SEGURO,
         FECHA_INICIO,
         FECHA_FIN,
         SALDO_PENDIENTE,
         MONTO_PRIMA_TOT,
         ESTADO_POLIZA)
    VALUES
        (@num_poliza_out,
         @id_cliente,
         @id_corredor,
         @clave_seguro,
         @fecha_inicio,
         @fecha_fin,
         @monto_prima_tot,
         @monto_prima_tot,
         'ACTIVA');
END;
GO

---VERIFICACION

DECLARE @nuevaPolizaRetiro INT;

EXEC Operaciones.sp_RegistrarPolizaRetiro
    @id_cliente = 3,
    @id_corredor = 7,
    @fecha_inicio = '2025-04-01',
    @fecha_fin = '2026-04-01',
    @monto_prima_tot = 18000,
    @num_poliza_out = @nuevaPolizaRetiro OUTPUT;

SELECT @nuevaPolizaRetiro AS NuevaPolizaRetiro;

SELECT * FROM Operaciones.POLIZA

/*========================================================
  sp_RegistrarPago
========================================================*/
CREATE PROCEDURE Operaciones.sp_RegistrarPago
    @num_poliza     INT,
    @stspago        VARCHAR(40),
    @fecha_pago     DATE,
    @monto_pagado   DECIMAL(14,2),
    @metodo_pago    VARCHAR(50),
    @id_pago_out    INT OUTPUT
AS
BEGIN

    -- Validar que la póliza exista
    IF NOT EXISTS (
        SELECT 1 FROM Operaciones.POLIZA WHERE NUM_POLIZA = @num_poliza
    )
    BEGIN
        RAISERROR('La póliza indicada no existe.', 16, 1);
        RETURN;
    END;

    -- Validar monto positivo
    IF @monto_pagado <= 0
    BEGIN
        RAISERROR('El monto pagado debe ser mayor que 0.', 16, 1);
        RETURN;
    END;

    -- Validar estatus de pago compatible con el CHECK
    IF @stspago NOT IN ('PAGADO','PENDIENTE')
    BEGIN
        RAISERROR('El estatus de pago debe ser PAGADO o PENDIENTE.', 16, 1);
        RETURN;
    END;

    -- Nuevo ID_PAGO global
    SELECT @id_pago_out = ISNULL(MAX(ID_PAGO), 0) + 1
    FROM Operaciones.PAGO;

    -- Nuevo número de pago dentro de la póliza
    DECLARE @num_pago INT;
    SELECT @num_pago = ISNULL(MAX(NUM_PAGO), 0) + 1
    FROM Operaciones.PAGO
    WHERE NUM_POLIZA = @num_poliza;

    -- Insertar
    INSERT INTO Operaciones.PAGO
        (ID_PAGO, NUM_POLIZA, STSPAGO, NUM_PAGO, FECHA_PAGO, MONTO_PAGADO, METODO_PAGO)
    VALUES
        (@id_pago_out, @num_poliza, @stspago, @num_pago, @fecha_pago, @monto_pagado, @metodo_pago);
END;
GO
---VERIFICACION
DECLARE @nuevoPago INT;

EXEC Operaciones.sp_RegistrarPago
    @num_poliza = 2001,
    @stspago = 'PAGADO',
    @fecha_pago = '2025-04-15',
    @monto_pagado = 1500,
    @metodo_pago = 'TRANSFERENCIA',
    @id_pago_out = @nuevoPago OUTPUT;

SELECT @nuevoPago AS NuevoPago;

SELECT * FROM Operaciones.PAGO

/*========================================================
  sp_RegistrarSiniestro
========================================================*/
CREATE OR ALTER PROCEDURE Operaciones.sp_RegistrarSiniestro
    @num_poliza        INT,
    @fecha_hora        DATETIME,
    @lugar             VARCHAR(400),
    @causa             VARCHAR(400),
    @monto_indemniz    DECIMAL(14,2),
    @num_siniestro_out INT OUTPUT
AS
BEGIN

    -- Validar póliza
    IF NOT EXISTS (
        SELECT 1 FROM Operaciones.POLIZA WHERE NUM_POLIZA = @num_poliza
    )
    BEGIN
        RAISERROR('La póliza indicada no existe.', 16, 1);
        RETURN;
    END;

    -- Validar indemnización positiva
    IF @monto_indemniz <= 0
    BEGIN
        RAISERROR('El monto de indemnización debe ser mayor que 0.', 16, 1);
        RETURN;
    END;

    -- Nuevo número de siniestro
    SELECT @num_siniestro_out = ISNULL(MAX(NUM_SINIESTRO), 0) + 1
    FROM Operaciones.SINIESTRO;

    INSERT INTO Operaciones.SINIESTRO
        (NUM_SINIESTRO,
         NUM_POLIZA,
         FECHA_HORA,
         LUGAR,
         CAUSA,
         MONTO_INDEMNIZ,
         FECHA_REGISTRO)
    VALUES
        (@num_siniestro_out,
         @num_poliza,
         @fecha_hora,
         @lugar,
         @causa,
         @monto_indemniz,
         GETDATE());
END;
GO

---VERIFICACION

DECLARE @nuevoPago INT;

EXEC Operaciones.sp_RegistrarPago
    @num_poliza = 2001,
    @stspago = 'PAGADO',
    @fecha_pago = '2025-04-15',
    @monto_pagado = 1500,
    @metodo_pago = 'TRANSFERENCIA',
    @id_pago_out = @nuevoPago OUTPUT;

SELECT @nuevoPago AS NuevoPago;

SELECT * FROM Operaciones.PAGO
/*========================================================
  sp_RegistrarPoliza 
=======================================================*/
CREATE PROCEDURE Operaciones.sp_RegistrarPoliza
    @id_cliente       INT,
    @id_corredor      INT,
    @clave_seguro     VARCHAR(30),
    @fecha_inicio     DATE,
    @fecha_fin        DATE,
    @monto_prima_tot  DECIMAL(14,2),
    @estado_poliza    VARCHAR(20),
    @num_poliza_out   INT OUTPUT
AS
BEGIN

    -- Validar cliente
    IF NOT EXISTS (
        SELECT 1 FROM Personas.CLIENTE WHERE ID_CLIENTE = @id_cliente
    )
    BEGIN
        RAISERROR('El cliente indicado no existe.', 16, 1);
        RETURN;
    END;

    -- Validar corredor
    IF NOT EXISTS (
        SELECT 1 FROM Personas.CORREDOR WHERE ID_CORREDOR = @id_corredor
    )
    BEGIN
        RAISERROR('El corredor indicado no existe.', 16, 1);
        RETURN;
    END;

    -- Validar tipo de seguro
    IF NOT EXISTS (
        SELECT 1 FROM Seguros.TIPO_SEGURO WHERE CLAVE_SEGURO = @clave_seguro
    )
    BEGIN
        RAISERROR('La clave de seguro indicada no existe en TIPO_SEGURO.', 16, 1);
        RETURN;
    END;

    -- Validar prima positiva
    IF @monto_prima_tot <= 0
    BEGIN
        RAISERROR('El monto de la prima total debe ser mayor que 0.', 16, 1);
        RETURN;
    END;

    -- Validar vigencia lógica
    IF @fecha_fin <= @fecha_inicio
    BEGIN
        RAISERROR('La fecha de fin debe ser mayor que la fecha de inicio.', 16, 1);
        RETURN;
    END;

    -- Nuevo número de póliza
    SELECT @num_poliza_out = ISNULL(MAX(NUM_POLIZA), 0) + 1
    FROM Operaciones.POLIZA;

    INSERT INTO Operaciones.POLIZA
        (NUM_POLIZA,
         ID_CLIENTE,
         ID_CORREDOR,
         CLAVE_SEGURO,
         FECHA_INICIO,
         FECHA_FIN,
         SALDO_PENDIENTE,
         MONTO_PRIMA_TOT,
         ESTADO_POLIZA)
    VALUES
        (@num_poliza_out,
         @id_cliente,
         @id_corredor,
         @clave_seguro,
         @fecha_inicio,
         @fecha_fin,
         @monto_prima_tot,
         @monto_prima_tot,
         @estado_poliza);
END;

DECLARE @nuevaPolizaGenerica INT;

EXEC Operaciones.sp_RegistrarPoliza
    @id_cliente = 4,
    @id_corredor = 8,
    @clave_seguro = '100',   -- 100 = Vida, 200 = Retiro, 300 = Auto
    @fecha_inicio = '2025-04-10',
    @fecha_fin = '2026-04-10',
    @monto_prima_tot = 13000,
    @estado_poliza = 'ACTIVA',
    @num_poliza_out = @nuevaPolizaGenerica OUTPUT;

SELECT @nuevaPolizaGenerica AS NuevaPolizaGenerica;

SELECT * FROM Operaciones.POLIZA
GO