/*=======================================================================================
Proyecto: 
    ERP Agro

Procedimiento:
    SP_Packing_StockCamara.sql

Autor:
    Arturo Escalante - Analista de Informacion y Procesos

Descripcion:
    Procedimiento para el control de stock en cámaras de packing. Consolida
    información de existencias por fecha, packing, cultivo, variedad, lote,
    categoría y calibre.

Objetivo:
    Proveer una vista confiable en tiempo real del stock en cámara para control operativo,
    planificación y toma de decisiones.

Parametros:
    @FechaDesde - Fecha Inicial del analisis.
    @FechaHasta - Fecha Final del analisis.
    @Cultivo - Codigo de cultivo a evaluar.
    @Packing - Packing o planta de proceso

Características técnicas:
    - Uso de CTEs / tablas temporales para segmentación por etapas
    - Filtros dinámicos (fechas, packing, cultivo)
    - Agregaciones por dimensiones operativas
    - Preparado para reporting (Power BI / ERP)

Nota: 
    Este script fue adaptado y anonimizado para fines demostrativos de portafolio.
    No contiene credenciales, datos reales ni información sensible de empresa.
========================================================================================*/    

Declare @Id_Campaña int = 15
  
/*=======================================================================================================      
	SEGMENTO DE OPTIMIZACION PARA SOLO FILTRAR LAS FECHAS DONDE HAY PALES EN EXISTENCIAS
=========================================================================================================*/ 

;WITH EX AS (
Select AE.Id_UnidadLogistica, A.Nombre, ANS.NumeroSerie,ANS.FechaFabricacion, SUM(AE.Cantidad) Envases from AcumuladoExistencias AE
	left join ArticulosNumerosSerie ANS on ANS.Id = AE.Id_UnidadLogistica
	left join Articulos A on A.Id = AE.Id_Articulo
Where ANS.FechaFabricacion > '20251001' and AE.Id_Almacen in (82,83,79,78,76,77) and A.TipoArticulo = 1 and A.Nombre Like 'EMP/%'
Group by AE.Id_UnidadLogistica,A.Nombre, ANS.NumeroSerie, ANS.FechaFabricacion
)
Select * 
Into #RangoFechas
from EX
Where Envases > 0
Order by Id_UnidadLogistica

DECLARE @FechaDesde datetime, @FechaHasta datetime
SET @FechaDesde = (Select DATEADD(DAY, -3, MIN(CONVERT(date, FechaFabricacion))) FechaInicio from #RangoFechas)
SET @FechaHasta = (Select DATEADD(DAY,  3, MAX(CONVERT(date, FechaFabricacion))) FechaFin from #RangoFechas)
       
/*=======================================================================================================      
           DECLARACION DE VARIABLES DE CAMPAÑA Y CULTIVO     
=========================================================================================================*/      
DECLARE @Cultivo Varchar(5)      
SET @Cultivo = (      
     Select       
      CASE       
       When Nombre like '%UVA%' THEN '2'      
       When Nombre like '%PALTA%' THEN '3'      
       when Nombre like '%ARANDANO%' THEN '4'      
      END Cultivo      
     From Campanyas C where C.Id = @Id_Campaña      
)      

/*=======================================================================================================      
           INCLUIR TRASPASOS      
=========================================================================================================*/      
DECLARE @IncluirTraspasos BIT                    
SET @IncluirTraspasos =1       
      
-- Establecer los valores por defecto para parámetros nulos.                     
  SELECT @FechaDesde = COALESCE(@FechaDesde, '19000101'), @FechaHasta = COALESCE(@FechaHasta, '99991231')                    

/*=======================================================================================================      
          OPTIMIZACION DE TABLAS      
=========================================================================================================*/         
       
 --> Partidas      
  SELECT P.*, A.Nombre Articulo      
  INTO #Partidas       
  FROM Partidas P      
   inner join Articulos A on A.Id = P.Id_Articulo      
   inner join FamiliasArticulo F1 on F1.Id = A.Id_Familia      
   inner join FamiliasArticulo F2 on F2.Id = F1.Id_FamiliaSuperior      
   inner join FamiliasArticulo F3 on F3.Id = F2.Id_FamiliaSuperior and F3.Codigo = @Cultivo      
  WHERE P.Fecha BETWEEN  @FechaDesde and @FechaHasta     
      
	CREATE CLUSTERED INDEX IX_##Partidas_Id ON #Partidas(Id);
	CREATE NONCLUSTERED INDEX IX_##Partidas_Fecha ON #Partidas(Fecha) INCLUDE (Id, Id_Articulo);
 --Select * from #Partidas      
 --> ArticulosPartida      
  SELECT AP.* INTO #ArticulosPartida FROM ArticulosPartida AP                    
   JOIN #Partidas P ON P.Id = AP.Id_Partida  
   
	CREATE CLUSTERED INDEX IX_##AP_Id ON #ArticulosPartida(Id);
	CREATE NONCLUSTERED INDEX IX_##AP_Partida ON #ArticulosPartida(Id_Partida) INCLUDE (Id, Id_Articulo);
   
 --> Reservas_ArticulosReservados      
  SELECT * INTO #Reservas_ArticulosReservados FROM Reservas_ArticulosReservados RAR      
   JOIN #ArticulosPartida AP on AP.Id = RAR.Id_ArticulosReservados 
   
      
 --> LineasDocumentoEnvio_ArticulosEnviados       
  SELECT * INTO #LineasDocumentoEnvio_ArticulosEnviados FROM LineasDocumentoEnvio_ArticulosEnviados LAE      
   JOIN #ArticulosPartida AP on AP.Id = LAE.Id_ArticulosEnviados      
      
 --> LineasRecepcion_ArticulosRecibidos      
  SELECT * INTO #LineasRecepcion_ArticulosRecibidos FROM LineasRecepcion_ArticulosRecibidos LAR      
   JOIN #ArticulosPartida AP on AP.Id = LAR.Id_ArticulosRecibidos   
   
	CREATE NONCLUSTERED INDEX IX_##LRAR_LineaRec ON #LineasRecepcion_ArticulosRecibidos(Id_LineasRecepcion) INCLUDE (Id_ArticulosRecibidos);
	CREATE NONCLUSTERED INDEX IX_##LRAR_ArtRec  ON #LineasRecepcion_ArticulosRecibidos(Id_ArticulosRecibidos) INCLUDE (Id_LineasRecepcion);
      
 --> UbicacionesUnidadPartida      
  SELECT UUP.* INTO #UbicacionesUnidadPartida FROM UbicacionesUnidadPartida UUP      
   JOIN #ArticulosPartida AP on AP.Id = UUP.Id_ArticuloPartida 

   	CREATE NONCLUSTERED INDEX IX_##UUP_ArtPart ON #UbicacionesUnidadPartida(Id_ArticuloPartida) INCLUDE (Id_UnidadLogistica, Cantidad);

/*=======================================================================================================      
           RECEPCIONES      
=========================================================================================================*/          
Select Distinct                     
 AP.Id_Partida ,                     
 LRA.Id_ProveedorTrazabilidad  , F3.Codigo                  
Into #DatosPartidasRecepciones                    
From LineasRecepcion LR                     
 inner join LineasRecepcionArticulo LRA on LRA.Id_LineaRecepcion = LR.Id                     
 inner join #LineasRecepcion_ArticulosRecibidos LRAR on LRAR.Id_LineasRecepcion = LR.Id                     
 inner join ArticulosPartida AP on AP.Id =LRAR.Id_ArticulosRecibidos                     
 inner join Articulos A on A.Id = AP.Id_Articulo and A.EsMateriaPrima = 1                    
 inner join Partidas P on P.Id = AP.Id_Partida                     
 inner join (Select                     
			 UUP.Id_ArticuloPartida, UUP.Cantidad, UUP.Id_UnidadLogistica ,                     
			 ANS.NumeroSerie, U.Codigo Ubicacion                    
			From #UbicacionesUnidadPartida UUP      
			 inner join Ubicaciones U on U.Id = UUP.Id_Ubicacion                     
			 left join ArticulosNumerosSerie ANS on ANS.Id = UUP.Id_UnidadLogistica       
			Where ANS.FechaFabricacion Between  @FechaDesde and @FechaHasta      
			) U on U.Id_ArticuloPartida = AP.Id         
 INNER JOIN FamiliasArticulo F1 ON F1.Id=A.Id_Familia      
 INNER JOIN FamiliasArticulo F2 ON F2.Id=F1.Id_FamiliaSuperior      
 INNER JOIN FamiliasArticulo F3 ON F3.Id=F2.Id_FamiliaSuperior and F3.Codigo = @Cultivo      
 WHERE P.Fecha BETWEEN  @FechaDesde and @FechaHasta          
       
 CREATE CLUSTERED INDEX IX_#DPR_Partida ON #DatosPartidasRecepciones (Id_Partida);  

Select Distinct Id_Articulo , Id_Envase                     
Into #CombinacionesArticuloEnvase                    
From (                    
  Select LRA.Id_Articulo, ENV.Id Id_Envase                    
  From LineasRecepcion LR                     
   inner join #LineasRecepcion_ArticulosRecibidos LRAR on LRAR.Id_LineasRecepcion = LR.Id                     
   inner join LineasRecepcionArticulo LRA on LRA.Id_LineaRecepcion = LR.Id                     
   inner join Articulos A on A.Id = LRA.Id_Articulo and A.EsMateriaPrima = 1                    
   inner join LineasRecepcionArticulo_DesgloseLinea LRADL on LRADL.Id_LineasRecepcionArticulo = LRA.Id_LineaRecepcion                     
   inner join DesgloseLineas DL on DL.Id = LRADL.Id_DesgloseLinea                     
   inner join Articulos ENV on ENV.Id = DL.Id_Articulo and ENV.TipoArticulo = 1                    
  UNION ALL                     
  Select PPRS.Id_Articulo , A.Id Id_Envase                    
  From PartesProduccionRealSalida PPRS                     
   inner join PartesProduccionRealSalida_ArticulosProducidosLinea APL on APL.Id_PartesProduccionRealSalida = PPRS.Id                     
   inner join #Articulospartida APAR on APAR.Id = APL.Id_ArticulosProducidosLinea                        
   inner join PartesProduccionRealSalida_DesgloseLinea PPRSDL on PPRSDL.Id_PartesProduccionRealSalida = PPRS.Id           
   inner join DesgloseLineas DL on DL.Id = PPRSDL.Id_DesgloseLinea                     
   inner join Articulos A on A.Id = DL.Id_Articulo and A.TipoArticulo = 1                    
 ) T           

 CREATE CLUSTERED INDEX IX_#CAE_ArticuloEnvase ON #CombinacionesArticuloEnvase (Id_Articulo, Id_Envase);  
     	 
/*=======================================================================================================      
          PESO NORMALIZADO      
=========================================================================================================*/        
Select C.Id_Articulo , C.Id_Envase , dbo.RNEG063PesoNormalizadoConUnidadMedidaGeneral(C.Id_Articulo , C.Id_Envase , 0) PesoNormalizado                    
Into #PesosNormalizados                    
From #CombinacionesArticuloEnvase C                    
 
CREATE CLUSTERED INDEX IX_#PN_ArticuloEnvase ON #PesosNormalizados (Id_Articulo, Id_Envase);  

/*=======================================================================================================      
       INFORMACION ACERCA DEL ARTICULO DE TIPO PALE      
=========================================================================================================*/        
Select                     
 PPRS.Id Id_PPRS, PART.Serie, PART.Numero,                     
 A.TipoArticulo, A.Codigo, A.Nombre, A.Descripcion, A.DescripcionCorta,                    
 UUP.Cantidad, ANS.NumeroSerie, UUP.Id_UnidadLogistica                    
Into #InfoArtTipoPalePorPPRS                    
From PartesProduccionRealSalida PPRS                    
 inner join PartesProduccionRealSalida_ArticulosProducidosLinea APL on APL.Id_PartesProduccionRealSalida = PPRS.Id                    
 inner join #ArticulosPartida AP on AP.Id = APL.Id_ArticulosProducidosLinea                    
 inner join #Partidas PART on PART.Id = AP.Id_Partida                    
 inner join Articulos A on A.Id = AP.Id_Articulo and A.TipoArticulo = 0                    
 inner join #UbicacionesUnidadPartida UUP on UUP.Id_ArticuloPartida = AP.Id and UUP.Cantidad > 0                    
 inner join ArticulosNumerosSerie ANS on ANS.Id = UUP.Id_UnidadLogistica               

CREATE CLUSTERED INDEX IX_#InfoPale_UL ON #InfoArtTipoPalePorPPRS (Id_UnidadLogistica);  

/*=======================================================================================================      
      EXISTENCIAS DE PRODUCTO POR PARTIDA Y UNIDAD LOGISTICA      
=========================================================================================================*/                    
select                     
 AE.Id_Articulo, AE.Id_Partida, AE.Id_UnidadLogistica, AE.Cantidad                     
Into #ExistenciasProducto                    
From AcumuladoExistencias AE      
 inner join Articulos A on A.id = AE.id_Articulo                  
 inner join #Partidas P on P.id = AE.Id_Partida                     
Where AE.Id_Articulo = P.Id_Articulo and  Cantidad > 0                    
                
CREATE CLUSTERED INDEX IX_#ExistProd_PartidaUL ON #ExistenciasProducto (Id_Partida, Id_UnidadLogistica);  
          
/*=======================================================================================================      
     EXISTENCIAS DE ENVASES POR PARTIDA Y UNIDAD LOGISTICA      
=========================================================================================================*/                    
Select                     
 AE.Id_Articulo, AE.Id_Partida, AE.Id_UnidadLogistica, AE.Cantidad                     
Into #ExistenciasEnvase                    
From AcumuladoExistencias AE      
   inner join Articulos A on A.id = AE.id_Articulo                     
   inner join #Partidas P on P.id = AE.Id_Partida                     
  where A.TipoArticulo = 1 and AE.Id_Articulo <> P.Id_Articulo and Cantidad > 0                    
 
 CREATE CLUSTERED INDEX IX_#ExistEnv_PartidaUL ON #ExistenciasEnvase (Id_Partida, Id_UnidadLogistica);  
         
/*=======================================================================================================      
       RESERVAS DE UNIDADES LOGISTICAS      
=========================================================================================================*/                  
Create Table #ReservasUL (      
FechaPedido DATETIME,    Pedido VARCHAR(100),   NombreClientePedido VARCHAR(100),   DireccionEnvioPedido VARCHAR(400),                    
 Linea INT,       Id_Partida INT,     Id_UnidadLogistica INT,      FechaSalidaPedidoVenta DATETIME,       
 FechaEntregaPedidoVenta DATETIME, CodigoConfeccion VARCHAR(10), Confeccion VARCHAR(50),      EnvasesPorPalet INT,       
 NombreEnvio VARCHAR(50),   Id_Pedido INT,     Destino VARCHAR(150)      
 )                    
                    
Create Index IX_#ReservasUL on #ReservasUL(Id_Partida,Id_UnidadLogistica)                    
                    
Insert #ReservasUL (      
 FechaPedido,      Pedido ,      NombreClientePedido ,      DireccionEnvioPedido,      
 Linea,        Id_Partida,      Id_UnidadLogistica,       FechaSalidaPedidoVenta,       
 FechaEntregaPedidoVenta,   CodigoConfeccion,    Confeccion,         EnvasesPorPalet,       
 NombreEnvio,      Id_Pedido,      Destino      
 )                    
      
