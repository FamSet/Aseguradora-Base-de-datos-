# Proyecto - Documentación del Sistema de Base de Datos (Aseguradora)

Este proyecto implementa el diseño, estructura y lógica de negocio de una base de datos para una **Aseguradora** utilizando SQL Server. El sistema permite gestionar de manera integral clientes, pólizas, siniestros, pagos y la fuerza de ventas.

## Índice

1. [Descripción General](#descripción-general)
2. [Funcionalidades](#funcionalidades)
3. [Estructura de Esquemas](#estructura-de-esquemas)
4. [Módulos del Sistema](#módulos-del-sistema)
5. [Ejecución del Sistema](#ejecución-del-sistema)
6. [Requisitos](#requisitos)

## Descripción General

El sistema centraliza la operación de una aseguradora multirramo. La base de datos, denominada `ASEGURADORA06`, está diseñada bajo una arquitectura de esquemas para separar las responsabilidades de datos personales, definiciones de seguros y operaciones transaccionales.

## Funcionalidades

* **Gestión Multirramo:** Tablas especializadas para seguros de vida, retiro y vehículos.
* **Automatización de Negocio:** Triggers que actualizan saldos y validan estados en tiempo real.
* **Seguridad Granular:** Implementación de roles (`GERENTE`, `ASESOR`, etc.) con permisos mediante `GRANT`.
* **Inteligencia de Datos:** Consultas avanzadas para reportes de siniestralidad y productividad.

## Estructura de Esquemas

* **Personas:** Tablas como `CLIENTE`, `CORREDOR` y `AJUSTADOR`.
* **Seguros:** Definiciones de `TIPO_SEGURO` y coberturas.
* **Operaciones:** Flujo de `COTIZACION`, `POLIZA`, `PAGO` y `SINIESTRO`.

## Módulos del Sistema

### 1. DDL (CREAR.sql)
Define la infraestructura base, creación de tablas y restricciones (`CHECK`, `PK`, `FK`).
* **Ejemplo:** `CHK_POLIZA_VIGENCIA_LOGICA` asegura que la fecha fin sea mayor a la de inicio.

### 2. DML (DML.sql)
Contiene la lógica programable:
* **Funciones:** `fn_EdadClienteEnFecha` para cálculos dinámicos.
* **Triggers:** Automatización de folios y saldos pendientes.

### 3. Carga de Datos (CARGA.sql)
Script para poblar el sistema con datos de prueba, incluyendo catálogos y registros históricos.

### 4. Seguridad (SEGURIDAD.sql)
Gestiona el acceso mediante roles como `ADMINISTRADOR_SEGURO` y `JEFE_COMERCIAL`.

### 5. Estadísticas (INFORMES1.sql)
Consultas para generar métricas clave, como el ranking de corredores y porcentaje de morosidad.

## Ejecución del Sistema

Se recomienda ejecutar los scripts en el siguiente orden para evitar errores de dependencia:
1. `CREAR.sql`
2. `DML.sql`
3. `CARGA.sql`
4. `SEGURIDAD.sql`
5. `INFORMES1.sql`

## Requisitos

* **Motor:** SQL Server 2019 o superior.
* **IDE:** SQL Server Management Studio (SSMS) o Azure Data Studio.
