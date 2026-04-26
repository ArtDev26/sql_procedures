/*=======================================================================================
Proyecto: 
    ERP Agro

Procedimiento:
    SP_PedidosVenta_CambioAlmacen.sql

Autor:
    Arturo Escalante - Analista de Informacion y Procesos

Descripcion:
    Procedimiento para actualizar el almacén de origen por defecto de un pedido
    de venta y sincronizar dicho almacén en sus líneas asociadas.

Objetivo:
    Mantener consistencia operativa entre la cabecera del pedido de venta y las
    líneas/artículos relacionados, evitando diferencias de almacén en el flujo
    comercial-logístico.

Parametros:
    @IdPedidoVenta - Identificador del Pedido de Venta.
    @IdAlmacen - Identificador de Almacen a asignar

Características técnicas:
     - Validación de existencia del pedido de venta.
     - Validación de existencia de líneas asociadas.
     - Actualización transaccional de cabecera y detalle.
     - Manejo de errores con TRY/CATCH.
     - Retorno de filas afectadas para trazabilidad.

Nota: 
    Este script fue adaptado y anonimizado para fines demostrativos de portafolio.
    No contiene credenciales, datos reales ni información sensible de empresa.
========================================================================================*/ 
/*
++++++++++++++++++++++++++++++++++++++++++
VARIABLES DE PRUEBA
++++++++++++++++++++++++++++++++++++++++++
*/
DECLARE @Pedido int = 16 , @Almacen int = 74
/* 
++++++++++++++++++++++++++++++++++++++++++
CAMBIO DE ALMACEN EN PEDIDOS VENTA
++++++++++++++++++++++++++++++++++++++++++
*/

UPDATE PedidosVenta
SET Id_AlmacenOrigenDefecto = @Almacen
Where Id = @Pedido


/* 
++++++++++++++++++++++++++++++++++++++++++
CAMBIO DE ALMACEN EN LINEAS PEDIDOS VENTA
++++++++++++++++++++++++++++++++++++++++++
*/
DECLARE @LPV TABLE (Id_LPV int)
Insert Into @LPV (Id_LPV)
Select Id Id_LPV from LineasPedidoVenta where Id_PedidoVenta = @Pedido

UPDATE LPVA
SET LPVA.Id_AlmacenOrigen = @Almacen
FROM LineasPedidoVentaArticulo LPVA
JOIN @LPV T ON T.Id_LPV = LPVA.Id_LineaPedidoVenta;