Select                     
 PV.Fecha FechaPedido, CONCAT(PV.Serie,'/', PV.Numero) Pedido, dbo.Nombre(C.Id_Sujeto) as NombreClientePedido,                     
 dbo.DireccionAbreviada(PV.Id_DireccionEnvio) as DireccionEnvioPedido,                    
 LPV.Orden Linea, AP.Id_Partida, UUP.Id_UnidadLogistica, PV.FechaSalida, PV.FechaEntrega,                
 CO.Codigo CodigoConfeccion, CO.Nombre Confeccion, CO.EnvasesPorPalet, DIR.Nombre NombreEnvio, PV.Id, PA.NombreOficial            
From PedidosVenta PV                     
 inner join Clientes C on C.id = PV.Id_Cliente                     
 inner join LineasPedidoVenta LPV on LPV.Id_PedidoVenta = PV.Id                    
 inner join LineasPedidoVentaArticulo LPVA ON LPVA.Id_LineaPedidoVenta=LPV.Id                
 inner join Confeccion CO ON CO.Id=LPVA.Id_Confeccion                
 inner join Reservas R on R.Id_DocumentoOrigen = LPV.Id and R.TipoOrigenReserva = 1                    
 inner join #Reservas_ArticulosReservados RAR on RAR.Id_Reservas = R.id                     
 inner join #Articulospartida AP on AP.Id = RAR.Id_ArticulosReservados                     
 inner join #Partidas P on P.Id = AP.Id_Partida                     
 inner join Articulos A on A.id = AP.Id_Articulo and A.TipoArticulo = 2                    
 inner join (Select Distinct Id_Articulo From ArticulosCaracteristica ) AC on AC.Id_Articulo = A.Id                     
 inner join #UbicacionesUnidadPartida UUP on UUP.Id_ArticuloPartida = AP.Id                     
 inner join ArticulosNumerosSerie ANS on ANS.Id = UUP.Id_UnidadLogistica                     
 left join Direcciones DIR on DIR.Id=PV.Id_DireccionEnvio      
 left join Paises PA on PA.Id = DIR.Id_Pais      
  
 CREATE NONCLUSTERED INDEX IX_#ReservasUL_Pedido ON #ReservasUL (Id_Pedido);  

/*=======================================================================================================      
       DATOS DE PALES VENDIDOS      
=========================================================================================================*/                                     
Create Table #VentasUL (      
 FechaAlbaran DATETIME,    Albaran VARCHAR(100),   NombreClienteAlbarán VARCHAR(100),   DireccionEnvioAlbaran VARCHAR(400),      
 Linea INT,       Id_Partida INT,     Id_UnidadLogistica INT      
 )                    
                    
Create Index IX_#VentasUL on #VentasUL (Id_Partida, Id_UnidadLogistica)                    
                    
Insert #VentasUL (      
 FechaAlbaran,      Albaran,      NombreClienteAlbarán,      DireccionEnvioAlbaran,      
 Linea,        Id_Partida,      Id_UnidadLogistica      
 )        
Select                     
 AV.Fecha FechaAlbaran, CONCAT(AV.Serie,'/',AV.Numero) Albaran, dbo.Nombre(C.Id_Sujeto) as NombreClienteAlbarán,                     
 dbo.DireccionAbreviada(AV.Id_DireccionEnvio) as DireccionEnvioAlbaran,                    
 LAV.Orden Linea, AP.Id_Partida, UUP.Id_UnidadLogistica             
From AlbaranesVenta AV                     
 inner join Clientes C on C.id = av.Id_Cliente                     
 inner join LineasAlbaranVenta LAV on LAV.Id_AlbaranVenta = AV.Id                     
 inner join LineasDocumentoEnvio LDE on LDE.Id = LAV.Id_LineaEnvio                     
 inner join #LineasDocumentoEnvio_ArticulosEnviados LDEAE on LDEAE.Id_LineasDocumentoEnvio = LDE.Id                     
 inner join #ArticulosPartida AP on AP.Id = LDEAE.Id_ArticulosEnviados                     
 inner join #Partidas P on P.Id = AP.Id_Partida                     
 inner join Articulos A on A.id = AP.Id_Articulo and A.EsMateriaPrima = 1                    
 inner join #UbicacionesUnidadPartida UUP on UUP.Id_ArticuloPartida = AP.Id                     
 inner join ArticulosNumerosSerie ANS on ANS.Id = UUP.Id_UnidadLogistica                     

 CREATE NONCLUSTERED INDEX IX_#VentasUL_Albaran ON #VentasUL (Id_Partida, Id_UnidadLogistica);  
          
/*=======================================================================================================      
     SELECT PARA OBTENER UNIDADES LOGISTICAS (RECEPCIONADOS O FABRICADAS      
=========================================================================================================*/             
                
Create Table #UnidadesLogisticas (       
	Tipo VARCHAR(100),       Pale VARCHAR(100),        FechaFabricacion DATETIME,       Producto VARCHAR(100),                    
    NombreProducto VARCHAR(100),    DescripcionProducto VARCHAR(100),    DescripcionCortaProducto VARCHAR(100),    Envase VARCHAR(100),                    
    NombreEnvase VARCHAR(100),     NroEnvases DECIMAL(13,3),      Id_Partida INT,          PartidaEntrante VARCHAR(50),                    
	Id_UnidadLogistica INT,      UnidadLogistica VARCHAR(100),     Cantidad decimal(13,3),        Id_ArticuloDeLaPartida INT,                    
    PartidaOrigen VARCHAR(100),     Id_PartidaOrigen INT,       UL_Origen VARCHAR(100),        UbicacionOrigen VARCHAR(100),                    
	CantidadOrigen DECIMAL(13,3),    LineaProd VARCHAR(3),       NombreLineaProd VARCHAR(100),      Lote VARCHAR(30),                     
    DescripcionEnvase VARCHAR(100),    DescripcionCortaEnvase VARCHAR(15),             FechaParteProduccion DATETIME,      ParteProduccion VARCHAR(50),                     
    CodigoProveedorTrazabilidad VARCHAR(30),    NombreProveedorTrazabilidad VARCHAR(100),       PesoNormalizado DECIMAL(13,3),      CodigoPale VARCHAR(30),      
	NombrePale VARCHAR(100),     DescripcionPale VARCHAR(100),           DescripcionCortaPale VARCHAR(15),     NroPales INT,       
	Id_Articulo INT,       PesoBruto DECIMAL(12,3),      PesoNeto DECIMAL(12,3)      
 )                                   
                 
Create Index IX_#UnidadesLogisticas on #UnidadesLogisticas(Id_Partida, Id_Articulodelapartida, Id_UnidadLogistica)                    
Create Index IX2_#UnidadesLogisticas on #UnidadesLogisticas(Id_Partida, Id_UnidadLogistica)                    
      
Insert #UnidadesLogisticas (      
 Tipo,          Pale,           FechaFabricacion,         Producto,      
 NombreProducto,        DescripcionProducto,       DescripcionCortaProducto,       Envase,       
 NombreEnvase,        NroEnvases,          Id_Partida,           PartidaEntrante,      
 Id_UnidadLogistica,       UnidadLogistica,        Cantidad,           Id_ArticuloDeLaPartida,      
 PartidaOrigen,        Id_PartidaOrigen,        UL_Origen,           UbicacionOrigen,       
 CantidadOrigen,        LineaProd,          NombreLineaProd,         Lote,      
 DescripcionEnvase,       DescripcionCortaEnvase,       FechaParteProduccion,        ParteProduccion,       
 CodigoProveedorTrazabilidad,    NombreProveedorTrazabilidad,     PesoNormalizado,         CodigoPale,       
 NombrePale,         DescripcionPale,        DescripcionCortaPale,        NroPales,       
 Id_Articulo,        PesoBruto,          PesoNeto      
 )                    
Select  Distinct      
      
 'Fabricado' as Tipo, ANS.NumeroSerie Pale, P.FechaFabricacion AS FechaFabricacion, A.Codigo Producto, A.Nombre NombreProducto, A.Descripcion,                     
 A.DescripcionCorta, ENV.Envase, ENV.NombreEnvase, ENV.NroEnvases, P.Id Id_Partida, CONCAT(P.Serie,'/',P.Numero) PartidaEntrante,                 
 ANS.Id Id_UnidadLogistica, ANS.NumeroSerie UnidadLogistica, VAP.Cantidad, P.Id_Articulo Id_ArticuloDeLaPartida, D.Partida as PartidaOrigen, D.Id_Partida Id_PartidaOrigen,                    
 D.NumeroSerie UL_Origen, D.Ubicacion UbicacionOrigen, D.Cantidad CantidadOrigen, LP.Codigo as LineaProd, LP.Nombre as NombreLineaProd, VAP.Lote, ENV.Descripcion,                     
 ENV.DescripcionCorta, PPRS.Fecha, CONCAT(PP.Serie,'/',PP.Numero) ParteProduccion,                     
 (Select codigo from Proveedores where id = D.Id_ProveedorTrazabilidad),                     
 (Select s.Nombre+' '+s.PrimerApellido+ ' '+s.SegundoApellido FROM Proveedores P JOIN Sujetos s ON P.Id_Sujeto = S.Id where p.Id = D.Id_ProveedorTrazabilidad),                                 
 (Select PesoNormalizado from #PesosNormalizados PN where PN.Id_Articulo = A.id and PN.Id_Envase = ENV.id), PAL.Codigo, PAL.Nombre, PAL.Descripcion,                     
 PAL.DescripcionCorta, PAL.Cantidad, A.Id, VAP.PesoBruto, VAP.PesoNeto            
       
From PartesProduccionRealSalida PPRS                     
 inner join LineaProduccion LP on LP.Id = PPRS.Id_LugarProduccion and PPRS.TipoLugarProduccion = 1                     
 inner join PartesProduccionRealSalida_ArticulosProducidosLinea APL on APL.Id_PartesProduccionRealSalida = PPRS.Id                     
 left join PartesProduccion PP ON PP.Id_ParteProduccionReal = PPRS.Id_ParteProduccionReal                    
 inner join Articulos A on A.Id = PPRS.Id_Articulo and A.EsMateriaPrima = 1 -- solo materia prima                    
 inner join #ArticulosPartida AP on APL.Id_ArticulosProducidosLinea = AP.Id                    
 inner join #Partidas P on AP.Id_Partida = P.Id and P.Id_Articulo = AP.Id_Articulo                    
 inner join (                                      
      Select                    
     UUP.Id_ArticuloPartida, UUP.Id_Ubicacion, UUP.Id_UnidadLogistica, /*null,*/ UUP.Cantidad, '' as Lote, UUP.PesoBruto, UUP.PesoNeto                    
      From #UbicacionesunidadPartida UUP      
    ) VAP on AP.Id = VAP.Id_ArticuloPartida                      
 inner join Ubicaciones U on VAP.Id_Ubicacion = U.Id                    
 inner join ArticulosNumerosSerie ANS on ANS.Id = PPRS.Id_UnidadLogistica                     
 left join (                   
     Select PPRSDL.Id_PartesProduccionRealSalida, A.Id, A.Codigo Envase, A.Nombre NombreEnvase, DL.Cantidad NroEnvases, A.Descripcion, A.DescripcionCorta                    
     From PartesProduccionRealSalida_DesgloseLinea PPRSDL                     
      inner join DesgloseLineas DL on DL.Id = PPRSDL.Id_DesgloseLinea                     
      inner join Articulos A on A.Id = DL.Id_Articulo             
     where A.TipoArticulo = 1                    
    ) ENV on ENV.Id_PartesProduccionRealSalida = PPRS.Id                     
--> Datos origen                    
 outer apply (                    
     Select                     
      DO.Id_PartesProduccionRealSalida, AP.Id_Partida, CONCAT(P.Serie,'/',P.Numero) Partida, UB.Cantidad,                    
      UB.Id_UnidadLogistica, UB.NumeroSerie, UB.Ubicacion, DPR.Id_ProveedorTrazabilidad                     
     From PartesProduccionRealSalida_DatosOrigen DO                    
      inner join #ArticulosPartida AP on AP.Id = DO.Id_DatosOrigen                     
      inner join Articulos A on A.Id = AP.Id_Articulo and A.EsMateriaPrima = 1                    
      inner join Partidas P on P.Id = AP.Id_Partida                   
      inner join (                    
          Select Distinct UUP.Id_ArticuloPartida, UUP.Cantidad, UUP.Id_UnidadLogistica, ANS.NumeroSerie, U.Codigo Ubicacion                    
          From #UbicacionesUnidadPartida UUP      
           inner join Ubicaciones U on U.Id = UUP.Id_Ubicacion                     
           left join ArticulosNumerosSerie ANS on ANS.Id = UUP.Id_UnidadLogistica                                        
         ) UB on UB.Id_ArticuloPartida = AP.Id                     
      left join #DatosPartidasRecepciones DPR on DPR.Id_Partida = P.Id                    
     where DO.Id_PartesProduccionRealSalida = PPRS.Id                     
    ) D                    
  --> Información del artículo de tipo palé                    
  left join #InfoArtTipoPalePorPPRS PAL on PAL.Id_UnidadLogistica= ans.id                    
               
/*=======================================================================================================      
          TRASPASOS      
=========================================================================================================*/        
IF @IncluirTraspasos = 1                     
BEGIN                    
                    
SELECT                     
MA.Id Id_MA, MA.Fecha, LMA.Id Id_LMA, CMA.TipoClaveMovimiento, -- CMA.TipoClaveMovimiento = 0 /*TipoClaveMovimiento: 0 Entrada, 1 Salida*/                    
AP.Id_Articulo, P.Id Id_Partida, VAP.Id_UnidadLogistica, MAX(VAP.Id_Lote) Id_Lote, MAX(VAP.Id_Ubicacion) Id_Ubicacion, SUM(VAP.Cantidad) Cantidad, DPR.Id_ProveedorTrazabilidad,                    
ROW_NUMBER() OVER(PARTITION BY VAP.Id_UnidadLogistica, CMA.TipoClaveMovimiento ORDER BY VAP.Id_UnidadLogistica, CMA.TipoClaveMovimiento, MA.Fecha, LMA.Id) Orden                    
INTO #IdsT                    
FROM MovimientosAlmacen MA                    
 INNER JOIN LineasMovimientoAlmacen LMA ON MA.Id = LMA.Id_MovimientoAlmacen                    
INNER JOIN ClavesMovimientoAlmacen CMA ON LMA.Id_ClaveMovimientoAlmacen = CMA.Id                     
 INNER JOIN LineasMovimientoAlmacen_Partidas LMA_AP ON LMA.Id = LMA_AP.Id_LineasMovimientoAlmacen                    
 INNER JOIN #ArticulosPartida AP ON LMA_AP.Id_Partidas = AP.Id                    
 INNER JOIN Articulos A ON AP.Id_Articulo = A.Id AND A.EsMateriaPrima = 1   -- Selección de producto materia prima.                    
 INNER JOIN #Partidas P ON AP.Id_Partida = P.Id AND AP.Id_Articulo = P.Id_Articulo -- Selección del producto propio.                     
 INNER JOIN vwArticulosPartidaUbicaciones VAP ON AP.Id = VAP.Id_ArticuloPartida AND VAP.Id_UnidadLogistica > 0 -- Que tenga UL                    
 LEFT JOIN #DatosPartidasRecepciones DPR on DPR.id_partida = P.Id                                 
 LEFT JOIN (                    
    Select PPRS.Id_UnidadLogistica , AP.Id_Partida                     
    From PartesProduccionRealSalida PPRS                     
     inner join PartesProduccionRealSalida_ArticulosProducidosLinea APL on APL.Id_PartesProduccionRealSalida = PPRS.Id                     
     inner join ArticulosPartida AP on AP.Id = APL.Id_ArticulosProducidosLinea                     
     inner join Articulos A on A.Id = AP.Id_Articulo and A.EsMateriaPrima = 1                    
     ) FAB on FAB.Id_UnidadLogistica = VAP.Id_UnidadLogistica and AP.Id_Partida = FAB.Id_Partida                     
WHERE (MA.TipoDocumentoOrigen = 17 OR MA.TipoDocumentoOrigen = 0) /*TipoDocumentoOrigen: 17 Cambio de ubicación, 0 Manual*/                               
   AND MA.Fecha BETWEEN @FechaDesde AND @FechaHasta                       
   AND (CMA.TipoClaveMovimiento = 1 OR CMA.TipoClaveMovimiento = 0 AND Fab.Id_Partida  IS NULL)                    
GROUP BY VAP.Id_UnidadLogistica, MA.Fecha, MA.Id, LMA.Id, P.Id, AP.Id_Articulo, CMA.TipoClaveMovimiento, DPR.Id_ProveedorTrazabilidad                    
            
SELECT                     
TE.*, TS.Id_UnidadLogistica Id_UnidadLogisticaOrigen, TS.Id_Ubicacion Id_UbicacionOrigen                     
INTO #Traspasos                    
FROM #IdsT TE                    
INNER JOIN #IdsT TS ON TS.Id_MA = TE.Id_MA                     
    AND TS.Id_Partida = TE.Id_Partida                     
    AND TS.Id_Articulo = TE.Id_Articulo                     
    AND TS.Cantidad = TE.Cantidad                    
WHERE                    
 TE.TipoClaveMovimiento = 0                     
 AND TS.TipoClaveMovimiento = 1                    
 AND TE.Id_UnidadLogistica <> TS.Id_UnidadLogistica              

INSERT #UnidadesLogisticas (                    
 Tipo,          Pale,           FechaFabricacion,         Producto,      
 NombreProducto,        DescripcionProducto,       DescripcionCortaProducto,       Envase,      
 NombreEnvase,        NroEnvases,          Id_Partida,           PartidaEntrante ,      
 Id_UnidadLogistica,       UnidadLogistica,        Cantidad,           Id_ArticuloDeLaPartida,      
 PartidaOrigen,        Id_PartidaOrigen,        UL_Origen,           UbicacionOrigen,      
 CantidadOrigen,        LineaProd,          NombreLineaProd,         Lote,      
 DescripcionEnvase,       DescripcionCortaEnvase,       FechaParteProduccion,        ParteProduccion,       
 CodigoProveedorTrazabilidad,    NombreProveedorTrazabilidad,     PesoNormalizado,         CodigoPale,       
 NombrePale,         DescripcionPale,        DescripcionCortaPale,        NroPales,       
 Id_Articulo,        PesoBruto,          PesoNeto      
 )                 
SELECT Distinct                   
 'Traspaso' Tipo,                    
 ANS.NumeroSerie Pale, LN.FechaFabricacion FechaFabricacion, A.Codigo Producto, A.Nombre NombreProducto, A.Descripcion, A.DescripcionCorta,                       
 A_ENV.Codigo Envase, A_ENV.Nombre NombreEnvase, ENV.Cantidad NroEnvases, P.Id Id_Partida, CONCAT(P.Serie,'/',P.Numero) PartidaEntrante,      
 T.Id_UnidadLogistica, ANS.NumeroSerie UnidadLogistica,                    
 T.Cantidad, A.Id Id_ArticuloDeLaPartida,                     
 COALESCE(D.PartidaOrigen,CONCAT(P.Serie,'/',P.Numero)) PartidaOrigen, COALESCE( D.Id_PartidaOrigen, P.Id) Id_PartidaOrigen, COALESCE(ANS_O.NumeroSerie,'') UL_Origen,                   
 COALESCE( U_O.codigo,'') UbicacionOrigen,      
 CASE       
  WHEN D.id_PartidaOrigen IS Not null                    
  Then cast( (T.Cantidad *coalesce(D.PorcPartida,0))/100 as decimal(17,2))                    
  Else T.Cantidad                     
 END CantidadOrigen,      
 LN.Codigo LineaProd, LN.Nombre NombreLineaProd, COALESCE(L.Codigo, '') Lote, ENV.Descripcion, Env.DescripcionCorta, null, null,                    
 (select codigo from Proveedores where id = T.Id_ProveedorTrazabilidad),                     
 (Select s.Nombre+' '+s.PrimerApellido+ ' '+s.SegundoApellido FROM Proveedores p JOIN Sujetos s ON p.Id_Sujeto = s.Id where p.Id = T.Id_ProveedorTrazabilidad),                                 
 (select PesoNormalizado from  #PesosNormalizados PN where PN.id_articulo = a.id and pn.id_Envase = ENV.id_Envase),                    
 PAL.Codigo, PAL.Nombre, PAL.Descripcion, PAL.DescripcionCorta, PAL.Cantidad, A.Id, PROD.PesoBruto, PROD.PesoNeto                    
FROM #Traspasos T                    
 INNER JOIN #Partidas P ON T.Id_Partida = P.Id                    
 INNER JOIN Articulos A ON T.Id_Articulo = A.Id                    
 INNER JOIN ArticulosNumerosSerie ANS ON T.Id_UnidadLogistica = ANS.Id                    
 LEFT JOIN ArticulosNumerosSerie ANS_O ON T.Id_UnidadLogisticaOrigen = ANS_O.Id                    
 LEFT JOIN Ubicaciones U_O ON T.Id_UbicacionOrigen = U_O.Id         
--> Envase        
 LEFT JOIN (                    
     SELECT                    
      T.Id_LMA Id_LMA_Producto, T.Id_UnidadLogistica, MAX(AP.Id_Articulo) Id_Envase, SUM(VAP.Cantidad) Cantidad, A.Descripcion, A.DescripcionCorta , ap.Id_Partida                   
     FROM #Traspasos T                    
      INNER JOIN LineasMovimientoAlmacen LMA ON T.Id_MA = LMA.Id_MovimientoAlmacen                       
      INNER JOIN ClavesMovimientoAlmacen CMA ON LMA.Id_ClaveMovimientoAlmacen = CMA.Id AND CMA.TipoClaveMovimiento = 0 /*TipoClaveMovimiento: 0 Entrada, 1 Salida*/                    
      INNER JOIN LineasMovimientoAlmacen_Partidas LMA_AP ON LMA.Id = LMA_AP.Id_LineasMovimientoAlmacen                       
      INNER JOIN #ArticulosPartida AP ON LMA_AP.Id_Partidas = AP.Id AND T.Id_Partida = AP.Id_Partida                    
      INNER JOIN Articulos A ON AP.Id_Articulo = A.Id AND A.TipoArticulo = 1 /*TipoArticulo: 0 Pale, 1 Envase, 2 Producto*/                    
      INNER JOIN vwArticulosPartidaUbicaciones VAP ON AP.Id = VAP.Id_ArticuloPartida AND VAP.Id_UnidadLogistica = T.Id_UnidadLogistica                        
     GROUP BY T.Id_LMA, T.Id_UnidadLogistica, LMA.Id, A.Descripcion, A.DescripcionCorta   , AP.Id_Partida                   
    ) ENV ON T.Id_LMA = ENV.Id_LMA_Producto AND T.Id_UnidadLogistica = ENV.Id_UnidadLogistica  and ENV.Id_Partida=P.Id              
 LEFT JOIN Articulos A_ENV ON ENV.Id_Envase = A_ENV.Id                    
 LEFT JOIN Lotes L ON T.Id_Lote = L.Id                    
--> Datos Origen                    
 LEFT JOIN (                    
    Select                     
  AP.Id_Partida Id_PartidaFabridada, AP.Id_Articulo Id_Articulo, P.Id Id_PartidaOrigen, CONCAT(P.Serie,'/',P.Numero) PartidaOrigen,      
  UB.Cantidad, UB.Numeroserie, UB.Ubicacion, CAST(((UB.Cantidad * 100 ) / PPRS.Cantidad) as DECIMAL (12,2)) PorcPartida,                    
UB.PesoBruto, UB.PesoNeto                    
    From PartesProduccionRealSalida PPRS                     
  inner join PartesProduccionRealSalida_ArticulosProducidosLinea APL on APL.Id_PartesProduccionRealSalida = PPRS.Id                     
  inner join #ArticulosPartida AP on AP.Id = APL.Id_ArticulosProducidosLinea                     
  inner join Articulos on Articulos.Id = AP.Id_Articulo and Articulos.EsMateriaPrima = 1                    
  inner join PartesProduccionRealSalida_DatosOrigen DO on DO.Id_PartesProduccionRealSalida = PPRS.Id                     
  inner join ArticulosPartida AP_DO on AP_DO.Id = DO.Id_DatosOrigen                     
  inner join Articulos A on A.Id = AP_DO.Id_Articulo and A.EsMateriaPrima = 1                    
  inner join #Partidas P on P.Id = AP_DO.Id_Partida                     
  inner join (                    
     Select       
      UUP.Id_ArticuloPartida, UUP.Cantidad, UUP.Id_UnidadLogistica, ANS.NumeroSerie,       
      U.Codigo Ubicacion, UUP.PesoBruto, UUP.PesoNeto                    
     From #UbicacionesUnidadPartida UUP      
      inner join Ubicaciones U on U.Id = UUP.Id_Ubicacion                     
      left join ArticulosNumerosSerie ANS on ANS.Id = UUP.Id_UnidadLogistica        
     ) UB on UB.Id_ArticuloPartida = AP_DO.Id                     
     ) D on D.id_PartidaFabridada = P.Id         
--> Palet      
 LEFT JOIN (                    
    Select       
     A.Codigo, A.Nombre, A.Descripcion, A.DescripcionCorta,                    
     UUP.Cantidad, ANS.NumeroSerie, UUP.Id_UnidadLogistica,                    
     UUP.PesoBruto,UUP.PesoNeto                    
    From #Traspasos T                    
     inner join MovimientosAlmacen MA ON MA.Id = T.Id_MA                    
     inner join LineasMovimientoAlmacen LMA on LMA.Id_MovimientoAlmacen= MA.Id                    
     inner join ClavesMovimientoAlmacen CLA on CLA.Id = LMA.Id_ClaveMovimientoAlmacen                    
     inner join LineasMovimientoAlmacen_Partidas LMAP on LMAP.Id_LineasMovimientoAlmacen = LMA.Id                    
     inner join #ArticulosPartida AP on AP.Id = LMAP.Id_Partidas                    
     inner join #Partidas P on P.Id = AP.Id_Partida                    
     inner join Articulos A on A.Id = AP.Id_Articulo                    
     inner join #UbicacionesUnidadPartida UUP on UUP.Id_ArticuloPartida = AP.Id and UUP.Cantidad>0                    
     inner join ArticulosNumerosSerie ANS on ANS.Id = UUP.Id_UnidadLogistica                    
    Where  A.TipoArticulo = 0                
    ) PAL ON PAL.Id_UnidadLogistica = T.Id_UnidadLogisticaOrigen         
--> Producto      
 LEFT JOIN (                    
      Select       
       A.Codigo, A.Nombre, A.Descripcion, A.DescripcionCorta, UUP.Cantidad, ANS.NumeroSerie, UUP.Id_UnidadLogistica,                    
       UUP.PesoBruto, UUP.PesoNeto, P.Id  Id_Partida                 
      FROM #Traspasos T                    
     inner join Movimientosalmacen ma ON MA.Id = T.Id_MA                    
       inner join LineasMovimientoAlmacen LMA on LMA.Id_MovimientoAlmacen= MA.Id                    
       inner join ClavesMovimientoAlmacen CLA on CLA.Id = LMA.Id_ClaveMovimientoAlmacen                    
       inner join LineasMovimientoAlmacen_Partidas lmap on LMAP.Id_LineasMovimientoAlmacen = LMA.Id                    
       inner join #ArticulosPartida AP on AP.Id = LMAP.Id_Partidas                    
       inner join #Partidas P on P.Id = AP.Id_Partida                    
       inner join Articulos A on A.Id = AP.Id_Articulo                    
       inner join #UbicacionesUnidadPartida UUP on UUP.Id_ArticuloPartida = AP.Id and UUP.Cantidad>0                    
       inner join ArticulosNumerosSerie ANS on ANS.Id = UUP.Id_UnidadLogistica                    
      Where CLA.TipoClaveMovimiento = 0 and A.EsMateriaPrima = 1                    
    ) PROD ON PROD.Id_UnidadLogistica = ANS.Id  and  PROD.Id_Partida = P.Id        
--> Lineas de los Traspasos      
 LEFT JOIN (      
    SELECT DISTINCT LP.Codigo, LP.Nombre, P.FechaFabricacion, P.Id FROM PartesProduccionRealSalida pprs                     
     inner join LineaProduccion LP on LP.Id = PPRS.Id_LugarProduccion and PPRS.TipoLugarProduccion = 1                     
     inner join PartesProduccionRealSalida_ArticulosProducidosLinea APL on APL.Id_PartesProduccionRealSalida = PPRS.Id                     
     left join PartesProduccion PP ON PP.Id_ParteProduccionReal = PPRS.Id_ParteProduccionReal                    
     inner join Articulos A on A.Id = PPRS.Id_Articulo and A.EsMateriaPrima = 1                  
     inner join #ArticulosPartida AP on APL.Id_ArticulosProducidosLinea = AP.Id                    
     inner join #Partidas P on AP.Id_Partida = P.Id and P.Id_Articulo = AP.Id_Articulo      
    WHERE P.Fecha BETWEEN @FechaDesde and @FechaHasta      
    ) LN ON LN.Id = P.ID      
                    
END      
                          
/*=======================================================================================================      
          REPROCESADOS      
=========================================================================================================*/                    
Select UL.Id_UnidadLogistica, ANS.NumeroSerie                    
Into #OrigenReprocesadoAux                    
From #UnidadesLogisticas UL                    
 inner join #UbicacionesUnidadPartida U on U.Id_UnidadLogistica = UL.Id_UnidadLogistica                    
 inner join PartesProduccionRealSalida_ArticulosProducidosLinea APL on APL.Id_ArticulosProducidosLinea = U.Id_ArticuloPartida                    
 inner join PartesProduccionRealSalida_OrigenesReprocesado POR on POR.Id_PartesProduccionRealSalida = APL.Id_PartesProduccionRealSalida                    
 inner join #UbicacionesUnidadPartida UO on UO.Id_ArticuloPartida = POR.Id_OrigenesReprocesado                    
 inner join ArticulosNumerosSerie ANS on ANS.Id = UO.Id_UnidadLogistica                    
group by UL.Id_UnidadLogistica, ANS.NumeroSerie                    

Select U.Id_UnidadLogistica, STUFF((Select ',' + O.NumeroSerie From #OrigenReprocesadoAux O Where O.Id_UnidadLogistica = U.Id_UnidadLogistica for xml path('')),1,1,'') NumerosSerieOrigenReprocesado                    
Into #OrigenReprocesado                    
From #UnidadesLogisticas U                    
Group by U.Id_UnidadLogistica            
            
/*=======================================================================================================      
          PARTIDAS ORIGEN      
=========================================================================================================*/       
      
CREATE TABLE #DatosPartidasOrigen (      
 Id_Partida INT,     PartidaOrigen VARCHAR(10),   Id_Cultivo INT,      Id_Finca INT,           NroGuiaRecepcion_BCA VARCHAR(25),      
    LOTE VARCHAR(20),    NomLote VARCHAR(50),    DesLote VARCHAR(50),    Recepcion VARCHAR(20),          
    Proveedor VARCHAR(20),   NombreProveedor VARCHAR(100),  PesoXEnvase DECIMAL(10,3),   Cultivo VARCHAR(20) ,          
    Referencia_Lote VARCHAR(20), VariedadCultivo VARCHAR(20),  FechaCosecha DATE,     NroGuiaRecepcion_ICA VARCHAR(25)      
 )          
          
INSERT INTO #DatosPartidasOrigen           
--> Tabla temporal de partidas origen.                    
Select Distinct             
 AP.Id_Partida, CONCAT(P.Serie,'/',P.Numero) PartidaOrigen, P.Id_Cultivo, C.Id_Finca,        
 CASE       
        WHEN CHARINDEX('-', DR.Referencia) > 0       
            THEN SUBSTRING(DR.Referencia, CHARINDEX('-', DR.Referencia) + 1, LEN(DR.Referencia))      
        ELSE NULL      
    END AS NroGuiaRecepcion_BCA,         
 FI.Codigo LOTE, FI.Nombre NomLote, FI.Descripcion DesLote, CONCAT(DR.Serie,'/',DR.Numero) Recepcion,           
 PRO.Codigo Proveedor, dbo.Nombre(PRO.Id_Sujeto) NombreProveedor,                     
 CONVERT(DECIMAL(10,3), (LRCA.PesoNeto / COALESCE( ENV.Cantidad,1))) PesoXEnvase,                    
 COALESCE( C.Descripcion,'') Cultivo, COALESCE( C.Referencia,'') Referencia_Lote,                  
 COALESCE( artcul.Nombre,'') as VariedadCultivo,      
 --> Fecha Cosecha      
 (SELECT DISTINCT DCV.Valor AS FechaCosecha FROM Partidas_DatosComplementarios PDC          
   INNER JOIN DatoComplementarioValor DCV ON PDC.Id_DatosComplementarios = DCV.Id         
   INNER JOIN DatosComplementarios DC ON DC.Id = DCV.Id_DatoComplementario         
 WHERE DC.Id=50000057  AND PDC.Id_Partidas = P.Id) FechaCosecha,      
 --> N° Guias de Recepcion      
 (SELECT DISTINCT DCV.Valor AS NroGuiaRep FROM Partidas_DatosComplementarios PDC          
   INNER JOIN DatoComplementarioValor DCV ON PDC.Id_DatosComplementarios = DCV.Id         
   INNER JOIN DatosComplementarios DC ON DC.Id = DCV.Id_DatoComplementario         
 WHERE DC.Id=50000210  AND PDC.Id_Partidas = P.Id) NroGuiaRecepcion_ICA      
From DocumentosRecepcion DR                     
 inner join Proveedores PRO on PRO.Id = DR.Id_Proveedor                     
 inner join LineasRecepcion LR on LR.Id_DocumentoRecepcion = DR.Id                    
 left join (                    
     Select LRADL.Id_LineasRecepcionArticulo, SUM(Case when DL.Cantidad=0 then 1 else DL.Cantidad end) Cantidad                    
     From LineasRecepcionArticulo_DesgloseLinea LRADL                     
      inner join DesgloseLineas DL on DL.Id = LRADL.Id_DesgloseLinea                     
      inner join Articulos ENV on ENV.Id = DL.Id_Articulo and ENV.TipoArticulo = 1                    
     GROUP BY LRADL.Id_LineasRecepcionArticulo                    
    ) ENV on ENV.Id_LineasRecepcionArticulo = LR.Id                 
 inner join LineasRecepcionComercializacionArticulo LRCA on LRCA.Id_LineaRecepcionArticulo = LR.Id                     
 inner join #LineasRecepcion_ArticulosRecibidos LRAR on LRAR.Id_LineasRecepcion = LR.Id                     
 inner join #ArticulosPartida AP on AP.Id = LRAR.Id_ArticulosRecibidos                     
 inner join #UnidadesLogisticas U on U.Id_PartidaOrigen = AP.Id_Partida                    
 inner join Articulos A on A.Id = AP.Id_Articulo and A.EsMateriaPrima= 1                    
 inner join Partidas P on P.id = ap.id_partida                    
 left join Cultivos C on C.id = P.id_Cultivo                     
 left join Articulos artcul on artcul.id = C.Id_Articulo              
 left join Fincas FI ON FI.Id = C.Id_Finca           
 
/*=======================================================================================================      
         UNIDADES LOGISTICAS ALMACENES      
=========================================================================================================*/         
create table #UnidadesLogisticas_Almacenes (Id_UnidadLogistica int,                 
            Id_Partida int,                 
            AlmacenEntradaCodigo varchar(max),                 
            NombreAlmacenEntrada varchar(max))                
 insert #UnidadesLogisticas_Almacenes                
 select distinct                
  #UnidadesLogisticas.id_unidadlogistica, ap.Id_Partida , a.Codigo, a.Nombre                
 from #UnidadesLogisticas                 
  inner join PartesProduccionRealSalida pprs on #UnidadesLogisticas.id_unidadlogistica=pprs.Id_UnidadLogistica                
  inner join PartesProduccionRealSalida_ArticulosProducidosLinea apl on apl.Id_PartesProduccionRealSalida = pprs.id                 
  inner join #articulospartida ap on ap.id = apl.Id_ArticulosProducidosLinea                 
  inner join articulos on articulos.id = ap.Id_Articulo and articulos.EsMateriaPrima = 1                
  inner join Almacenes a on pprs.Id_Almacen=a.Id                
 union                
 select distinct                
  #UnidadesLogisticas.id_unidadlogistica, ap.Id_Partida , a.Codigo, a.Nombre                
 from #UnidadesLogisticas                 
  inner join LineasRecepcionComercializacionPesada_UnidadesLogisticas lrcp_ul on #UnidadesLogisticas.id_unidadlogistica=lrcp_ul.Id_UnidadesLogisticas                
  inner join LineasRecepcionComercializacionPesada lrcp on lrcp_ul.Id_LineasRecepcionComercializacionPesada=lrcp.Id                
  inner join LineasRecepcionComercializacionArticulo lrca on lrcp.Id_LineaRecepcionComercializacionArticulo=lrca.Id_LineaRecepcionArticulo                
  inner join LineasRecepcionArticulo lra on lrca.Id_LineaRecepcionArticulo=lra.Id_LineaRecepcion                
  inner join Almacenes a on lra.Id_AlmacenDestino=a.Id                
  inner join #LineasRecepcion_ArticulosRecibidos lrar on lrar.Id_LineasRecepcion = lra.Id_LineaRecepcion                 
  inner join #ArticulosPartida ap on ap.id = lrar.Id_ArticulosRecibidos                 
  inner join articulos on articulos.id = ap.Id_Articulo and articulos.EsMateriaPrima = 1                
  inner join #UbicacionesUnidadPartida uup on uup.Id_ArticuloPartida = ap.id                 
  inner join articulosnumerosserie ans on ans.id = uup.Id_UnidadLogistica and ans.id = #UnidadesLogisticas.id_unidadlogistica                 
    
/*=======================================================================================================      
         PALET CON PARTIDAS DE CONFECCION      
=========================================================================================================*/       
      
  SELECT Id_UnidadLogistica, UL.Pale,UL.Id_Partida INTO #UL_Partidas  FROM #UnidadesLogisticas UL -- traigo solo los palets con sus partidas de confeccion         
      
/*=======================================================================================================      
   CANTIDADES CORRECTAS DE ENVASES Y PRODUCTO TRAIDOS DE UBICIONES UNIDAD PARTIDA      
=========================================================================================================*/       
      
;WITH UltimoArticulo AS (      
    SELECT       
        UL.Id_UnidadLogistica,       
        PA.Id AS Id_Partida,       
        A.Id Id_Envase,       
        UUP.Cantidad,       
        AP.Id AS Id_ArticuloPartida,      
        ROW_NUMBER() OVER (      
            PARTITION BY UL.Id_UnidadLogistica, PA.Id, A.Id       
            ORDER BY AP.Id DESC      
        ) AS rn      
    FROM #UbicacionesUnidadPartida UUP      
    INNER JOIN #ArticulosPartida AP ON AP.ID = UUP.Id_ArticuloPartida      
    INNER JOIN #Partidas PA ON PA.ID = AP.Id_Partida      
    INNER JOIN ARTICULOS A ON A.Id = AP.Id_Articulo      
    INNER JOIN #UL_Partidas UL ON UL.Id_Partida = PA.Id       
        AND UL.Id_UnidadLogistica = UUP.Id_UnidadLogistica      
    WHERE A.TipoArticulo = 1      
          
)      
SELECT       
    Id_UnidadLogistica,       
    Id_Partida,       
    Id_Envase,       
    Cantidad,       
    Id_ArticuloPartida      
INTO #CajasRecientes      
FROM UltimoArticulo      
WHERE rn = 1;      
                  
;WITH UltimoArticulo AS (      
    SELECT       
        UL.Id_UnidadLogistica,       
        PA.Id AS Id_Partida,       
        A.Id Id_Envase,       
        UUP.Cantidad,       
        AP.Id AS Id_ArticuloPartida,      
        ROW_NUMBER() OVER (      
            PARTITION BY UL.Id_UnidadLogistica, PA.Id, A.Id       
            ORDER BY AP.Id DESC      
        ) AS rn      
    FROM #UbicacionesUnidadPartida UUP      
    INNER JOIN #ArticulosPartida AP ON AP.ID = UUP.Id_ArticuloPartida      
    INNER JOIN #Partidas PA ON PA.ID = AP.Id_Partida      
    INNER JOIN ARTICULOS A ON A.Id = AP.Id_Articulo      
    INNER JOIN #UL_Partidas UL ON UL.Id_Partida = PA.Id       
        AND UL.Id_UnidadLogistica = UUP.Id_UnidadLogistica      
    WHERE A.TipoArticulo = 2      
           
)      
SELECT       
    Id_UnidadLogistica,       
    Id_Partida,       
    Id_Envase,       
    Cantidad,       
    Id_ArticuloPartida      
INTO #KilosRecientes      
FROM UltimoArticulo      
WHERE rn = 1;      
      
/*=======================================================================================================      
 CALIBRE Y CATEGORIA    
=========================================================================================================*/   
  
;WITH CCar AS (  
    SELECT  
        AC.Id_Articulo,  
        C.Id            AS IdCaracteristica,  
        ROW_NUMBER() OVER (  
            PARTITION BY AC.Id_Articulo  
            ORDER BY C.Id  
        ) AS rn,  
        CASE C.TipoDato  
            WHEN 0 THEN AC.ValorAlfanumerico  
            WHEN 1 THEN CLV.DescripcionCorta  
            WHEN 2 THEN CONVERT(varchar(50), AC.ValorNumerico)  
        END AS Valor  
    FROM ArticulosCaracteristica AC  
    INNER JOIN Caracteristicas C ON AC.Id_Caracteristica = C.Id  
    LEFT JOIN CaracteristicasListaValores CLV ON AC.Id_ValorLista = CLV.Id  
    WHERE AC.Fecha IS NULL  
)  
SELECT  
    Id_Articulo,  
    MAX(CASE WHEN rn = 1 THEN ISNULL(Valor,'') END) AS Categoria,  
    MAX(CASE WHEN rn = 2 THEN ISNULL(Valor,'') END) AS Calibre  
INTO #ArticulosCategoriaCalibre  
FROM CCar  
GROUP BY Id_Articulo;  
  
CREATE CLUSTERED INDEX IX_#ArtCatCal_Articulo ON #ArticulosCategoriaCalibre (Id_Articulo);  
      
/*=======================================================================================================      
         SELECT PRINCIPAL      
=========================================================================================================*/          
Select Distinct       
--> Tabla Unidades Logisticas      
CASE      
  WHEN U.NombreLineaProd like '%P1%' THEN 'P1'      
  WHEN U.NombreLineaProd like '%P2%' THEN 'P2'      
  WHEN U.NombreLineaProd like '%P3%' THEN 'P3'      
END Packing,      
U.Id_Partida, U.Tipo, U.Pale, U.LineaProd, U.NombreLineaProd, U.FechaFabricacion, U.Producto CodigoProducto,                   
U.NombreProducto, U.DescripcionProducto, U.DescripcionCortaProducto, U.Envase CodigoEnvase, U.NombreEnvase,       
U.DescripcionEnvase, U.DescripcionCortaEnvase, U.NroEnvases, COALESCE(Marcas.Nombre,'') as Marca,                     
U.CodigoPale, U.NombrePale, U.DescripcionPale, U.DescripcionCortaPale, U.NroPales, U.PartidaEntrante,                              
U.Cantidad, U.PesoBruto, U.PesoNeto, U.PesoNormalizado, U.UL_Origen, U.UbicacionOrigen, U.FechaParteProduccion, U.ParteProduccion, U.Id_PartidaOrigen,      
U.PartidaOrigen, U.CantidadOrigen, U.CodigoProveedorTrazabilidad, U.NombreProveedorTrazabilidad, U.Lote LoteUL, U.Id_UnidadLogistica, 
--> Categoria y Calibre
ACC.Categoria, ACC.Calibre,   
      
--> Unidades Logsiticas Almacenes      
 #UnidadesLogisticas_Almacenes.AlmacenEntradaCodigo AlmacenEntrada,                
 #UnidadesLogisticas_Almacenes.NombreAlmacenEntrada,        
      
--> Tabla de Familias Articulo      
FA.Codigo CodigoFamilia, FA.Nombre NombreFamilia,                     
(Select Codigo from vFamiliasNiveles where id in (select * from dbo.Split(vfa.Niveles, ',')) AND Level=2) CodigoFamiliaN2,                    
(Select Nombre from vFamiliasNiveles where id in (select * from dbo.Split(vfa.Niveles, ',')) AND Level=2) NombreFamilaN2,                    
(Select Codigo from vFamiliasNiveles where id in (select * from dbo.Split(vfa.Niveles, ',')) AND Level=3) CodigoFamiliaN3,                    
(Select Nombre from vFamiliasNiveles where id in (select * from dbo.Split(vfa.Niveles, ',')) AND Level=3) NombreFamilaN3,       
(Select Codigo from vFamiliasNiveles where id in (select * from dbo.Split(vfa.Niveles, ',')) AND Level=4) CodigoFamiliaN4,      
(Select Nombre from vFamiliasNiveles where id in (select * from dbo.Split(vfa.Niveles, ',')) AND Level=4) NombreFamiliaN4,      
      
--> Puntos de Paletizado       
(Select TOP 1 PuntoPaletizado.Codigo From PuntoPaletizado                     
 join PuntoPaletizadoRegistro on PuntoPaletizadoRegistro.Id_PuntoPaletizado = PuntoPaletizado.id                     
 join ArticulosNumerosSerie on ArticulosNumerosSerie.id = PuntoPaletizadoRegistro.Id_ArticuloNumeroSerie                    
 where ArticulosNumerosSerie.id = ans.Id) CodigoPuntoPaletizado,                    
(Select TOP 1 PuntoPaletizado.Nombre From PuntoPaletizado                     
 join PuntoPaletizadoRegistro on PuntoPaletizadoRegistro.Id_PuntoPaletizado = PuntoPaletizado.id                     
 join ArticulosNumerosSerie on ArticulosNumerosSerie.id = PuntoPaletizadoRegistro.Id_ArticuloNumeroSerie                    
 where ArticulosNumerosSerie.id = ans.Id) NombrePuntoPaletizado,                     
                    
CASE WHEN E.Cantidad is null THEN 'NO' ELSE 'SI' END EnExistencias,       
-->Existencia      
ISNULL(EP.Cantidad, KR.Cantidad) ExProducto,       
ISNULL(EE.Cantidad, CR.Cantidad) ExEnvases,                                 
CONVERT(DECIMAL(10,2), ROUND(U.CantidadOrigen / CASE WHEN isnull(dpo.PesoxEnvase,1)=0 then 1 else isnull(dpo.PesoxEnvase,1) end,2)) CajasOrigen,       
      
--> Datos Partidas Origen      
DPO.Proveedor CodigoProveedor, DPO.NombreProveedor, DPO.LOTE, DPO.NomLote, DPO.DesLote, DPO.Referencia_Lote LotePar_Red,                   
DPO.VariedadCultivo, DPO.FechaCosecha,        
      
--> Reservas      
R.FechaPedido, R.FechaSalidaPedidoVenta, R.FechaEntregaPedidoVenta, R.Pedido, R.NombreClientePedido, R.DireccionEnvioPedido,                     
R.Linea LineaPedido, R.EnvasesPorPalet, R.Confeccion, R.CodigoConfeccion, R.NombreEnvio,  R.Id_Pedido, R.Destino,          
      
--> Albaranes      
V.FechaAlbaran, V.Albaran, V.NombreClienteAlbarán, V.DireccionEnvioAlbaran, V.Linea LineaAlbaran,                    
coalesce(orp.NumerosSerieOrigenReprocesado,'') NumerosSerieOrigenReprocesado,                    
E.almacen, E.nombreAlmacen, E.ubicacion, E.nombreUbicacion, E.NumeroZonas,                
ANS.Observaciones                               
Into #PART          
From #UnidadesLogisticas U                     
 inner join #Partidas P on P.Id = U.Id_Partida                     
 inner join ArticulosNumerosSerie ANS on ANS.Id = U.Id_UnidadLogistica                     
 left join Articulos A on A.Id = P.Id_Articulo and A.TipoArticulo = 0                    
 left join Marcas on Marcas.id = P.Id_Marca                     
--> Familia del producto                    
 inner join Articulos AF on AF.Id = U.Id_ArticuloDeLaPartida                      
 left join FamiliasArticulo FA on AF.Id_Familia=FA.Id                               
--> Existencias actuales de producto                    
 left join #ExistenciasProducto EP on EP.id_ARticulo = U.id_ArticuloDeLaPartida and EP.Id_partida = U.id_partida and EP.Id_UnidadLogistica = U.Id_UnidadLogistica                     
--> Existencias actuales de envases                    
 left join #ExistenciasEnvase EE on EE.Id_partida = U.id_Partida   and EE.Id_UnidadLogistica = U.Id_UnidadLogistica                     
--> Datos de partidas origen                    
 left join #DatosPartidasOrigen DPO on DPO.id_partida = U.Id_PartidaOrigen            
--> Existencias            
 left join (                    
     Select Distinct       
      AE.id_partida, AE.Id_UnidadLogistica , AE.cantidad, AL.Codigo Almacen, AL.Nombre NombreAlmacen,                
      U.Codigo ubicacion, U.Nombre nombreUbicacion,  U.NumeroZonas                   
     From AcumuladoExistencias AE                     
      inner join Partidas P on P.id = AE.Id_Partida                     
      inner join Almacenes AL on AL.Id = AE.Id_Almacen                     
      inner join Ubicaciones U on U.Id = AE.Id_Ubicacion                    
     Where AE.Id_Articulo = P.Id_Articulo and  AE.Cantidad >0                    
    ) E on E.Id_Partida = U.Id_Partida and E.Id_UnidadLogistica = U.Id_UnidadLogistica        
--> Cantidades correctas de Ubicaciones unidad Partida      
LEFT JOIN #CajasRecientes CR ON CR.Id_Partida=U.Id_Partida AND CR.Id_UnidadLogistica=U.Id_UnidadLogistica      
LEFT JOIN #KilosRecientes KR ON KR.Id_Partida=U.Id_Partida AND KR.Id_UnidadLogistica=U.Id_UnidadLogistica      
--> Datos de reservas                    
 outer apply (select top 1 re.*                    
      from #ReservasUL Re                    
      where Re.Id_Partida = U.id_partida and Re.id_unidadlogistica = U.Id_UnidadLogistica                     
     ) R                     
--> Datos de ventas                    
 left join #VentasUL V on V.Id_Partida = U.id_partida and V.id_unidadlogistica = U.Id_UnidadLogistica                     
 left join #OrigenReprocesado ORP on ORP.Id_UnidadLogistica= U.Id_UnidadLogistica                                  
 join vFamiliasNiveles VFA ON VFA.Id = FA.Id         
 left join #UnidadesLogisticas_Almacenes on #UnidadesLogisticas_Almacenes.Id_UnidadLogistica=U.id_unidadlogistica and #UnidadesLogisticas_Almacenes.id_partida = U.id_partida              
 LEFT JOIN #ArticulosCategoriaCalibre ACC ON ACC.Id_Articulo = U.Id_Articulo  

WHERE 
E.NombreUbicacion not like '%DESPACHO%' 
and E.NombreUbicacion not like '%TUNEL%' 
and E.NombreUbicacion not Like '%CONFECCION%'
and (U.FechaFabricacion BETWEEN @FechaDesde and (DATEADD(SECOND, -1, DATEADD(DAY, 1, @FechaHasta))))
	
    
/*=======================================================================================================
									CONCATENAR LOTE
=========================================================================================================*/  
;WITH B AS (
    SELECT DISTINCT
        Id_Partida,
        Lote,
        NomLote,
        DesLote,
        LotePar_Red,
        VariedadCultivo
    FROM #PART
),
Agg AS (
    SELECT
        Id_Partida,
        Lote            = STRING_AGG(Lote, ';')
    FROM (SELECT DISTINCT Id_Partida, Lote FROM B) x
    GROUP BY Id_Partida
),
Agg2 AS (
    SELECT
        Id_Partida,
        NomLote         = STRING_AGG(NomLote, ';')
    FROM (SELECT DISTINCT Id_Partida, NomLote FROM B) x
    GROUP BY Id_Partida
),
Agg3 AS (
    SELECT
        Id_Partida,
        DesLote         = STRING_AGG(DesLote, ';')
    FROM (SELECT DISTINCT Id_Partida, DesLote FROM B) x
    GROUP BY Id_Partida
),
Agg4 AS (
    SELECT
        Id_Partida,
        LotePar_Red     = STRING_AGG(LotePar_Red, ';')
    FROM (SELECT DISTINCT Id_Partida, LotePar_Red FROM B) x
    GROUP BY Id_Partida
),
Agg5 AS (
    SELECT
        Id_Partida,
        VariedadCultivo = STRING_AGG(VariedadCultivo, ';')
    FROM (SELECT DISTINCT Id_Partida, VariedadCultivo FROM B) x
    GROUP BY Id_Partida
)
SELECT
    sb.Id_Partida,
    a.Lote,
    b2.NomLote,
    b3.DesLote,
    b4.LotePar_Red,
    b5.VariedadCultivo
INTO #LoteOrigen
FROM (SELECT DISTINCT Id_Partida FROM #PART) sb
LEFT JOIN Agg  a  ON a.Id_Partida  = sb.Id_Partida
LEFT JOIN Agg2 b2 ON b2.Id_Partida = sb.Id_Partida
LEFT JOIN Agg3 b3 ON b3.Id_Partida = sb.Id_Partida
LEFT JOIN Agg4 b4 ON b4.Id_Partida = sb.Id_Partida
LEFT JOIN Agg5 b5 ON b5.Id_Partida = sb.Id_Partida;

/*=======================================================================================================      
        FECHA FABRICACION DE PARTIDA      
=========================================================================================================*/       
DECLARE @HoraVolcado Varchar(6)      
SET @HoraVolcado=(SELECT  pe.valor Valor FROM ParametrosEntorno pe        
     INNER JOIN  DescripcionParametrosEntorno dpe on pe.Id_DefinicionParametro = dpe.Id        
     INNER JOIN NivelesFuncionales nf on nf.Id = pe.Id_NivelFuncional        
     INNER JOIN GruposEmpresariales ge on ge.id = pe.Id_NivelEstructuralGrupoEmpresarial        
     WHERE  dpe.Id=2959)        
        
SELECT DISTINCT PA.Id, MIN(PA.FechaFabricacion) FechaFabricacion,        
CAST(CASE         
     WHEN CONVERT(TIME, MIN(PA.FechaFabricacion)) >= @HoraVolcado THEN MIN(PA.FechaFabricacion)        
     ELSE DATEADD(DAY, -1, MIN(PA.FechaFabricacion))        
     END AS DATE ) AS FechaProceso        
        
INTO #FechaPartida              
FROM #PART PAR              
INNER JOIN Partidas PA ON PA.Id=PAR.id_partida             
GROUP BY PA.Id  
             
/*=======================================================================================================      
        SELECT #PART      
=========================================================================================================*/        
SELECT  DISTINCT       
 Packing, Tipo, Pale, LineaProd, NombreLineaProd, --Id_PartidaOrigen, PartidaOrigen,      
 PART.FechaCosecha, FP.FechaFabricacion, FP.FechaProceso, CodigoProducto, NombreAlmacen, CodigoFamiliaN4, NombreFamiliaN4,      
 Nombreproducto,Descripcionproducto,Categoria,Calibre, CodigoFamilia, NombreFamilia,CodigoFamiliaN2, NombreFamilaN2,       
 CodigoFamiliaN3, codigoEnvase,NombreEnvase, DescripcionEnvase,NroEnvases, Marca, CodigoPale, NombrePale, NombreAlmacenEntrada,      
 DescripcionPale,       
 --> Numero de Palet's con decimales      
  (NroEnvases/EnvasesPorPalet) AS NroPales,      
 --> Numero de Contenedor totales por pedido       
  (EnvasesPorPalet*20) TotalCajasXCont,      
 --> Numero de Contenedores      
  (NroEnvases/(EnvasesPorPalet*20)) AS NroCont,      
 --> Se extrae la presentacion dentro de los parentesis      
  CASE       
  WHEN CHARINDEX('(', NombreEnvase) > 0 AND CHARINDEX(')', NombreEnvase) > CHARINDEX('(', NombreEnvase)      
   THEN SUBSTRING(NombreEnvase, CHARINDEX('(', NombreEnvase) + 1, CHARINDEX(')', NombreEnvase) - CHARINDEX('(', NombreEnvase) - 1)      
  ELSE NULL      
  END AS PRESENTACION,      
 CodigoPuntoPaletizado, NombrePuntoPaletizado, Cantidad,PesoBruto,PesoNeto, PesoNormalizado, UL_Origen, EnExistencias,          
 CodigoProveedor, NombreProveedor, LO.LOTE, LO.NomLote, LO.DesLote, LO.LotePar_Red, LO.VariedadCultivo, fechaPedido, Id_Pedido,         
 FechaSalidaPedidoVenta, FechaEntregaPedidoVenta, Pedido, NombreClientePedido, DireccionEnvioPedido, LineaPedido, EnvasesPorPalet,       
 Confeccion, CodigoConfeccion, NombreEnvio, Almacen, Ubicacion, nombreUbicacion, NumeroZonas, Id_UnidadLogistica , Destino,         
 CONVERT(DATE, ANS.FechaFabricacion) FechaConfeccionPalet, CONVERT(TIME,ANS.FechaFabricacion) HoraConfeccionPalet,FechaAlbaran, Albaran,ExEnvases, ExProducto,      
--> /* DATOS COMPLEMENTARIOS */      
 (SELECT TOP 1 DCV.Valor  from PedidosVenta_DatosComplementarios AVDC                                            
  INNER JOIN DatoComplementarioValor DCV ON DCV.Id=AVDC.Id_DatosComplementarios       
  INNER JOIN DatosComplementarios DC ON DC.Id=DCV.Id_DatoComplementario                                            
 WHERE DC.Id=1327 and AVDC.Id_PedidosVenta= Id_Pedido) COD_SAP,      
 (SELECT TOP 1 DCV.Valor  from PedidosVenta_DatosComplementarios AVDC                                            
  INNER JOIN DatoComplementarioValor DCV ON DCV.Id=AVDC.Id_DatosComplementarios                                            
  INNER JOIN DatosComplementarios DC ON DC.Id=DCV.Id_DatoComplementario                                            
 WHERE DC.Id=50000117 and AVDC.Id_PedidosVenta= Id_Pedido) PackingSalida,      
 (SELECT TOP 1 DCV.Valor  from PedidosVenta_DatosComplementarios AVDC                                            
  INNER JOIN DatoComplementarioValor DCV ON DCV.Id=AVDC.Id_DatosComplementarios                                            
  INNER JOIN DatosComplementarios DC ON DC.Id=DCV.Id_DatoComplementario                                            
 WHERE DC.Id=50000145 and AVDC.Id_PedidosVenta= Id_Pedido) NroContenedor,      
 (SELECT TOP 1 DCV.Valor  from PedidosVenta_DatosComplementarios AVDC                                            
  INNER JOIN DatoComplementarioValor DCV ON DCV.Id=AVDC.Id_DatosComplementarios                                            
  INNER JOIN DatosComplementarios DC ON DC.Id=DCV.Id_DatoComplementario                                            
 WHERE DC.Id=50000146 and AVDC.Id_PedidosVenta= Id_Pedido) StatusContenedor,      
 (SELECT TOP 1 DCV.Valor  from PedidosVenta_DatosComplementarios AVDC                                            
  INNER JOIN DatoComplementarioValor DCV ON DCV.Id=AVDC.Id_DatosComplementarios                                            
  INNER JOIN DatosComplementarios DC ON DC.Id=DCV.Id_DatoComplementario                                            
 WHERE DC.Id=50000061 and AVDC.Id_PedidosVenta= Id_Pedido) PuertoCarga 
 
Into #SF      
FROM #PART PART          
 LEFT JOIN #LoteOrigen LO ON LO.Id_Partida = PART.Id_Partida          
 INNER JOIN #FechaPartida FP ON FP.Id = PART.Id_Partida AND LO.Id_Partida = FP.Id          
 INNER JOIN (Select Id, FechaFabricacion from ArticulosNumerosSerie) as ANS on ANS.Id = PART.id_unidadlogistica          
Where       
 CodigoFamiliaN3 = @Cultivo       
 and NombreProducto not like '%MERCADO NACIONAL%'      
 and NombreProducto not like '%DESCARTE%'      
 and NombreProducto not like '%MATERIA SECA%'      
 and NombreProducto not like '%VIDA ANAQUEL%'      
 and Calibre not like '%MCDO NACIONAL%'      
 --and Packing = @Packing      
 and Id_Pedido is not null      
 and EnExistencias = 'SI'  
 and Albaran is null
ORDER BY Pale      
      
--Select * from #PART /*      
--Select * from #SF where Pedido = '1PV/841'      
/*=======================================================================================================      
          TABLA RANGO DE FECHAS      
=========================================================================================================*/      
--> Por Palet      
Select       
 Id_UnidadLogistica, Pale, MIN(FechaProceso) FechaMinPale, MAX(FechaProceso) FechaMaxPale      
INTO #RF_XPalet      
from #SF Group by Id_UnidadLogistica, Pale      
      
--> Por Pedido      
Select       
 Id_Pedido, Pedido, MIN(FechaProceso) FechaMinPedido, MAX(FechaProceso) FechaMaxPedido      
INTO #RF_XPedido      
from #SF Group by Id_Pedido, Pedido      
      
/*==============================================================================      
     SELECT  PRINCIPAL DE #SF - #PART      
================================================================================*/      
Select       
 SF.Packing, SF.Tipo, SF.Pale, SF.LineaProd, SF.NombreLineaProd,   
 SF.FechaCosecha, SF.FechaProceso, SF.CodigoProducto, SF.NombreAlmacen, SF.CodigoFamiliaN4, SF.NombreFamiliaN4,      
 SF.Nombreproducto,SF.Descripcionproducto,SF.Categoria,SF.Calibre, SF.CodigoFamilia, SF.NombreFamilia,SF.CodigoFamiliaN2, SF.NombreFamilaN2,       
 SF.CodigoFamiliaN3, SF.codigoEnvase,SF.NombreEnvase, SF.DescripcionEnvase,SF.NroEnvases, SF.Marca, SF.CodigoPale, SF.NombrePale, SF.NombreAlmacenEntrada,      
 SF.DescripcionPale, SF.NroPales, SF.TotalCajasXCont, SF.NroCont, SF.CodigoPuntoPaletizado, SF.NombrePuntoPaletizado, SF.Cantidad,SF.PesoBruto,SF.PesoNeto, SF.PesoNormalizado, SF.UL_Origen, SF.EnExistencias,          
 SF.CodigoProveedor, SF.NombreProveedor,SF.LOTE, SF.NomLote, SF.DesLote, SF.LotePar_Red, SF.VariedadCultivo, SF.fechaPedido,  SF.Id_Pedido,         
 SF.FechaSalidaPedidoVenta, SF.FechaEntregaPedidoVenta, SF.Pedido, SF.NombreClientePedido, SF.DireccionEnvioPedido, SF.LineaPedido, SF.EnvasesPorPalet,       
 SF.Confeccion, SF.CodigoConfeccion, SF.NombreEnvio, SF.Almacen, SF.Ubicacion, SF.nombreUbicacion, SF.NumeroZonas, SF.Id_UnidadLogistica , SF.Destino,         
 SF.FechaConfeccionPalet, SF.HoraConfeccionPalet,SF.FechaAlbaran, SF.Albaran,SF.ExEnvases, SF.ExProducto,      
 SF.COD_SAP, SF.PackingSalida, SF.NroContenedor, SF.StatusContenedor, SF.PuertoCarga, RP.FechaMinPale, RP.FechaMaxPale, RF.FechaMinPedido, RF.FechaMaxPedido, SF.PRESENTACION,      
 CASE      
  WHEN NombreUbicacion like '%CONFECCI%' THEN 'ZONA CONFECCION'      
  WHEN NombreUbicacion like '%TUNEL 01%' THEN 'TUNEL 01'      
  WHEN NombreUbicacion like '%TUNEL 02%' THEN 'TUNEL 02'      
  WHEN NombreUbicacion like '%TUNEL 03%' THEN 'TUNEL 03'      
  WHEN NombreUbicacion like '%TUNEL 04%' THEN 'TUNEL 04'      
  WHEN NombreUbicacion like '%TUNEL 05%' THEN 'TUNEL 05'      
  WHEN NombreUbicacion like '%TUNEL 06%' THEN 'TUNEL 06'      
  WHEN NombreUbicacion like '%TUNEL 07%' THEN 'TUNEL 07'      
  WHEN NombreUbicacion like '%TUNEL 08%' THEN 'TUNEL 08'      
  WHEN NombreUbicacion like '%TUNEL 09%' THEN 'TUNEL 09'      
  WHEN NombreUbicacion like '%TUNEL 10%' THEN 'TUNEL 10'      
  WHEN NombreUbicacion like '%TUNEL 11%' THEN 'TUNEL 11'      
  WHEN NombreUbicacion like '%TUNEL 12%' THEN 'TUNEL 12'      
  WHEN NombreUbicacion like '%TUNEL 13%' THEN 'TUNEL 13'      
  WHEN NombreUbicacion like '%TUNEL 14%' THEN 'TUNEL 14'      
  WHEN NombreUbicacion like '%TUNEL 15%' THEN 'TUNEL 15'      
  WHEN NombreUbicacion like '%TUNEL 16%' THEN 'TUNEL 16' 
  WHEN NombreUbicacion like '%PSM1-C01%' THEN 'CAMARA 1'      
  WHEN NombreUbicacion like '%CAMARA 01%' THEN 'CAMARA 1'      
  WHEN NombreUbicacion like '%CAMARA 02%' THEN 'CAMARA 2'      
  WHEN NombreUbicacion like '%CAMARA 03%' THEN 'CAMARA 3'      
  WHEN NombreUbicacion like '%CAMARA 04%' THEN 'CAMARA 4'      
  WHEN NombreUbicacion like '%CAMARA 05%' THEN 'CAMARA 5'      
  WHEN NombreUbicacion like '%CAMARA 06%' THEN 'CAMARA 6' 
  WHEN NombreUbicacion like '%CAMARA DE SALDOS%' THEN 'CAMARA SALDOS'    
  WHEN NombreUbicacion like '%DESPACHO%' THEN 'ZONA DESPACHO'      
 END UbicacionesPacking,      
 CASE      
  --> Packing 1      
  WHEN SF.Packing = 'P1' AND SF.nombreUbicacion like '%CAMARA 1%' THEN CAST(140 AS INT)      
  WHEN SF.Packing = 'P1' AND SF.nombreUbicacion like '%CAMARA 3%' THEN CAST(320 AS INT)      
  WHEN SF.Packing = 'P1' AND SF.nombreUbicacion like '%CAMARA 4%' THEN CAST(420 AS INT)      
  WHEN SF.Packing = 'P1' AND SF.nombreUbicacion like '%CAMARA 5%' THEN CAST(240 AS INT)           
  --> Packing 2      
  WHEN SF.Packing = 'P2' AND SF.nombreUbicacion like '%CAMARA 1%' THEN CAST(140 AS INT)      
  WHEN SF.Packing = 'P2' AND SF.nombreUbicacion like '%CAMARA 3%' THEN CAST(320 AS INT)      
  WHEN SF.Packing = 'P2' AND SF.nombreUbicacion like '%CAMARA 4%' THEN CAST(420 AS INT)      
  WHEN SF.Packing = 'P2' AND SF.nombreUbicacion like '%CAMARA 5%' THEN CAST(240 AS INT)      
  --> Packing 3      
  WHEN SF.Packing = 'P3' AND SF.nombreUbicacion like '%CAMARA 01%' THEN CAST(420 AS INT)      
  WHEN SF.Packing = 'P3' AND SF.nombreUbicacion like '%CAMARA 02%' THEN CAST(400 AS INT)      
  WHEN SF.Packing = 'P3' AND SF.nombreUbicacion like '%CAMARA 03%' THEN CAST(420 AS INT)      
  WHEN SF.Packing = 'P3' AND SF.nombreUbicacion like '%CAMARA 04%' THEN CAST(240 AS INT)      
  WHEN SF.Packing = 'P3' AND SF.nombreUbicacion like '%CAMARA 05%' THEN CAST(100 AS INT)      
  WHEN SF.Packing = 'P3' AND SF.nombreUbicacion like '%DESPACHO%' THEN CAST(160 AS INT)      

 END CapacidadCamara,
 DATEDIFF(DAY, RP.FechaMinPale, SYSDATETIME()) DiasCPT,
 DATEDIFF(DAY, RF.FechaMinPedido, SYSDATETIME()) DiasPedido

into #SSF      
from #SF SF      
 LEFT JOIN #RF_XPalet RP on RP.Id_UnidadLogistica = SF.Id_UnidadLogistica      
 LEFT JOIN #RF_XPedido RF on RF.Id_Pedido = SF.Id_Pedido      
where StatusContenedor not like '%DESPACHADO%' Or StatusContenedor is null      
    
Select * from #SSF
order by Id_Pedido, Pale  

/*=======================================================================================================      
        DEPURACION DE TABLAS TEMPORALES      
=========================================================================================================*/          
 IF OBJECT_ID('tempdb..#DatosPartidasRecepciones') IS NOT NULL BEGIN DROP TABLE #DatosPartidasRecepciones END                    
 IF OBJECT_ID('tempdb..#partidas') IS NOT NULL BEGIN DROP TABLE #partidas END                    
 IF OBJECT_ID('tempdb..#Articulospartida') IS NOT NULL BEGIN DROP TABLE #Articulospartida END                    
 IF OBJECT_ID('tempdb..#Reservas_ArticulosReservados') IS NOT NULL BEGIN DROP TABLE #Reservas_ArticulosReservados END                    
 IF OBJECT_ID('tempdb..#LineasDocumentoEnvio_ArticulosEnviados') IS NOT NULL BEGIN DROP TABLE #LineasDocumentoEnvio_ArticulosEnviados END                    
 IF OBJECT_ID('tempdb..#LineasRecepcion_ArticulosRecibidos') IS NOT NULL BEGIN DROP TABLE #LineasRecepcion_ArticulosRecibidos END                    
 IF OBJECT_ID('tempdb..#ExistenciasProducto') IS NOT NULL BEGIN DROP TABLE #ExistenciasProducto END                    
 IF OBJECT_ID('tempdb..#ExistenciasEnvase') IS NOT NULL BEGIN DROP TABLE #ExistenciasEnvase END                    
 IF OBJECT_ID('tempdb..#ReservasUL') IS NOT NULL BEGIN DROP TABLE #ReservasUL END                    
 IF OBJECT_ID('tempdb..#VentasUL') IS NOT NULL BEGIN DROP TABLE #VentasUL END                    
 IF OBJECT_ID('tempdb..#UnidadesLogisticas') IS NOT NULL BEGIN DROP TABLE #UnidadesLogisticas END                    
 IF OBJECT_ID('tempdb..#CombinacionesArticuloEnvase') IS NOT NULL BEGIN DROP TABLE #CombinacionesArticuloEnvase END                    
 IF OBJECT_ID('tempdb..#PesosNormalizados') IS NOT NULL BEGIN DROP TABLE #PesosNormalizados END                    
 IF OBJECT_ID('tempdb..#InfoArtTipoPalePorPPRS') IS NOT NULL BEGIN DROP TABLE #InfoArtTipoPalePorPPRS END                    
 IF OBJECT_ID('tempdb..#OrigenReprocesadoAux') IS NOT NULL BEGIN DROP TABLE #OrigenReprocesadoAux END                    
 IF OBJECT_ID('tempdb..#OrigenReprocesado') IS NOT NULL BEGIN DROP TABLE #OrigenReprocesado END                    
 IF OBJECT_ID('tempdb..#DatosPartidasOrigen') IS NOT NULL BEGIN DROP TABLE #DatosPartidasOrigen END                    
 IF OBJECT_ID('tempdb..#ProtocolosCalidad') IS NOT NULL BEGIN DROP TABLE #ProtocolosCalidad END                    
 IF OBJECT_ID('tempdb..#CreateTable') IS NOT NULL BEGIN DROP TABLE #CreateTable END                    
 IF OBJECT_ID('tempdb..#NumerosSerieDC') IS NOT NULL BEGIN DROP TABLE #NumerosSerieDC END                    
 IF OBJECT_ID('tempdb..#PIVOT') IS NOT NULL BEGIN DROP TABLE #PIVOT END                    
 IF OBJECT_ID('tempdb..#UnidadesLogisticas_Almacenes') IS NOT NULL BEGIN DROP TABLE #UnidadesLogisticas_Almacenes END                     
 IF OBJECT_ID('tempdb..#PART') IS NOT NULL BEGIN DROP TABLE #PART END                    
 IF OBJECT_ID('tempdb..#IdsT') IS NOT NULL BEGIN DROP TABLE #IdsT END           
 IF OBJECT_ID('tempdb..#Traspasos') IS NOT NULL BEGIN DROP TABLE #Traspasos END          
 IF OBJECT_ID('tempdb..#PartidasVolcadas') IS NOT NULL BEGIN DROP TABLE #PartidasVolcadas END          
 IF OBJECT_ID('tempdb..#LoteOrigen') IS NOT NULL BEGIN DROP TABLE #LoteOrigen END          
 IF OBJECT_ID('tempdb..#FechaPartida') IS NOT NULL BEGIN DROP TABLE #FechaPartida END         
 IF OBJECT_ID('tempdb..#Volcado') IS NOT NULL BEGIN DROP TABLE #Volcado END          
 IF OBJECT_ID('tempdb..#Recepcion') IS NOT NULL BEGIN DROP TABLE #Recepcion END          
 IF OBJECT_ID('tempdb..#SF') IS NOT NULL BEGIN DROP TABLE #SF END        
 IF OBJECT_ID('tempdb..#SSF') IS NOT NULL BEGIN DROP TABLE #SSF END        
 IF OBJECT_ID('tempdb..#RES') IS NOT NULL BEGIN DROP TABLE #RES END          
 IF OBJECT_ID('tempdb..#Resumen') IS NOT NULL BEGIN DROP TABLE #Resumen END         
 IF OBJECT_ID('tempdb..#RF_XPalet') IS NOT NULL BEGIN DROP TABLE #RF_XPalet END          
 IF OBJECT_ID('tempdb..#Detalle') IS NOT NULL BEGIN DROP TABLE #Detalle END      
 IF OBJECT_ID('tempdb..#MOV') IS NOT NULL BEGIN DROP TABLE #MOV END      
 IF OBJECT_ID('tempdb..#Historial') IS NOT NULL BEGIN DROP TABLE #Historial END      
 IF OBJECT_ID('tempdb..#RF_XPedido') IS NOT NULL BEGIN DROP TABLE #RF_XPedido END         
 IF OBJECT_ID('tempdb..#PV') IS NOT NULL BEGIN DROP TABLE #PV END        
 IF OBJECT_ID('tempdb..#UL_Partidas') IS NOT NULL BEGIN DROP TABLE #UL_Partidas END       
 IF OBJECT_ID('tempdb..#CajasRecientes') IS NOT NULL BEGIN DROP TABLE #CajasRecientes END       
 IF OBJECT_ID('tempdb..#KilosRecientes') IS NOT NULL BEGIN DROP TABLE #KilosRecientes END       
 IF OBJECT_ID('tempdb..#UbicacionesUnidadPartida') IS NOT NULL BEGIN DROP TABLE #UbicacionesUnidadPartida END 
 IF OBJECT_ID('tempdb..#ArticulosCategoriaCalibre') IS NOT NULL BEGIN DROP TABLE #ArticulosCategoriaCalibre END 
 IF OBJECT_ID('tempdb..#RangoFechas') IS NOT NULL BEGIN DROP TABLE #RangoFechas END 

 
