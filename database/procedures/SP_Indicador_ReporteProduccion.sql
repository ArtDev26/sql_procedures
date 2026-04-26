     
/* ======================================================================================================       
Proyecto: 
    ERP Agro

Procedimiento:
    SP_Indicador_ReporteProduccion.sql

Autor:
    Arturo Escalante - Analista de Informacion y Procesos

Descripcion:
     Procedimiento orientado a la producción en procesos agroindustriales de packing.

     Consolida información operativa en tiempo real relacionada con kilos recepcionados,
     kilos volcados y kilos confeccionados, permitiendo analizar el desempeño
     productivo por fecha, packing, cultivo, variedad, lote, categoría y calibre.

Objetivo: 
    Brindar una vista consolidada para reportes operativos, control de
    producción y soporte a la toma de decisiones.

Parametros:
    @FechaDesde - Fecha Inicial del analisis.
    @FechaHasta - Fecha Final del analisis.
    @Cultivo - Codigo de cultivo a evaluar.
    @Packing - Packing o planta de proceso

Principales Caracteristicas Tecnicas:
     - Uso de tablas temporales para segmentar etapas del proceso.
     - Creación de índices temporales para mejorar rendimiento.
     - Integración de información de recepción, volcado y confección.
     - Consolidación de KPIs operativos.
     - Filtros dinámicos por fecha, cultivo y packing.

Nota: 
    Este script fue adaptado y anonimizado para fines demostrativos de portafolio.
    No contiene credenciales, datos reales ni información sensible de empresa.
====================================================================================================== */       
        
/*=======================================================================================================        
           DECLARACION DE VARIABLES        
=========================================================================================================*/        
        
DECLARE @FechaDesde Datetime = '20260121', @FechaHasta datetime = '20260121', @Cultivo varchar(5) = '2'     
        
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
--> Optimizacion de Tablas para consultas mas rapidas        
         
 --> Partidas        
  SELECT P.*, A.Nombre Articulo        
  INTO #Partidas         
  FROM Partidas P        
   inner join Articulos A on A.Id = P.Id_Articulo        
   inner join FamiliasArticulo F1 on F1.Id = A.Id_Familia        
   inner join FamiliasArticulo F2 on F2.Id = F1.Id_FamiliaSuperior        
   inner join FamiliasArticulo F3 on F3.Id = F2.Id_FamiliaSuperior and F3.Codigo = @Cultivo        
  WHERE P.Fecha BETWEEN  @FechaDesde and @FechaHasta      
    
 CREATE NONCLUSTERED INDEX IX_#Partidas_ArticuloFecha ON #Partidas (Id_Articulo, Fecha);  
  
 --> ArticulosPartida        
  SELECT AP.* INTO #ArticulosPartida FROM ArticulosPartida AP                      
   JOIN #Partidas P ON P.Id = AP.Id_Partida   
     
 CREATE CLUSTERED INDEX IX_#ArticulosPartida_Id ON #ArticulosPartida (Id);  
 CREATE NONCLUSTERED INDEX IX_#ArticulosPartida_PartidaArticulo ON #ArticulosPartida (Id_Partida, Id_Articulo);  
        
 --> Reservas_ArticulosReservados        
  SELECT * INTO #Reservas_ArticulosReservados FROM Reservas_ArticulosReservados RAR        
   JOIN #ArticulosPartida AP on AP.Id = RAR.Id_ArticulosReservados        
        
 --> LineasDocumentoEnvio_ArticulosEnviados         
  SELECT * INTO #LineasDocumentoEnvio_ArticulosEnviados FROM LineasDocumentoEnvio_ArticulosEnviados LAE        
   JOIN #ArticulosPartida AP on AP.Id = LAE.Id_ArticulosEnviados        
        
 --> LineasRecepcion_ArticulosRecibidos        
  SELECT * INTO #LineasRecepcion_ArticulosRecibidos FROM LineasRecepcion_ArticulosRecibidos LAR        
   JOIN #ArticulosPartida AP on AP.Id = LAR.Id_ArticulosRecibidos        
          
 --> UbicacionesUnidadPartida        
  SELECT UUP.* INTO #UbicacionesUnidadPartida FROM UbicacionesUnidadPartida UUP        
   inner join #ArticulosPartida AP on AP.Id = UUP.Id_ArticuloPartida     
     
   CREATE CLUSTERED INDEX IX_#UUP_ArticuloPartida ON #UbicacionesUnidadPartida (Id_ArticuloPartida, Id_UnidadLogistica);  
   CREATE NONCLUSTERED INDEX IX_#UUP_UL ON #UbicacionesUnidadPartida (Id_UnidadLogistica);  
        
/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++   
                             RECEPCION        
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/        
        
/*=======================================================================================          
  TABLA UBICACIONES UNIDAD PARTIDA FILTRADA POR FECHA FAB.PARTIDA Y ALMACEN          
=========================================================================================*/          
          
Select Distinct          
 UUP.Id_ArticuloPartida, UUP.Id_Ubicacion, U.Nombre Ubicacion,          
 UUP.Id_UnidadLogistica, ANS.NumeroSerie,UUP.Cantidad, UUP.PesoNeto, UUP.PesoBruto,           
 AP.Id_Articulo, A.Nombre Articulo, A.Descripcion DescArticulo, A.TaraCompras, A.TaraVentas,          
 F1.Nombre F1, F2.Nombre F2, F3.Nombre F3, F3.Codigo CodF3,          
 AP.Id_Partida, CONCAT(P.Serie,'/',P.Numero) Partidas          
into #UbicacionesUnidadPart          
from UbicacionesUnidadPartida UUP          
 inner join ArticulosPartida AP on AP.Id = UUP.Id_ArticuloPartida          
 inner join Articulos A on A.Id = AP.Id_Articulo          
 inner join Partidas P on P.Id = AP.Id_Partida          
 inner join FamiliasArticulo F1 on F1.Id = A.Id_Familia          
 inner join FamiliasArticulo F2 on F2.Id = F1.Id_FamiliaSuperior          
 inner join FamiliasArticulo F3 on F3.Id = F2.Id_FamiliaSuperior           
 inner join Ubicaciones U on U.Id = UUP.Id_Ubicacion 
 inner join ArticulosNumerosSerie ANS on ANS.Id = UUP.Id_UnidadLogistica          
Where P.Fecha Between @FechaDesde and @FechaHasta         
               
/*=======================================================================================          
  TABLA CANTIDADES POR MOVIMIENTO DE ALMACEN Y UBICACIONES UNIDAD PARTIDA          
=========================================================================================*/          
          
Select Distinct          
 LMA.Id_MovimientoAlmacen, MA.TipoDocumentoOrigen, CMA.Codigo Cod, CMA.Nombre,  MA.Id_DocumentoOrigen, MA.Fecha, MA.Id_Centro, LMA.Id_Almacen,          
 LMA.Id_Articulo,  LMA.NombreArticulo, LMA.DescripcionArticulo, LMA.FechaOperacion, LMA.CantidadTotal, AP.Id_Partida,          
 UUP.Id_UnidadLogistica, UUP.NumeroSerie,LMA.Cantidad CantidadMovAlmacen, UUP.Cantidad CantidadUUP, UUP.PesoNeto PesoNetoUUP,          
 UUP.F1, UUP.F2, UUP.F3, UUP.TaraCompras, UUP.TaraVentas, UUP.CodF3, UUP.Id_Ubicacion, UUP.Ubicacion          
into #MovAlmacen          
from MovimientosAlmacen MA          
 inner join LineasMovimientoAlmacen LMA on LMA.Id_MovimientoAlmacen = MA.Id          
 inner join LineasMovimientoAlmacen_Partidas LMAP on LMAP.Id_LineasMovimientoAlmacen = LMA.Id          
 inner join ClavesMovimientoAlmacen CMA on CMA.Id = LMA.Id_ClaveMovimientoAlmacen          
 inner join ArticulosPartida AP on AP.Id = LMAP.Id_Partidas          
 inner join #UbicacionesUnidadPart UUP on  UUP.Id_ArticuloPartida = AP.Id           
Order by UUP.NumeroSerie          
        
/*=======================================================================================          
  TABLA ENVASES, PALET Y KILOS          
=========================================================================================*/          
          
;WITH ENV AS (          
 Select           
  Id_DocumentoOrigen, Id_Centro, Id_Almacen, Id_Articulo, NombreArticulo, DescripcionArticulo, CodF3,          
   Id_Partida, Id_UnidadLogistica, NumeroSerie,CantidadTotal,CantidadMovAlmacen, CantidadUUP, TaraCompras, TaraVentas          
 from #MovAlmacen Where TipoDocumentoOrigen = 2 and CodF3 = 'ENV'          
),          
PAL AS (          
 Select           
  Id_DocumentoOrigen, Id_Centro, Id_Almacen, Id_Articulo, NombreArticulo, DescripcionArticulo, CodF3,          
   Id_Partida, Id_UnidadLogistica, NumeroSerie,CantidadTotal,CantidadMovAlmacen, CantidadUUP, TaraCompras, TaraVentas          
 from #MovAlmacen Where TipoDocumentoOrigen = 2 and CodF3 = 'C'          
),          
KG AS (          
 Select           
  Id_DocumentoOrigen, Id_Centro, Id_Almacen, Id_Articulo, NombreArticulo, DescripcionArticulo, CodF3,          
   Id_Partida, Id_UnidadLogistica, NumeroSerie,CantidadTotal,CantidadMovAlmacen, CantidadUUP, TaraCompras, TaraVentas          
 from #MovAlmacen Where TipoDocumentoOrigen = 2 and CodF3 = @Cultivo          
)          
Select          
 ENV.Id_DocumentoOrigen, ENV.Id_Centro, ENV.Id_Almacen, ENV.Id_Articulo IdEnv, ENV.NombreArticulo NombreEnv, ENV.DescripcionArticulo DescEnv, ENV.TaraCompras TaraCEnv, ENV.TaraVentas TaraVEnv,          
 ENV.Id_Partida, ENV.Id_UnidadLogistica, ENV.NumeroSerie, ENV.CantidadUUP NroEnvases,          
 PAL.Id_Articulo IdPal, COALESCE(PAL.NombreArticulo,'SIN PALLET') NombrePal, COALESCE(PAL.DescripcionArticulo,'S/P') DescPal, COALESCE(PAL.TaraCompras,0) TaraCPal, COALESCE(PAL.TaraVentas,0) TaraVPal, COALESCE(PAL.CantidadUUP,1) NroPalet,          
 KG.Id_Articulo IdArticulo, KG.NombreArticulo NombreArticulo, KG.DescripcionArticulo DescArticulo, KG.CantidadUUP Kilos          
Into #Cant          
From ENV           
 left join PAL on PAL.Id_DocumentoOrigen = ENV.Id_DocumentoOrigen and PAL.Id_Centro = ENV.Id_Centro and PAL.Id_Almacen = ENV.Id_Almacen And PAL.Id_UnidadLogistica = ENV.Id_UnidadLogistica          
 left join KG on KG.Id_DocumentoOrigen = ENV.Id_DocumentoOrigen and KG.Id_Centro = ENV.Id_Centro and KG.Id_Almacen = ENV.Id_Almacen And KG.Id_UnidadLogistica = ENV.Id_UnidadLogistica          
         
/*=======================================================================================          
 DATOS COMPLEMENTARIOS DE LAS PARTIDAS         
=========================================================================================*/          
        
;WITH DC_ALL AS (          
 SELECT PDC.Id_Partidas, DC.Id IdDato, DCV.Valor FROM Partidas_DatosComplementarios PDC          
  INNER JOIN DatoComplementarioValor DCV ON DCV.Id = PDC.Id_DatosComplementarios                
  INNER JOIN DatosComplementarios DC ON DC.Id = DCV.Id_DatoComplementario           
),          
DC_PIVOT AS (          
 Select           
  Id_Partidas,          
  MAX(CASE WHEN IdDato = 50000057 THEN Valor END) AS FechaCosecha,          
  MAX(CASE WHEN IdDato = 50000210 THEN Valor END) AS NroGuia_Ica          
 from DC_ALL          
 Group by Id_Partidas          
)          
Select * Into #DCP from DC_PIVOT          
/*=======================================================================================          
  TABLA DETALLE RECEPCCION CON ENVASES, PALET Y KILOS          
=========================================================================================*/          
          
Select Distinct          
 DR.Id Id_DR, PUL.Id_LineasRecepcionComercializacionPesada, LRA.Id_LineaRecepcion, LRA.Id_Articulo,LRA.NombreArticulo NombreArticuloRecepcionado,LRA.UnidadesEnvase KgXEnv, LRA.CantidadTotal KgTotalRecepcion,CONVERT(DATE,LRA.FechaRecepcion) FechaRecepcion,
        
 CONVERT(DATE,DCP.FechaCosecha) FechaCosecha,A.Nombre Articulo, AP.Id_Partida, CONCAT(P.Serie, '/',P.Numero) Partidas, C.Referencia SubLote, F.Codigo Lote,  F.Descripcion VariedadValidacion,        
 CONCAT(DR.Serie,'/',DR.Numero) Recepcion, DR.Id_Centro, CE.Codigo Centro, DR.Id_AlmacenDestino, AL.Nombre AlmacenOrigen, DR.NombreProveedor, DR.FechaCreacion, DR.Usuario, DR.Id_UbicacionDefecto, U.Nombre Ubicacion,          
 PUL.Id_UnidadesLogisticas, CA.NumeroSerie, LRCP.Cantidad KgPalet, LRCP.PesoNeto PesoNetoPalet,          
 CA.NombreArticulo , CA.DescArticulo, CA.Kilos, CA.NombreEnv,CA.DescEnv, CA.TaraCEnv, CA.TaraVEnv, CA.NroEnvases,          
 CA.NombrePal, CA.DescPal, CA.TaraCPal, CA.TaraVPal, CA.NroPalet,        
 CASE        
 WHEN AL.Nombre like '%P2%' then 'P2'        
 WHEN AL.Nombre like '%P1%' then 'P1'  
 WHEN AL.Nombre like '%P3%' then 'P3'
 END Packing        
Into #Recepcion        
from LineasRecepcionComercializacionPesada_UnidadesLogisticas PUL          
 inner join LineasRecepcionComercializacionPesada LRCP on LRCP.Id = PUL.Id_LineasRecepcionComercializacionPesada           
 inner join LineasRecepcionArticulo LRA on LRA.Id_LineaRecepcion = LRCP.Id_LineaRecepcionComercializacionArticulo        
 inner join LineasRecepcion LR on LR.Id = LRA.Id_LineaRecepcion          
 inner join DocumentosRecepcion DR on DR.Id = LR.Id_DocumentoRecepcion      
 inner join LineasRecepcion_ArticulosRecibidos AR on AR.Id_LineasRecepcion = LR.Id          
 inner join ArticulosPartida AP on AP.Id = AR.Id_ArticulosRecibidos          
 inner join Articulos A on A.Id = AP.Id_Articulo and A.EsMateriaPrima = 1          
 inner join Partidas P on P.Id = AP.Id_Partida          
 inner join Cultivos C on C.Id = P.Id_Cultivo          
 inner join Fincas F on F.Id = C.Id_Finca          
 inner join #Cant CA on CA.Id_UnidadLogistica = PUL.Id_UnidadesLogisticas           
 inner join Ubicaciones U on U.Id = DR.Id_UbicacionDefecto          
 inner join Almacenes AL on AL.Id = DR.Id_AlmacenDestino          
 inner join Centros CE on CE.Id = DR.Id_Centro         
 left join #DCP DCP on DCP.Id_Partidas = P.Id        
        
/*=======================================================================================          
  FECHA INICIO Y FIN DE RECEPCION POR FECHA PROCESO         
=========================================================================================*/         
;WITH FR AS (        
 Select Packing, CONVERT(DATE,Dr.Fecha) FechaProceso, DR.FechaCreacion from DocumentosRecepcion DR        
 inner join #Recepcion R on R.Id_DR = DR.Id        
)        
Select FR.Packing,  FR.FechaProceso, MIN(FechaCreacion) FIni_Recep, MAX(FechaCreacion)FFin_Recep         
into #FRE From FR        
wHERE FR.FechaProceso between @FechaDesde and @FechaHasta        
Group by FR.Packing, FR.FechaProceso        
        
--Select * from #FRE        
        
/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++   
                   VOLCADO       
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/      
        
 DECLARE @IdGrupoEmpresarial INT  = 1           
DECLARE @HastaFechaConHora DATETIME       
                
/*####################################################################################          
      OBTENER UNIDAD DE MEDIDA PARA PESOS                   
#####################################################################################*/          
DECLARE @idUnidadMedidaGeneral INT          
IF exists (SELECT valor FROM ParametrosEntorno WHERE Id_DefinicionParametro = 284 and Id_NivelEstructuralGrupoEmpresarial = @IdGrupoEmpresarial and Id_NivelFuncional = 29)  -- Buscamos primero en comercialización          
BEGIN           
 SET @idUnidadMedidaGeneral = (SELECT id FROM UnidadesMedida WHERE Id_GrupoEmpresarial = @IdGrupoEmpresarial and Codigo=(        
 SELECT valor FROM ParametrosEntorno WHERE Id_DefinicionParametro = 284 and Id_NivelEstructuralGrupoEmpresarial = 1 and Id_NivelFuncional = 29))          
END           
ELSE          
IF exists (SELECT valor FROM ParametrosEntorno WHERE Id_DefinicionParametro = 284 and Id_NivelEstructuralGrupoEmpresarial = @IdGrupoEmpresarial and Id_NivelFuncional = 28)  -- Luego buscamos a nivel de agro          
BEGIN           
 SET @idUnidadMedidaGeneral = (SELECT id FROM UnidadesMedida WHERE Id_GrupoEmpresarial = @IdGrupoEmpresarial and Codigo=(        
 SELECT valor FROM ParametrosEntorno WHERE Id_DefinicionParametro = 284 and Id_NivelEstructuralGrupoEmpresarial = 1 and Id_NivelFuncional = 29))          
END          
          
/*####################################################################################          
     PARTIDAS O NUMEROS SERIE RECEPCIONADOS          
#####################################################################################*/          
SELECT DISTINCT           
 CONCAT(DR.Serie,'/',DR.Numero) Recepcion, DR.Fecha FechaRecepcion, proveedores.codigo Proveedor, DR.NombreProveedor, partidas.id id_partida, lrca.PesoNeto PesoNetoRecibido,          
 CASE lra.cantidad WHEN 0 THEN 1 ELSE lrca.PesoNeto / lra.cantidad END Factor, ISNULL(ul.NumeroSerie,'') NumeroSerie            
INTO #PartidasRecepcion          
FROM DocumentosRecepcion dr           
 inner join documentosrecepcioncomercializacion drc on drc.Id_DocumentoRecepcion = dr.id           
 inner join proveedores on proveedores.id = dr.id_proveedor          
 inner join LineasRecepcion lr on lr.Id_DocumentoRecepcion = dr.id           
 inner join lineasrecepcionarticulo lra on lra.Id_LineaRecepcion = lr.id   
 inner join lineasrecepcioncomercializacionarticulo lrca on lrca.Id_LineaRecepcionArticulo = lr.id           
 inner join LineasRecepcion_ArticulosRecibidos lrar on lrar.Id_LineasRecepcion = lr.id           
 inner join articulospartida ap on ap.id = lrar.Id_ArticulosRecibidos           
 inner join partidas on partidas.id = ap.Id_Partida and partidas.Id_Articulo = ap.Id_Articulo           
 inner join articulos artpart on artpart.id = partidas.Id_Articulo and artpart.TipoArticulo = 2          
 inner join (select distinct id_articulo from ArticulosCaracteristica) AC on AC.Id_Articulo = artpart.id           
 outer apply (          
    SELECT ans.NumeroSerie          
    FROM LineasRecepcionComercializacionPesada lrcp 
        inner join LineasRecepcionComercializacionPesada_UnidadesLogisticas lrcp_ul on lrcp.Id=lrcp_ul.Id_LineasRecepcionComercializacionPesada          
        inner join ArticulosNumerosSerie ans on lrcp_ul.Id_UnidadesLogisticas=ans.Id          
    WHERE lrcp.Id_LineaRecepcionComercializacionArticulo=lr.Id          
   ) UL          
WHERE artpart.PeticionNumeroSerie = 0 and dr.Fecha >= DATEADD(DAY, -2, @FechaDesde) and dr.Fecha <=@FechaHasta       
  
          
/*####################################################################################          
     FACTOR CANTIDAD PESO POR PARTIDA          
#####################################################################################*/          
SELECT DISTINCT id_partida , Factor           
INTO #Factores          
FROM #PartidasRecepcion P          
            
SET @HastaFechaConHora = @FechaHasta        
IF @FechaHasta is not null          
BEGIN           
 SET @HastaFechaConHora = DATEADD(second,86399,@FechaHasta)        
END          
          
/*####################################################################################          
      ID'S PARTES REALES DE ENTRADA          
#####################################################################################*/            
SELECT DISTINCT ppre.id id_ppre          
INTO #PPRE          
FROM PartesProduccionRealEntrada ppre          
WHERE         
 dbo.ObtenerFechaSinHora (ppre.fecha) <> ppre.fecha and           
 dbo.ObtenerFechaSinHora (ppre.fecha) BETWEEN ISNULL(@FechaDesde, dbo.obtenerfechasinhora(ppre.fecha)) and ISNULL(@HastaFechaConHora, dbo.obtenerfechasinhora(ppre.fecha))          
        
/*####################################################################################          
      TODOS LOS DATOS DE VOLCADO          
#####################################################################################*/            
SELECT           
 Fecha, Linea, NombreLinea, ParteProduccion, id_partida, Partida, Lote, NumeroSerie, Familia, NombreFamilia,          
 Producto, NombreProducto, SUM(Cantidad) Cantidad, SUM(PesoNetovolcado) PesoNetoVolcado, EstadoCola, FechaInicio, FechaFin, CantidadEnvases,        
 CantidadDisponible, CantidadVolcada, Almacen, Id_Almacen        
INTO #Resultado          
FROM (          
  SELECT DISTINCT           
   ppre.Fecha, COALESCE(l.codigo,'') Linea, COALESCE(l.nombre,'') NombreLinea,          
   CONCAT(PartesProduccion.Serie,'/',PartesProduccion.Numero) ParteProduccion,          
   partidas.id id_partida, CONCAT(Partidas.Serie,'/',Partidas.Numero) Partida,          
   Lotes.codigo Lote, COALESCE(ans.numeroserie, '')  NumeroSerie, Fam.codigo Familia,          
   Fam.Nombre NombreFamilia, artpart.codigo Producto, artpart.nombre NombreProducto,          
   CASE           
    WHEN ppre.cantidad > 0 THEN ulp.Cantidad           
     ELSE -ulp.cantidad           
   END Cantidad ,           
   CASE           
    WHEN Articulos.Id_UnidadMedidaAlmacen = @idUnidadMedidaGeneral           
     THEN           
      CASE WHEN ppre.cantidad > 0 THEN ulp.Cantidad           
      ELSE -ulp.cantidad           
      END          
      ELSE          
      CASE WHEN ppre.cantidad > 0 THEN ulp.Cantidad * COALESCE(F.Factor,1)            
      ELSE -ulp.cantidad * COALESCE(F.Factor,1)           
      END        
   END PesoNetoVolcado, CV.EstadoCola, CV.FechaInicio, CV.FechaFin, CV.CantidadEnvases, CD.CantidadDisponible, CD.CantidadVolcada,        
   ALM.Nombre Almacen, ALM.Id Id_Almacen        
  FROM #PPRE PP          
   inner join PartesProduccionRealEntrada ppre on ppre.id = PP.id_ppre --and PPRE.Id_Almacen = @Almacen -- and ppre.TipoOrigen=0          
   inner join partesproduccion on partesproduccion.Id_ParteProduccionReal = ppre.Id_ParteProduccionReal           
   left join LineaProduccion l on l.id= ppre.Id_LugarProduccion and ppre.TipoLugarProduccion = 1  --and L.Id_Almacen = @Almacen        
   left join Almacenes ALM on ALM.Id = l.Id_Almacen        
   inner join articulos on articulos.id = ppre.Id_Articulo           
   inner join (select distinct id_articulo from ArticulosCaracteristica) ALC on ALC.Id_Articulo = articulos.id           
   inner join FamiliasArticulo fam on fam.id = articulos.id_familia          
   inner join PartesProduccionRealEntrada_ArticulosUtilizados ppreau on ppreau.Id_PartesProduccionRealEntrada = ppre.id          
   inner join ArticulosPartida ap on ap.id = ppreau.id_articulosutilizados           
   inner join partidas on partidas.id = ap.Id_Partida and partidas.Id_Articulo = ap.Id_Articulo           
   inner join articulos artpart on artpart.id = ap.Id_Articulo and artpart.TipoArticulo = 2           
   left join FamiliasArticulo F1 on F1.Id = artpart.Id_Familia          
   left join FamiliasArticulo F2 on F2.Id = F1.Id_FamiliaSuperior          
   left join FamiliasArticulo F3 on F2.Id = F2.Id_FamiliaSuperior and F3.Codigo = @Cultivo -->          
   inner join (select distinct id_articulo from ArticulosCaracteristica) AC on AC.Id_Articulo = artpart.id           
   inner join LotesPartida lp on lp.Id_ArticuloPartida = ap.id           
   inner join lotes on lotes.id = lp.Id_Lote           
   inner join UbicacionesLotePartida ulp on ulp.Id_LotePartida = lp.id           
   left join ArticulosNumerosSerie ans on ans.id = ulp.Id_UnidadLogistica           
   LEFT join #Factores F on F.id_partida = ap.Id_Partida           
   left join ColaVolcado CV on CV.Id_ParteProduccionRealEntrada = ppre.Id          
   left join ColaVolcadoCantidadDisponible CD on CD.Id_ColaVolcado = CV.Id        
  UNION           
          
  SELECT DISTINCT           
   ppre.Fecha, COALESCE(l.codigo,'') Linea, COALESCE(l.nombre,'') NombreLinea,          
   CONCAT(PartesProduccion.Serie,'/', PartesProduccion.Numero) ParteProduccion,          
   partidas.id id_partida, CONCAT(Partidas.Serie,'/',Partidas.Numero) Partida,          
   '' Lote, COALESCE(ans.numeroserie,'') NumeroSerie, Fam.codigo Familia,          
   Fam.Nombre NombreFamilia, artpart.codigo Producto, artpart.nombre NombreProducto,          
   CASE           
    WHEN ppre.cantidad > 0 THEN uup.Cantidad           
    ELSE -uup.cantidad           
   END Cantidad,          
   CASE WHEN Articulos.Id_UnidadMedidaAlmacen = @idUnidadMedidaGeneral THEN           
    CASE WHEN ppre.cantidad > 0 THEN uup.Cantidad           
     ELSE -uup.cantidad           
    END          
     ELSE           
    CASE WHEN ppre.cantidad > 0 THEN uup.Cantidad*coalesce(F.Factor,1)            
     ELSE -uup.cantidad*coalesce(F.Factor,1)           
    END           
   END PesoNetoVolcado, CV.EstadoCola, CV.FechaInicio, CV.FechaFin, CV.CantidadEnvases, CD.CantidadDisponible, CD.CantidadVolcada,        
   ALM.Nombre Almacen, ALM.Id Id_Almacen        
  FROM #PPRE PP          
   inner join partesproduccionrealentrada ppre on ppre.Id = PP.id_ppre --and PPRE.Id_Almacen = @Almacen -- and ppre.TipoOrigen=0          
   inner join partesproduccion on partesproduccion.Id_ParteProduccionReal = ppre.Id_ParteProduccionReal           
   left join LineaProduccion l on l.id= ppre.Id_LugarProduccion and ppre.TipoLugarProduccion = 1 -- and L.Id_Almacen = @Almacen        
   left join Almacenes ALM on ALM.Id = l.Id_Almacen        
   inner join articulos on articulos.id = ppre.Id_Articulo           
   inner join (select distinct id_articulo from ArticulosCaracteristica) ALC on ALC.Id_Articulo = articulos.id           
   inner join FamiliasArticulo fam on fam.id = articulos.id_familia          
   inner join PartesProduccionRealEntrada_ArticulosUtilizados ppreau on ppreau.Id_PartesProduccionRealEntrada = ppre.id           
   inner join articulospartida ap on ap.id = ppreau.Id_ArticulosUtilizados           
   inner join partidas on partidas.id = ap.Id_partida and partidas.id_articulo= ap.Id_Articulo           
   inner join articulos artpart on artpart.id = partidas.Id_Articulo and artpart.TipoArticulo = 2          
   inner join (select distinct id_articulo from ArticulosCaracteristica) AC on AC.Id_Articulo = artpart.id           
   inner join UbicacionesUnidadPartida uup on uup.Id_ArticuloPartida = ap.id           
   left join ArticulosNumerosSerie ans on ans.id = UUP.Id_UnidadLogistica           
   left join #Factores F on F.id_partida = ap.Id_Partida           
   left join ColaVolcado CV on CV.Id_ParteProduccionRealEntrada = ppre.Id          
   left join ColaVolcadoCantidadDisponible CD on CD.Id_ColaVolcado = CV.Id        
      
  UNION                 
        
  SELECT DISTINCT          
   cv.FechaInicio as Fecha, Lp.codigo Linea, lp.nombre NombreLinea, CONCAT(pp.Serie,'/',pp.Numero) ParteProduccion,          
   NS.Id_Partida, CONCAT(Partidas.Serie,'/',Partidas.Numero) Partida, COALESCE(NS.lote,'') Lote, ans.NumeroSerie NumeroSerie,          
   f.Codigo Familia, f.Nombre NombreFamilia, art.Codigo Producto, art.Nombre NombreProducto, cv.Cantidad,           
   CASE WHEN art.Id_UnidadMedidaAlmacen = @idUnidadMedidaGeneral THEN cv.Cantidad          
    ELSE cv.Cantidad * COALESCE(FA.Factor ,1)           
   END PesoNetoVolcado, cv.EstadoCola, cv.FechaInicio, cv.FechaFin, cv.CantidadEnvases, CD.CantidadDisponible, CD.CantidadVolcada,        
   ALM.Nombre Almacen, ALM.Id Id_Almacen        
  FROM LineaProduccion lp         
 left join Almacenes ALM on ALM.Id = lp.Id_Almacen        
   inner join LineaProduccionElemento lpe on lpe.Id_LineaProduccion = lp.Id         
   inner join ElementoProduccion ep on ep.Id = lpe.Id_ElementoProduccion and ep.TipoElemento = 0        
   inner join PuntoVolcado ptovol on ptovol.Id = ep.Id_Elemento           
   inner join ColaVolcado cv on cv.Id_PuntoVolcado = ptovol.Id          
   left join ColaVolcadoCantidadDisponible CD on CD.Id_ColaVolcado = CV.Id        
   left join PartesProduccion pp on pp.Id=cv.Id_ParteProduccion          
   inner join ArticulosNumerosSerie ans on ans.id = cv.Id_EntidadVolcada           
   inner join Articulos art on art.Id = ans.Id_Articulo           
   inner join FamiliasArticulo f on f.Id=art.Id_Familia           
   left join FamiliasArticulo F1 on F1.Id = f.Id          
   left join FamiliasArticulo F2 on F2.Id = F1.Id_FamiliaSuperior          
   left join FamiliasArticulo F3 on F2.Id = F2.Id_FamiliaSuperior and F3.Codigo = @Cultivo -->          
   cross apply (          
       SELECT TOP 1 NumeroSerie, Lote, id_Partida           
       FROM (          
         SELECT DISTINCT NSP.NumeroSerie,'' AS Lote, ap.id_partida          
         FROM ArticulosPartida ap           
          inner join Partidas on Partidas.Id = ap.Id_Partida and Partidas.Id_Articulo = ap.Id_Articulo           
          inner join NumerosSeriePartida NSP on NSP.Id_ArticuloPartida = ap.Id           
         WHERE NSP.NumeroSerie = ans.NumeroSerie           
          
        ) T          
        ORDER BY Id_Partida           
      ) NS           
   inner join Partidas on Partidas.Id = NS.Id_Partida           
   left join #Factores FA on FA.id_partida = NS.Id_Partida           
  WHERE           
   cv.cantidad < 0 and cv.TipoEntidadVolcada = 3 and          
   cv.Fecha between COALESCE(@FechaDesde,cv.Fecha) and COALESCE(@HastaFechaConHora,cv.fecha)         
 ) T          
GROUP BY           
 Fecha, Linea, NombreLinea, ParteProduccion, id_partida, Partida, Lote, NumeroSerie, Familia,          
 NombreFamilia, Producto, NombreProducto, EstadoCola, FechaInicio, FechaFin, CantidadEnvases,        
 CantidadDisponible, CantidadVolcada, Almacen, Id_Almacen        
          
/*####################################################################################          
       SELECT FINAL          
#####################################################################################*/           
SELECT DISTINCT             
 R.*, P.Recepcion, P.FechaRecepcion, P.Proveedor, P.NombreProveedor,           
 COALESCE(P.PesoNetoRecibido, CONVERT(decimal(8,2),ur.PesoNeto, 0)) PesoNetoRecibido,        
 CASE        
  WHEN R.Almacen like '%P2%' THEN 'P2'        
  WHEN R.Almacen like '%P1%' THEN 'P1'
  WHEN R.Almacen like '%P3%' THEN 'P3'
 END Packing        
INTO #SFI          
FROM #Resultado R           
outer apply (          
   --> Recepciones con Unidades Logisticas          
   SELECT          
      P.Recepcion, P.FechaRecepcion, P.Proveedor, P.NombreProveedor, P.PesoNetoRecibido          
     FROM #PartidasRecepcion P WHERE P.NumeroSerie <> '' and P.id_partida = R.id_partida and P.NumeroSerie COLLATE Modern_Spanish_BIN = R.NumeroSerie COLLATE Modern_Spanish_BIN           
               
     UNION          
    --> Recepciones sin UL solo partidas          
     SELECT          
      P.Recepcion, P.FechaRecepcion, P.Proveedor, P.NombreProveedor, P.PesoNetoRecibido          
     FROM #PartidasRecepcion P WHERE P.NumeroSerie = '' and P.id_partida = R.id_partida           
    ) P             
outer apply (          
   SELECT           
      SUM(epp.PesoNeto) PesoNeto          
     FROM dbo.PartesProduccionRealSalida ps          
      inner join PartesProduccionRealSalida_DatosOrigen do on do.Id_PartesProduccionRealSalida=ps.id          
      inner join ArticulosPartida app on app.Id=do.Id_DatosOrigen          
      inner join vwArticulosPartidaUbicaciones epp on epp.Id_Partida=app.Id_Partida          
      inner join LineasRecepcion_ArticulosRecibidos lrar on lrar.Id_ArticulosRecibidos=epp.Id_ArticuloPartida          
      inner join Articulos a on a.Id=epp.Id_Articulo and a.EsMateriaPrima=1          
      inner join ArticulosNumerosSerie ans on ans.Id=ps.Id_UnidadLogistica and ans.NumeroSerie=R.NumeroSerie          
     WHERE epp.Id_Partida=r.id_partida           
     GROUP BY epp.Id_Partida          
    ) ur          
          
Select           
 CONVERT(DATE,SF.Fecha) FechaVolcado, SF.Linea Cod_LineaProd, SF.NombreLinea NombreLineaProd, SF.Id_partida, SF.Partida PartidaVolcada, SF.NumeroSerie, SF.Familia Cod_Familia,           
 SF.NombreFamilia Variedad, SF.Producto Cod_Producto, SF.NombreProducto, SF.Cantidad, SF.PesoNetoVolcado, SF.Recepcion,   DCP.FechaCosecha,        
 SF.FechaRecepcion, SF.Proveedor, SF.NombreProveedor, SF.PesoNetoRecibido, C.Id_Finca, C.Referencia LoteRed, F.Codigo Lote, SF.EstadoCola,          
 CASE          
  WHEN SF.EstadoCola = 0 THEN 'EN COLA'          
  WHEN SF.EstadoCola = 1 THEN 'ACTIVO'          
  WHEN SF.EstadoCola = 2 THEN 'CONSUMIENDO'          
  WHEN SF.EstadoCola = 3 THEN 'FINALIZADA'         
  else 'S/E'        
 END EstadoVolcado ,        
 FechaInicio, FechaFin, CantidadEnvases, CantidadDisponible, CantidadVolcada, Almacen, S.PrimerApellido FundoLote, SF.Packing        
Into #Volcado        
From #SFI SF          
 inner join Partidas P on P.Id = SF.id_partida      
 left join Cultivos C on C.Id = P.Id_Cultivo          
 left join Fincas F on F.Id = C.Id_Finca          
 left join Sujetos S on S.Id = F.Id_representante        
 left join #DCP DCP on DCP.Id_Partidas = SF.id_partida        
where SF.Producto like @Cultivo+'%'         
order by NumeroSerie           
        
        
Select         
 Packing, FechaVolcado, MIN(FechaInicio) FechaInicio, MAX(FechaFin) FechaFin        
Into #FVOL        
from #Volcado        
Group by Packing, FechaVolcado        

/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++   
                   CONFECCION       
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/       
           
Select Distinct                       
 AP.Id_Partida ,                       
 LRA.Id_ProveedorTrazabilidad  , F3.Codigo                    
Into #DatosPartidasRecepciones                      
From LineasRecepcion LR                       
 inner join LineasRecepcionArticulo LRA on LRA.Id_LineaRecepcion = LR.Id                       
 inner join LineasRecepcion_ArticulosRecibidos LRAR on LRAR.Id_LineasRecepcion = LR.Id                       
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
                  
/*=======================================================================================================        
          OPTIMIZACION DE TABLAS        
=========================================================================================================*/             
        
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
         
/*=======================================================================================================        
          PESO NORMALIZADO        
=========================================================================================================*/          
Select C.Id_Articulo , C.Id_Envase , dbo.RNEG063PesoNormalizadoConUnidadMedidaGeneral(C.Id_Articulo , C.Id_Envase , 0) PesoNormalizado                      
Into #PesosNormalizados                      
From #CombinacionesArticuloEnvase C                        
/*=======================================================================================================        
       INFORMACION ACERCA DEL ARTICULO DE TIPO PALE        
=========================================================================================================*/          
Select                       
 PPRS.Id Id_PPRS,                       
 PART.Serie, PART.Numero,                       
 A.TipoArticulo, A.Codigo, A.Nombre, A.Descripcion, A.DescripcionCorta,                      
 UUP.Cantidad, ANS.NumeroSerie, UUP.Id_UnidadLogistica                      
Into #InfoArtTipoPalePorPPRS                      
From PartesProduccionRealSalida PPRS                      
 inner join PartesProduccionRealSalida_ArticulosProducidosLinea APL on APL.Id_PartesProduccionRealSalida = PPRS.Id                      
 inner join ArticulosPartida AP on AP.Id = APL.Id_ArticulosProducidosLinea                      
 inner join #Partidas PART on PART.Id = AP.Id_Partida                      
 inner join Articulos A on A.Id = AP.Id_Articulo and A.TipoArticulo = 0                      
 inner join #UbicacionesUnidadPartida UUP on UUP.Id_ArticuloPartida = AP.Id and UUP.Cantidad > 0                      
 inner join ArticulosNumerosSerie ANS on ANS.Id = UUP.Id_UnidadLogistica                 
         
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
                
/*=======================================================================================================        
       DATOS DE PALES VENDIDOS        
=========================================================================================================*/                                       
Create Table #VentasUL (        
 FechaAlbaran DATETIME,    Albaran VARCHAR(100),   NombreClienteAlbarán VARCHAR(100),   DireccionEnvioAlbaran VARCHAR(400),        
 Linea INT,       Id_Partida INT,     Id_UnidadLogistica INT        
 )                      
                      
Create Index IX_#VentasUL on #VentasUL (Id_Partida, Id_UnidadLogistica)                      
                      
--> Primero se inserta información a partir de productos que no están configurados para petición de lote.          
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
 CodigoProveedorTrazabilidad,    NombreProveedorTrazabilidad,             
 PesoNormalizado,         CodigoPale,         
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
 inner join Articulos A on A.Id = PPRS.Id_Articulo and A.EsMateriaPrima = 1                      
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
                      
--> Obtener los Ids de movimientos de almacén de traspaso de UL.                       
SELECT                       
MA.Id Id_MA, MA.Fecha, LMA.Id Id_LMA, CMA.TipoClaveMovimiento,                     
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
WHERE (MA.TipoDocumentoOrigen = 17 OR MA.TipoDocumentoOrigen = 0)                                
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
        
--> Los Resultados se insertan en la tabla temporal #UnidadesLogisticas                     
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
 --, D.Id_Articulo Id_ArticuloDeLaPartida                                 
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
      INNER JOIN ClavesMovimientoAlmacen CMA ON LMA.Id_ClaveMovimientoAlmacen = CMA.Id AND CMA.TipoClaveMovimiento = 0                      
      INNER JOIN LineasMovimientoAlmacen_Partidas LMA_AP ON LMA.Id = LMA_AP.Id_LineasMovimientoAlmacen                         
      INNER JOIN #ArticulosPartida AP ON LMA_AP.Id_Partidas = AP.Id AND T.Id_Partida = AP.Id_Partida                      
      INNER JOIN Articulos A ON AP.Id_Articulo = A.Id AND A.TipoArticulo = 1                      
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
    Where  A.TipoArticulo = 0     --and cla.tipoclavemovimiento= 0               
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
     inner join Articulos A on A.Id = PPRS.Id_Articulo and A.EsMateriaPrima = 1 -- solo materia prima                      
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
 inner join LineasRecepcion_ArticulosRecibidos LRAR on LRAR.Id_LineasRecepcion = LR.Id                       
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
 UNION                  
 select distinct                  
  #UnidadesLogisticas.id_unidadlogistica, ap.Id_Partida , a.Codigo, a.Nombre                  
 from #UnidadesLogisticas                   
  inner join LineasRecepcionComercializacionPesada_UnidadesLogisticas lrcp_ul on #UnidadesLogisticas.id_unidadlogistica=lrcp_ul.Id_UnidadesLogisticas                  
  inner join LineasRecepcionComercializacionPesada lrcp on lrcp_ul.Id_LineasRecepcionComercializacionPesada=lrcp.Id                  
  inner join LineasRecepcionComercializacionArticulo lrca on lrcp.Id_LineaRecepcionComercializacionArticulo=lrca.Id_LineaRecepcionArticulo                  
  inner join LineasRecepcionArticulo lra on lrca.Id_LineaRecepcionArticulo=lra.Id_LineaRecepcion                  
  inner join Almacenes a on lra.Id_AlmacenDestino=a.Id                  
  inner join LineasRecepcion_ArticulosRecibidos lrar on lrar.Id_LineasRecepcion = lra.Id_LineaRecepcion                   
  inner join #ArticulosPartida ap on ap.id = lrar.Id_ArticulosRecibidos                   
  inner join articulos on articulos.id = ap.Id_Articulo and articulos.EsMateriaPrima = 1                  
  inner join #UbicacionesUnidadPartida uup on uup.Id_ArticuloPartida = ap.id                   
  inner join articulosnumerosserie ans on ans.id = uup.Id_UnidadLogistica and ans.id = #UnidadesLogisticas.id_unidadlogistica                   
      
/*=======================================================================================================        
         PALET CON PARTIDAS DE CONFECCION        
=========================================================================================================*/         
        
SELECT Id_UnidadLogistica, UL.Pale,UL.Id_Partida INTO #UL_Partidas  FROM #UnidadesLogisticas UL     
        
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
    INNER JOIN #UL_Partidas UL ON UL.Id_Partida = PA.Id AND UL.Id_UnidadLogistica = UUP.Id_UnidadLogistica        
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
--> Unidades Logisticas        
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
--> CATEGORIA   
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
       
WHERE U.FechaFabricacion BETWEEN @FechaDesde and (DATEADD(SECOND, -1, DATEADD(DAY, 1, @FechaHasta)))             
           
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
SELECT distinct        
 Packing, Tipo, Pale, LineaProd, NombreLineaProd,   
 PART.FechaCosecha,FP.FechaProceso,        
 NombreAlmacen,     
 Nombreproducto,     
 Categoria,Calibre,  NombreFamilia,          
 CodigoFamiliaN3, NombreEnvase, NroEnvases, Marca,  NombreAlmacenEntrada, FP.FechaFabricacion,        
         
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
 Cantidad,PesoNeto, PesoNormalizado, UL_Origen, EnExistencias,    EnvasesPorPalet, ExEnvases, ExProducto,        
 LO.LOTE,  LO.LotePar_Red, LO.VariedadCultivo          
Into #SSF        
FROM #PART PART            
 LEFT JOIN #LoteOrigen LO ON LO.Id_Partida = PART.Id_Partida            
 INNER JOIN #FechaPartida FP ON FP.Id = PART.Id_Partida AND LO.Id_Partida = FP.Id            
 INNER JOIN (Select Id, FechaFabricacion from ArticulosNumerosSerie) as ANS on ANS.Id = PART.id_unidadlogistica            
Where CodigoFamiliaN3 = @Cultivo and Id_Pedido is not null        
ORDER BY Pale        
        
--> Fecha Minima y Maxima de Proceso        
Select         
 Packing, FechaProceso, MIN(FechaFabricacion) FechaInicio, MAX(FechaFabricacion) FechaFin         
Into #FPRO        
from #SSF        
Group by Packing ,FechaProceso        
        
/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++        
                 CARTILLA CON DATOS DE PREVISION DE COSECHA PERO SOLO CONFIRMADO     
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/  
  
;DECLARE @Campania INT = 2025, @IdSede INT = 8, @Referencia NVARCHAR(50) = N'1456';    
    
    /* ==========================================================    
       1) Temporalidad vigente (#PCCT)    
       ========================================================== */    
    ;WITH m AS    
    (    
      SELECT Id_PlantillaControlCalidad, Referencia, MAX(Id) AS MaxId    
      FROM dbo.PlantillasControlCalidadTemporalidad WITH (NOLOCK)    
      WHERE Referencia = @Referencia    
      GROUP BY Id_PlantillaControlCalidad, Referencia    
    )    
    SELECT t.Id, t.Id_PlantillaControlCalidad, t.Nombre, t.Referencia    
    INTO #PCCT    
    FROM dbo.PlantillasControlCalidadTemporalidad AS t WITH (NOLOCK)    
    JOIN m ON t.Id = m.MaxId;    
    
    CREATE CLUSTERED INDEX CX_PCCT_Id ON #PCCT (Id);    
    CREATE NONCLUSTERED INDEX IX_PCCT_Plantilla ON #PCCT (Id_PlantillaControlCalidad);    
    
    /* ==========================================================    
       2) Base de calidad (#CalidadBase)    
       ========================================================== */    
    SELECT    
        pcc.Id                                   AS IdPlantilla,    
        rccc.Id_RegistroControlCalidad           AS IdCalidad,    
        pcct.Id                                  AS IdTemporalidad,    
        CONVERT(date, rcc.Fecha)                 AS Fecha,    
        CONVERT(time, rcc.Fecha)                 AS Hora,    
        rcc.Fecha                                AS FechaHora,    
        pcct.Nombre                              AS Nombre,    
        rcc.Numero                               AS NumeroFormulario,    
        pccg.Codigo                              AS CodigoGrupo,    
        pccc.Orden,    
        pccg.Descripcion                         AS DescripcionGrupo,    
        ccc.Codigo                               AS CodigoConcepto,    
        ccc.Nombre                               AS NombreConcepto,    
        up.Numero                                AS RespuestaNumero,    
        up.Valor                                 AS RespuestaValor,    
        Usuario = CONCAT(s.PrimerApellido,' ',ISNULL(s.SegundoApellido,''),' ',ISNULL(s.Nombre,''))    
    INTO #CalidadBase    
    FROM RegistrosControlCalidad AS rcc           WITH (NOLOCK)    
    JOIN RegistrosControlCalidadConcepto AS rccc  WITH (NOLOCK)  ON rccc.Id_RegistroControlCalidad = rcc.Id    
    JOIN ConceptosControlCalidad AS ccc           WITH (NOLOCK)  ON ccc.Id = rccc.Id_ConceptoControlCalidad    
    JOIN Plantillascontrolcalidadconcepto AS pccc WITH (NOLOCK)  ON pccc.Id_ConceptoControlCalidad = ccc.Id    
    JOIN PlantillaControlCalidadGrupo AS pccg     WITH (NOLOCK)  ON pccg.Id = pccc.Id_Grupo    
    JOIN #PCCT AS pcct                                            ON pcct.Id = pccg.Id_PlantillaControlCalidadTemporalidad    
    JOIN PlantillasControlCalidad AS pcc           WITH (NOLOCK)  ON pcc.Id = pcct.Id_PlantillaControlCalidad    
    JOIN TecnicosCalidad AS tc                     WITH (NOLOCK)  ON rcc.Id_TecnicoCalidad = tc.Id    
    JOIN Sujetos AS s                              WITH (NOLOCK)  ON tc.Id_Sujeto = s.Id    
    CROSS APPLY (VALUES    
        (1, rccc.Respuesta1),    
        (2, rccc.Respuesta2),    
        (3, rccc.Respuesta3),    
        (4, rccc.Respuesta4),    
        (5, rccc.Respuesta5),    
        (6, rccc.Respuesta6),    
        (7, rccc.Respuesta7),    
        (8, rccc.Respuesta8),    
        (9, rccc.Respuesta9),    
        (10, rccc.Respuesta10)    
    ) up(Numero, Valor)    
    WHERE pcct.Referencia = @Referencia    
      AND up.Valor IS NOT NULL    
      AND up.Valor <> N'';    
    
    CREATE CLUSTERED INDEX CX_CalidadBase ON #CalidadBase (IdCalidad, CodigoConcepto, RespuestaNumero);    
    CREATE NONCLUSTERED INDEX IX_CalidadBase_Grupo ON #CalidadBase (DescripcionGrupo, IdCalidad);    
    CREATE NONCLUSTERED INDEX IX_CalidadBase_Fecha ON #CalidadBase (FechaHora);    
    
    /* ==========================================================    
       3) Listado/Tácnica (#TempLisTac) y Detalle (#TempDet)    
       ========================================================== */    
    SELECT     
        RDC.IdCalidad,    
        RDC.Fecha          AS Fecha_Eval,    
        RDC.Hora,    
        RDC.NumeroFormulario,    
        MAX(CASE WHEN RDC.CodigoConcepto='pcdfecha'   THEN RDC.RespuestaValor END) AS FechaCosecha,    
        MAX(CASE WHEN RDC.CodigoConcepto='pcdversion' THEN RDC.RespuestaValor END) AS Version1,    
        RDC.Usuario    
    INTO #TempLisTac    
    FROM #CalidadBase AS RDC    
    WHERE RDC.CodigoConcepto IN ('pcdfecha','pcdversion')    
    GROUP BY RDC.IdCalidad, RDC.Fecha, RDC.NumeroFormulario, RDC.Hora, RDC.Usuario;    
    
    CREATE CLUSTERED INDEX CX_TempLisTac ON #TempLisTac (IdCalidad);    
    
    SELECT     
        RDC.IdCalidad,    
        RDC.DescripcionGrupo,    
        RDC.NumeroFormulario,    
        RDC.RespuestaNumero,    
        MAX(CASE WHEN RDC.NombreConcepto = 'Lote Par'        THEN TRY_CONVERT(int, RDC.RespuestaValor) END)         AS LotePar,    
        MAX(CASE WHEN RDC.NombreConcepto = 'Lote Par'        THEN RDC.RespuestaValor END)                           AS LoteParTxt,    
        MAX(CASE WHEN RDC.NombreConcepto = 'Packing'         THEN TRY_CONVERT(int, RDC.RespuestaValor) END)         AS Packing,    
        MAX(CASE WHEN RDC.NombreConcepto = 'Packing'         THEN RDC.RespuestaValor END)                           AS PackingTxt,    
        CAST(MAX(CASE WHEN RDC.NombreConcepto = '% <22 mm'   THEN RDC.RespuestaValor END) AS DECIMAL(10,2))         AS Mayor22mm,    
        CAST(MAX(CASE WHEN RDC.NombreConcepto = '% >22 mm'   THEN RDC.RespuestaValor END) AS DECIMAL(10,2))         AS Menormm,    
        MAX(CASE WHEN RDC.NombreConcepto = 'Cantidad Jabas'  THEN TRY_CAST(RDC.RespuestaValor AS DECIMAL(18,2)) ELSE 0 END) AS Jabas    
    INTO #TempDet    
    FROM #CalidadBase AS RDC    
    WHERE RDC.NombreConcepto IN ('Packing', 'Lote Par', 'Cantidad Jabas', '% <22 mm', '% >22 mm')    
    GROUP BY RDC.IdCalidad, RDC.DescripcionGrupo, RDC.RespuestaNumero, RDC.NumeroFormulario;    
    
    CREATE CLUSTERED INDEX CX_TempDet ON #TempDet (IdCalidad, DescripcionGrupo, NumeroFormulario);    
    
    IF OBJECT_ID('tempdb..#TempValvular1') IS NOT NULL DROP TABLE #TempValvular1;    
    
    SELECT    
        c.Id                 AS IdCultivo,    
        z.Nombre             AS Sede,    
        z.Id                 AS IdSede,  
  S.Id IdFundo,  
        s.PrimerApellido     AS Fundo,    
        eb.NombreComun       AS Cultivo,   
  ebv.Id IdVariedad,  
        ebv.Denominacion     AS Variedad,    
        fi.Codigo            AS Lote,    
        c.Descripcion        AS LotePar    
    INTO #TempValvular1    
    FROM ERPHispatec.dbo.Cultivos cu WITH (NOLOCK)    
    JOIN ERPHispatec.dbo.Fincas fi                         WITH (NOLOCK) ON fi.Id = cu.Id_Finca    
    JOIN ERPHispatec.dbo.CultivoAgrupacion_Cultivos cac    WITH (NOLOCK) ON cac.Id_Cultivos = cu.Id    
    JOIN ERPHispatec.dbo.CultivoAgrupacion ca              WITH (NOLOCK) ON ca.Id = cac.Id_CultivoAgrupacion    
    JOIN ERPHispatec.dbo.Cultivos c                        WITH (NOLOCK) ON c.Id = ca.Id_CultivoGenerico    
    JOIN ERPHispatec.dbo.Articulos ar                      WITH (NOLOCK) ON ar.Id = cu.Id_Articulo    
    JOIN ERPHispatec.dbo.ArticulosAgro aa                  WITH (NOLOCK) ON aa.Id = ar.Id_ArticuloAgro    
    LEFT JOIN ERPHispatec.dbo.ArticulosAgro_EspecieBotanicaVariedad aaev WITH (NOLOCK) ON aaev.Id_ArticuloAgro = aa.Id     
    LEFT JOIN ERPHispatec.dbo.EspecieBotanicaVariedad ebv  WITH (NOLOCK) ON ebv.Id = aaev.Id_EspecieBotanicaVariedad    
    LEFT JOIN ERPHispatec.dbo.EspeciesBotanicas eb         WITH (NOLOCK) ON eb.Id = ebv.Id_EspecieBotanica    
    JOIN ERPHispatec.dbo.Sujetos s                         WITH (NOLOCK) ON s.Id = fi.Id_Representante    
    JOIN ERPHispatec.dbo.Zonas z                           WITH (NOLOCK) ON z.Id = fi.Id_Zona    
    GROUP BY c.Id, z.Nombre, s.PrimerApellido, eb.NombreComun, ebv.Denominacion, fi.Codigo, c.Descripcion, z.Id, S.Id, ebv.Id;    
    
    CREATE CLUSTERED INDEX IX_TV1_IdCultivo   ON #TempValvular1 (IdCultivo);    
    CREATE INDEX         IX_TV1_Variedad      ON #TempValvular1 (Variedad);    
    CREATE INDEX         IX_TV1_Lotes         ON #TempValvular1 (LotePar, Lote);    
    
    IF OBJECT_ID('tempdb..#TempValvular2') IS NOT NULL DROP TABLE #TempValvular2;    
    
    SELECT     
        cu.Id             AS IdCultivo,     
        cu.Descripcion    AS Sublote,     
        ebv.Denominacion  AS Variedad,  
  Su.Id IdFundo,  
  ebv.Id IdVariedad,  
        cu.Id_Finca,     
        eb.NombreComun    AS Cultivo,     
        fi.Codigo         AS Lote,    
        cu.Referencia     AS LotePar,    
        z.Nombre          AS Sede,    
  z.Id                 AS IdSede,    
        su.PrimerApellido AS Fundo    
    INTO #TempValvular2    
    FROM ERPHispatec.dbo.Cultivos AS cu    
    INNER JOIN ERPHispatec.dbo.Fincas                     fi   ON fi.Id = cu.Id_Finca    
    INNER JOIN ERPHispatec.dbo.Fincas_DatosComplementarios fdc ON fi.Id = fdc.Id_Fincas    
    INNER JOIN ERPHispatec.dbo.DatoComplementarioValor    dcvc ON dcvc.Id = fdc.Id_DatosComplementarios    
    INNER JOIN ERPHispatec.dbo.DatosComplementarios       dcc  ON dcc.Id = dcvc.Id_DatoComplementario AND dcc.Codigo = 'VAR'    
    INNER JOIN ERPHispatec.dbo.EspecieBotanicaVariedad    ebv  ON ebv.Id = dcvc.Valor    
    INNER JOIN ERPHispatec.dbo.EspeciesBotanicas          eb   ON eb.Id = ebv.Id_EspecieBotanica    
    INNER JOIN ERPHispatec.dbo.Zonas                      z    ON fi.Id_Zona = z.Id    
    INNER JOIN ERPHispatec.dbo.Sujetos                    su   ON su.Id = fi.Id_Representante    
    WHERE TRY_CAST(dcvc.Valor AS FLOAT) IS NOT NULL;    
    
    CREATE CLUSTERED INDEX CX_TV2_IdCultivo ON #TempValvular2 (IdCultivo);    
    CREATE INDEX         IX_TV2_Variedad    ON #TempValvular2 (Variedad);    
    CREATE INDEX         IX_TV2_Lotes       ON #TempValvular2 (LotePar, Lote);    
    
    IF OBJECT_ID('tempdb..#DetResolved') IS NOT NULL DROP TABLE #DetResolved;    
    
    SELECT    
        d.*,    
        COALESCE(v1.IdCultivo, v2.IdCultivo)   AS IdCultivo1,    
        COALESCE(v1.Sede,      v2.Sede)        AS Sede1,    
  COALESCE(v1.IdSede,      v2.IdSede)        AS IdSede1,   
  COALESCE(v1.IdFundo, V2.IdFundo)  AS IdFundo,  
        COALESCE(v1.Fundo,     v2.Fundo)       AS Fundo1,    
        COALESCE(v1.Cultivo,   v2.Cultivo)     AS Cultivo1,  
  COALESCE(v1.IdVariedad, V2.IdVariedad) AS IdVariedad,  
        COALESCE(v1.Variedad,  v2.Variedad)    AS Variedad1,   
  COALESCE(v1.Lote, V2.Lote) AS Lote,  
        COALESCE(v1.LotePar,   v2.LotePar)     AS LotePar1    
    INTO #DetResolved    
    FROM #TempDet d    
    OUTER APPLY (    
        SELECT TOP (1) v.*     
        FROM #TempValvular1 v     
        WHERE v.IdCultivo = d.LotePar    
    ) v1    
    OUTER APPLY (    
        SELECT TOP (1) v.*     
        FROM #TempValvular2 v     
        WHERE v.IdCultivo = d.LotePar    
    ) v2;    
    
    CREATE CLUSTERED INDEX CX_DetResolved ON #DetResolved (IdCultivo1, IdCalidad, NumeroFormulario);    
  
--> CARTILLA N° 1    
    SELECT    
        C.Nombre AS Campania,    
        D.NumeroFormulario,    
        L.Fecha_Eval,    
        TRY_CONVERT(date, FORMAT(TRY_CONVERT(date, L.FechaCosecha, 101), 'yyyy-MM-dd'), 23) AS FechaCosecha,    
        CONVERT(varchar(5), TRY_CONVERT(time(0), L.Hora), 108) AS Hora,    
        DR.Cultivo1    AS Cultivoc,    
        DR.Sede1    AS Sede,    
  DR.IdSede1    AS IdSede,    
        DR.Fundo1    AS Fundo,    
        DR.Variedad1   AS Variedad,  
  DR.Lote,  
        DR.LotePar1    AS LotePar,  
        F.Codigo    AS Packing,    
        D.Mayor22mm/100   AS Menormm,    
        D.Menormm/100   AS Mayor22mm,    
        CASE     
            WHEN L.Version1 = 1 THEN 'Proyeccion'    
            WHEN L.Version1 = 2 THEN 'Confirmacion'    
            WHEN L.Version1 = 3 THEN 'Actualizacion'    
            ELSE CAST(L.Version1 AS varchar(50))    
        END AS Version,    
        D.Jabas,  
  (D.Jabas * FC.FactorConversion) CajasEqv,  
        L.Usuario,     
        CASE     
            WHEN TRY_CONVERT(date, FORMAT(TRY_CONVERT(date, L.FechaCosecha, 101), 'yyyy-MM-dd'), 23)    
               = MAX(TRY_CONVERT(date, FORMAT(TRY_CONVERT(date, L.FechaCosecha, 101), 'yyyy-MM-dd'), 23))    
                 OVER (PARTITION BY C.Nombre, CONVERT(date, L.Fecha_Eval), L.Version1)    
            THEN 'ULTIMO' ELSE '-'     
        END AS UltimaEval    
 Into #CARTILLA_1  
    FROM #DetResolved DR    
    JOIN #TempDet    D  WITH (NOLOCK) ON D.IdCalidad = DR.IdCalidad AND D.NumeroFormulario = DR.NumeroFormulario AND D.RespuestaNumero = DR.RespuestaNumero    
    JOIN #TempLisTac L  WITH (NOLOCK) ON D.IdCalidad = L.IdCalidad    
    JOIN Campanyas   C  WITH (NOLOCK) ON C.FechaInicial <= L.Fecha_Eval AND C.FechaFinal   >= L.Fecha_Eval AND C.Componente    = 1     
    JOIN Cultivos CU WITH (NOLOCK) ON D.Packing = CU.Id    
    JOIN Fincas   F  WITH (NOLOCK) ON CU.Id_Finca = F.Id   
 Left Join CLI547_Factor_Conversion FC on FC.Fundo  = DR.IdFundo  and FC.Variedad = DR.IdVariedad  
 WHERE @IdSede IS NULL OR DR.IdSede1 = @IdSede AND @Campania IS NULL OR C.Nombre = @Campania;    
  
Select Distinct  
 C1.Campania, C1.FechaCosecha, C1.Hora, C1.Cultivoc, C1.Sede, C1.IdSede,C1.Fundo,C1.Variedad,C1.Lote, C1.LotePar,C1.Packing,C1.Jabas, C1.CajasEqv  
Into #CARTILLA_2  
from #CARTILLA_1 C1  
where Version = 'Confirmacion' and C1.FechaCosecha Between @FechaDesde and @FechaHasta  
Order by C1.FechaCosecha, C1.LotePar;   
  
/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++        
                 UNION DE TABLAS PARA RESUMEN INDICADOR        
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/        
        
/*=======================================================================================================        
        CREACION DE TABLA PARA LA UNION        
=========================================================================================================*/         
        
CREATE TABLE #Union (        
 Versus Varchar(15), Packing Varchar(5), FechaCosecha DATE, FechaProceso DATE, Variedad Varchar(250), Lote Varchar(50), LotePar_Red Varchar(250),        
 Categoria Varchar(5), Calibre Varchar(50), NombreFamilia Varchar(250), NroEnvase Decimal, Kilos Decimal, FechaInicio DAtetime, FechaFin DAtetime,      
 RgHora Datetime, TmpEstimado int, KgHora decimal, PromTotal_Kg decimal,    
 EnvHora decimal, PromTotal_Env decimal    
    
)        
/*===========================================================================================*/        
--> DATOS CONFECCION        
;WITH CONF AS (        
Select distinct        
 'CONFECCION' AS VS, SSF.Packing, SSF.FechaCosecha, CONVERT(DATE,SSF.FechaProceso) FechaProceso, SSF.VariedadCultivo, SSF.Lote, SSF.LotePar_Red, SSF.Categoria, SSF.Calibre, SSF.NombreFamilia,         
  --SUM(SSF.ExEnvases) ExEnvases,   
 SUM(SSF.Exproducto) ExProducto, FP.FechaInicio, FP.FechaFin        
from #SSF SSF        
 left join #FPRO FP on FP.FechaProceso = SSF.FechaProceso  and FP.Packing = SSF.Packing      
Group by         
 SSF.Packing, SSF.FechaCosecha, SSF.FechaProceso, SSF.VariedadCultivo, SSF.Lote, SSF.LotePar_Red, SSF.Categoria, SSF.Calibre, SSF.NombreFamilia, FP.FechaInicio, FP.FechaFin        
)       
Insert into #Union (        
 Versus,Packing, FechaCosecha, FechaProceso, Variedad, Lote, LotePar_Red, Categoria, Calibre, NombreFamilia, NroEnvase, Kilos, FechaInicio, FechaFin,       
 --> Nuevos Campos Agregados      
 RgHora, TmpEstimado, KgHora, PromTotal_Kg    
)        
Select Distinct       
 VS, Packing, FechaCosecha, FechaProceso, VariedadCultivo, Lote, LotePar_Red, Categoria, Calibre, NombreFamilia, (ExProducto / 8.2 ) CajasEqv, Exproducto, FechaInicio, FechaFin,      
 --> Nuevos Campos Agregados      
 NULL AS RgHora, NULL AS TmpEstimado, NULL AS KgHora, NULL AS PromTotal_Kg    
from CONF         
        
/*===========================================================================================*/        
--> DATOS DE RECEPCION        
Insert into #Union (        
 Versus, Packing, FechaCosecha, FechaProceso, Variedad, Lote, LotePar_Red, Categoria, Calibre, NombreFamilia, NroEnvase, Kilos, FechaInicio, FechaFin,      
 --> Nuevos Campos Agregados      
 RgHora, TmpEstimado, KgHora, PromTotal_Kg      
)        
Select distinct        
 'RECEPCION' AS VS, RR.Packing, FechaCosecha, FechaRecepcion, VariedadValidacion, Lote, SubLote, 'S/C' AS Cat, 'S/C' as Cal, DescArticulo, SUM(NroEnvases) NroEnvases, SUM(PesoNetoPalet) PesoNetoPalet,        
 FR.FIni_Recep, FR.FFin_Recep,      
 --> Nuevos Campos Agregados      
 NULL AS RgHora, NULL AS TmpEstimado, NULL AS KgHora, NULL AS PromTotal_Kg      
from #Recepcion RR        
 left join #FRE FR on FR.FechaProceso = RR.FechaRecepcion  and FR.Packing = RR.Packing      
Group by         
 RR.Packing, FechaCosecha, FechaRecepcion, VariedadValidacion, Lote, SubLote, DescArticulo, FR.FIni_Recep, FR.FFin_Recep        
      
/*===========================================================================================*/        
--> DATOS DE VOLCADO        
Insert into #Union (        
 Versus, Packing, FechaCosecha, FechaProceso, Variedad, Lote, LotePar_Red, Categoria, Calibre, NombreFamilia, NroEnvase, Kilos, FechaInicio, FechaFin,      
  --> Nuevos Campos Agregados      
 RgHora, TmpEstimado, KgHora, PromTotal_Kg      
)        
Select distinct        
 'VOLCADO' AS VS, V.Packing, V.FechaCosecha, V.FechaVolcado, V.NombreProducto, V.Lote, V.LoteRed, 'S/C' Cat, 'S/C' Cal, V.Variedad, SUM(V.CantidadEnvases) CantidadEnvases, SUM(V.Cantidad) Cantidad, FV.FechaInicio, FV.FechaFin,      
  --> Nuevos Campos Agregados      
 NULL AS RgHora, NULL AS TmpEstimado, NULL AS KgHora, NULL AS PromTotal_Kg      
from #Volcado V        
 Left join #FVOL FV on FV.FechaVolcado = V.FechaVolcado  and V.Packing = FV.Packing      
Group by         
 V.Packing, V.FechaCosecha, V.FechaVolcado, V.NombreProducto, V.Lote, V.LoteRed, V.Variedad, FV.FechaInicio, FV.FechaFin        
        
/*===========================================================================================*/        
----> DATOS DE PREVISION CARTILLA  
Insert into #Union (        
 Versus, Packing, FechaCosecha, FechaProceso, Variedad, Lote, LotePar_Red, Categoria, Calibre, NombreFamilia, NroEnvase, Kilos, FechaInicio, FechaFin,      
  --> Nuevos Campos Agregados      
 RgHora, TmpEstimado, KgHora, PromTotal_Kg      
)   
Select   
'PREV_DIA' AS Versus, Packing, FechaCosecha, null FechaProceso, Variedad, Lote, LotePar, 'S/C' Cat, 'S/C' Cal, Variedad, Jabas, CajasEqv, null as FechaInicio, null as FechaFin,  
null as RgHora, null as TmpEstimado,null as KgHora, null as PromTotal_Kg  
from #CARTILLA_2  
  
/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++        
            CONSULTA PARA KILOS POR HORA DE RECEPCION / VOLCADO / CONFECCION       
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/      
      
/*===========================================================================================*/      
--> RECEPCION       
;WITH RE AS (      
Select       
  'HR_REP' AS Versus, Packing, FechaCosecha, FechaRecepcion, VariedadValidacion, Lote, SubLote, 'S/C' AS Cat, 'S/C' as Cal, DescArticulo, SUM(NroEnvases) NroEnvases, SUM(PesoNetoPalet) PesoNetoPalet,       
  DATEADD(HOUR, DATEPART(HOUR, FechaCreacion), CAST(CAST(FechaCreacion AS DATE) AS DATETIME)) AS RgHora, Min(FechaCreacion) FMin_Recep, MAX(FechaCreacion) FMax_Recep       
from #Recepcion      
Group by      
 Packing, FechaCosecha, FechaRecepcion, VariedadValidacion, Lote, SubLote, DescArticulo,  DATEADD(HOUR, DATEPART(HOUR, FechaCreacion), CAST(CAST(FechaCreacion AS DATE) AS DATETIME))      
),       
RE2 AS (      
Select       
 Versus, Packing, FechaCosecha, FechaRecepcion, VariedadValidacion, Lote, SubLote, Cat, Cal, DescArticulo, NroEnvases, PesoNetoPalet, RgHora, FMin_Recep, FMax_Recep, DATEPART(MINUTE,(FMax_Recep-FMin_Recep)) TmpEstimado    
From RE      
),    
/*++++++++++++++++++++++++++++++++++++  Agrupacion de Rangos de horas para mas adelante sacar el promedio por hora +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/    
RE4 AS (    
Select distinct     
 Versus, Packing, FechaRecepcion, RgHora, COUNT(distinct RgHora) Rn from RE2    
Group by     
 Versus, Packing, FechaRecepcion, RgHora    
),    
RE5 AS (    
Select     
 Versus, Packing, FechaRecepcion, SUM(rn) RgHoraTotal from RE4    
group by     
 Versus, Packing, FechaRecepcion    
),    
/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++  FIN  ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/    
RE3 AS (      
Select       
 RE2.Versus, RE2.Packing, RE2.FechaCosecha, RE2.FechaRecepcion, RE2.VariedadValidacion, RE2.Lote, RE2.SubLote, RE2.Cat, RE2.Cal, RE2.DescArticulo, RE2.NroEnvases, RE2.PesoNetoPalet,  RE2.FMin_Recep, RE2.FMax_Recep,       
 RE2.RgHora, RE2.TmpEstimado, AVG(CAST(RE2.PesoNetoPalet as decimal)) OVER (PARTITION BY RE2.RgHora) KgHora,  --AVG(CAST(PesoNetoPalet as decimal)) OVER (PARTITION BY Packing,FechaRecepcion) PromTotal_Kg     
 PromTotal_Kg = SUM(CAST(PesoNetoPalet AS decimal(18,2))) OVER (PARTITION BY RE2.Packing, RE2.FechaRecepcion)/RE5.RgHoraTotal,    
 AVG(CAST(RE2.NroEnvases as decimal)) OVER (PARTITION BY RE2.RgHora) EnvHora,   
 PromTotal_Env = SUM(CAST(NroEnvases AS decimal(18,2))) OVER (PARTITION BY RE2.Packing, RE2.FechaRecepcion)/RE5.RgHoraTotal    
from RE2    
 Left join RE5 on RE5.Versus = RE2.Versus and RE5.Packing = RE2.Packing and RE5.FechaRecepcion = RE2.FechaRecepcion    
Group by       
  RE2.Versus, RE2.Packing, RE2.FechaCosecha, RE2.FechaRecepcion, RE2.VariedadValidacion, RE2.Lote, RE2.SubLote, RE2.Cat, RE2.Cal, RE2.DescArticulo, RE2.NroEnvases, RE2.PesoNetoPalet,  RE2.FMin_Recep, RE2.FMax_Recep,       
  RE2.RgHora,RE2.TmpEstimado, RE5.RgHoraTotal      
)      
Insert into #Union (        
  Versus, Packing, FechaCosecha, FechaProceso, Variedad, Lote, LotePar_Red, Categoria, Calibre, NombreFamilia, NroEnvase, Kilos, FechaInicio, FechaFin,          
  RgHora, TmpEstimado, KgHora, PromTotal_Kg,    
  EnvHora, PromTotal_Env    
)       
Select       
  Versus, Packing, FechaCosecha, FechaRecepcion, VariedadValidacion, Lote, SubLote, Cat, Cal, DescArticulo, NroEnvases, PesoNetoPalet,  FMin_Recep, FMax_Recep,       
  RgHora, TmpEstimado, KgHora, PromTotal_Kg, EnvHora, PromTotal_Env    
      
from RE3      
Order by RgHora      
    
/*===========================================================================================*/       
      
--> VOLCADO       
--Select * from #Volcado -- FechaInicio y FechaFin son los campos con hora      
;WITH VO AS (      
Select       
  'HR_VOL' AS VS, V.Packing, V.FechaCosecha, V.FechaVolcado, V.NombreProducto, V.Lote, V.LoteRed, 'S/C' Cat, 'S/C' Cal, V.Variedad, SUM(V.CantidadEnvases) CantidadEnvases, SUM(V.Cantidad) Cantidad,       
  DATEADD(HOUR, DATEPART(HOUR, FechaInicio), CAST(CAST(FEchaInicio AS DATE) AS DATETIME)) AS RgHora,      
  MIN(FechaInicio) FechaInicio, MAX(FechaFin) FechaFin      
from #Volcado V      
Group by         
  V.Packing, V.FechaCosecha, V.FechaVolcado, V.NombreProducto, V.Lote, V.LoteRed, V.Variedad, DATEADD(HOUR, DATEPART(HOUR, FechaInicio), CAST(CAST(FEchaInicio AS DATE) AS DATETIME))      
),      
VO2 AS (      
Select       
 VS,Packing,FechaCosecha,FechaVolcado,NombreProducto,Lote,LoteRed,Cat,Cal,Variedad,CantidadEnvases,Cantidad,RgHora,FechaInicio,FechaFin, DATEPART(MINUTE,(FechaFin-FechaInicio)) TmpEstimado      
from VO      
Group by       
 VS,Packing,FechaCosecha,FechaVolcado,NombreProducto,Lote,LoteRed,Cat,Cal,Variedad,CantidadEnvases,Cantidad,RgHora,FechaInicio,FechaFin      
),    
/*++++++++++++++++++++++++++++++++++++  Agrupacion de Rangos de horas para mas adelante sacar el promedio por hora +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/    
VO4 AS (    
Select distinct     
 VS, Packing, FechaVolcado, RgHora, COUNT(distinct RgHora) Rn from VO2    
Group by     
 VS, Packing, FechaVolcado, RgHora    
),    
VO5 AS (    
Select     
 VS, Packing, FechaVolcado, SUM(rn) RgHoraTotal from VO4    
group by     
 VS, Packing, FechaVolcado    
),    
/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++  FIN  ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/    
VO3 AS (      
Select       
  VO2.VS,VO2.Packing,FechaCosecha,VO2.FechaVolcado,NombreProducto,Lote,LoteRed,Cat,Cal,Variedad,CantidadEnvases,Cantidad,RgHora,FechaInicio,FechaFin,TmpEstimado,      
  AVG(CAST(Cantidad AS decimal)) OVER (PARTITION BY RgHora) KgHora,  
  CASE  
   WHEN VO5.RgHoraTotal > 0 THEN SUM(CAST(Cantidad AS decimal(18,2))) OVER (PARTITION BY VO2.Packing, VO2.FechaVolcado)/ VO5.RgHoraTotal  
   ELSE 0  
  END AS PromTotal_Kg,  
  AVG(CAST(CantidadEnvases AS decimal)) OVER (PARTITION BY RgHora) EnvHora,    
  CASE  
   WHEN VO5.RgHoraTotal > 0 THEN SUM(CAST(CantidadEnvases AS decimal(18,2))) OVER (PARTITION BY VO2.Packing, VO2.FechaVolcado)/ VO5.RgHoraTotal  
   ELSE 0  
  END AS PromTotal_Env  
  
From VO2     
 Left join VO5 on VO5.VS = VO2.VS and VO5.Packing = VO2.Packing and VO5.FechaVolcado = VO2.FechaVolcado    
Group by       
 VO2.VS,VO2.Packing,FechaCosecha,VO2.FechaVolcado,NombreProducto,Lote,LoteRed,Cat,Cal,Variedad,CantidadEnvases,Cantidad,RgHora,FechaInicio,FechaFin,TmpEstimado,VO5.RgHoraTotal      
)      
Insert into #Union (        
  Versus, Packing, FechaCosecha, FechaProceso, Variedad, Lote, LotePar_Red, Categoria, Calibre, NombreFamilia, NroEnvase, Kilos, FechaInicio, FechaFin,      
  --> Nuevos Campos Agregados      
  RgHora, TmpEstimado, KgHora, PromTotal_Kg, EnvHora, PromTotal_Env    
    
)       
Select       
  VS, Packing, FechaCosecha, FechaVolcado, NombreProducto, Lote, LoteRed, Cat, Cal, Variedad, CantidadEnvases, Cantidad, FechaInicio, FechaFin,      
  RgHora, TmpEstimado, KgHora, PromTotal_Kg, EnvHora, PromTotal_Env    
from VO3      
Order by RgHora      
      
/*===========================================================================================*/        
      
--> CONFECCION       
;WITH PRO AS (      
Select       
  'HR_CONF' AS VS, SSF.Packing, SSF.FechaCosecha, CONVERT(DATE,SSF.FechaProceso) FechaProceso, SSF.VariedadCultivo, SSF.Lote, SSF.LotePar_Red, SSF.Categoria, SSF.Calibre, SSF.NombreFamilia,         
   SUM(SSF.ExEnvases) ExEnvases, SUM(SSF.Exproducto) ExProducto,  DATEADD(HOUR, DATEPART(HOUR, FechaFabricacion), CAST(CAST(FechaFabricacion AS DATE) AS DATETIME)) RgHora,      
  MIN(SSF.FechaFabricacion) FechaMin, MAX(SSF.FechaFabricacion) FechaMax      
from #SSF SSF      
Group by       
  SSF.Packing, SSF.FechaCosecha, SSF.FechaProceso, SSF.VariedadCultivo, SSF.Lote, SSF.LotePar_Red, SSF.Categoria, SSF.Calibre, SSF.NombreFamilia,      
  DATEADD(HOUR, DATEPART(HOUR, SSF.FechaFabricacion), CAST(CAST(SSF.FechaFabricacion AS DATE) AS DATETIME))      
),      
PRO2 AS (      
Select       
  VS,Packing,FechaCosecha,FechaProceso,VariedadCultivo,Lote,LotePar_Red,Categoria,Calibre,NombreFamilia,ExEnvases,ExProducto,RgHora,FechaMin,FechaMax,      
  DATEPART(MINUTE,(FechaMax-FechaMin)) TmpEstimado      
from PRO      
Group by       
 VS,Packing,FechaCosecha,FechaProceso,VariedadCultivo,Lote,LotePar_Red,Categoria,Calibre,NombreFamilia,ExEnvases,ExProducto,RgHora,FechaMin,FechaMax      
),     
/*++++++++++++++++++++++++++++++++++++  Agrupacion de Rangos de horas para mas adelante sacar el promedio por hora +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/    
PRO4 AS (    
Select distinct     
 VS, Packing, FechaProceso, RgHora, COUNT(distinct RgHora) Rn from PRO2    
Group by     
 VS, Packing, FechaProceso, RgHora    
),    
PRO5 AS (    
Select     
 VS, Packing, FechaProceso, SUM(rn) RgHoraTotal from PRO4    
group by     
 VS, Packing, FechaProceso    
),    
/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++  FIN  ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/    
PRO3 AS (      
Select       
 PRO2.VS,PRO2.Packing,FechaCosecha,PRO2.FechaProceso,VariedadCultivo,Lote,LotePar_Red,Categoria,Calibre,NombreFamilia,ExEnvases,ExProducto,RgHora,FechaMin,FechaMax, TmpEstimado,      
  (AVG(CAST(ExProducto as decimal)) OVER (PARTITION BY RgHora)) KgHora , --(AVG(CAST(ExProducto as decimal)) OVER (PARTITION BY Packing,FechaProceso)) PromTotal_Kg     
  PromTotal_Kg = SUM(CAST(ExProducto AS decimal(18,2))) OVER (PARTITION BY PRO2.Packing, PRO2.FechaProceso)/ PRO5.RgHoraTotal,    
  (AVG(CAST(ExEnvases as decimal)) OVER (PARTITION BY RgHora)) EnvHora ,    
  PromTotal_Env = SUM(CAST(ExEnvases AS decimal(18,2))) OVER (PARTITION BY PRO2.Packing, PRO2.FechaProceso)/ PRO5.RgHoraTotal    
from PRO2      
 Left join PRO5 on PRO5.VS = PRO2.VS and PRO5.Packing = PRO2.Packing and PRO5.FechaProceso = PRO2.FechaProceso    
Group by       
 PRO2.VS,PRO2.Packing,FechaCosecha,PRO2.FechaProceso,VariedadCultivo,Lote,LotePar_Red,Categoria,Calibre,NombreFamilia,ExEnvases,ExProducto,RgHora,FechaMin,FechaMax, TmpEstimado ,PRO5.RgHoraTotal    
)      
Insert into #Union (        
  Versus, Packing, FechaCosecha, FechaProceso, Variedad, Lote, LotePar_Red, Categoria, Calibre, NombreFamilia, NroEnvase, Kilos, FechaInicio, FechaFin,      
  --> Nuevos Campos Agregados      
  RgHora, TmpEstimado, KgHora, PromTotal_Kg, EnvHora, PromTotal_Env    
    
)       
Select       
  VS,Packing,FechaCosecha,FechaProceso,VariedadCultivo,Lote,LotePar_Red,Categoria,Calibre,NombreFamilia,ExEnvases,ExProducto,FechaMin,FechaMax,      
  RgHora, TmpEstimado, KgHora, PromTotal_Kg, EnvHora, PromTotal_Env    
   
from PRO3      
Order by RgHora      
      
/*===========================================================================================*/      
--> TODOS LOS DATOS UNIDOS        
     
Select * from #Union               
Order by FechaProceso, Packing, Versus      
      
--Select * from #FPRO      
      
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
 IF OBJECT_ID('tempdb..#Union') IS NOT NULL BEGIN DROP TABLE #Union END        
 IF OBJECT_ID('tempdb..#UbicacionesUnidadPart') IS NOT NULL BEGIN DROP TABLE #UbicacionesUnidadPart END        
 IF OBJECT_ID('tempdb..#MovAlmacen') IS NOT NULL BEGIN DROP TABLE #MovAlmacen END        
 IF OBJECT_ID('tempdb..#Cant') IS NOT NULL BEGIN DROP TABLE #Cant END        
 IF OBJECT_ID('tempdb..#DCP') IS NOT NULL BEGIN DROP TABLE #DCP END        
 IF OBJECT_ID('tempdb..#PartidasRecepcion') IS NOT NULL BEGIN DROP TABLE #PartidasRecepcion END          
 IF OBJECT_ID('tempdb..#PPRE') IS NOT NULL BEGIN DROP TABLE #PPRE END          
 IF OBJECT_ID('tempdb..#Resultado') IS NOT NULL BEGIN DROP TABLE #Resultado END          
 IF OBJECT_ID('tempdb..#Factores') IS NOT NULL BEGIN DROP TABLE #Factores  END          
 IF OBJECT_ID('tempdb..#DatosNSVersionCero') IS NOT NULL BEGIN DROP TABLE #DatosNSVersionCero  END          
 IF OBJECT_ID('tempdb..#SFI') IS NOT NULL BEGIN DROP TABLE #SFI  END         
 IF OBJECT_ID('tempdb..#FRE') IS NOT NULL BEGIN DROP TABLE #FRE  END         
 IF OBJECT_ID('tempdb..#FVOL') IS NOT NULL BEGIN DROP TABLE #FVOL  END         
 IF OBJECT_ID('tempdb..#FPRO') IS NOT NULL BEGIN DROP TABLE #FPRO  END         
 IF OBJECT_ID('tempdb..#Detalle') IS NOT NULL BEGIN DROP TABLE #Detalle  END    
 --> TABLAS DE LAS CARTILLAS  
IF OBJECT_ID('tempdb..#PCCT') IS NOT NULL BEGIN DROP TABLE #PCCT  END   
IF OBJECT_ID('tempdb..#CalidadBase') IS NOT NULL BEGIN DROP TABLE #CalidadBase  END       
IF OBJECT_ID('tempdb..#TempLisTac') IS NOT NULL BEGIN DROP TABLE #TempLisTac  END       
IF OBJECT_ID('tempdb..#TempDet') IS NOT NULL BEGIN DROP TABLE #TempDet  END       
IF OBJECT_ID('tempdb..#TempValvular1') IS NOT NULL BEGIN DROP TABLE #TempValvular1  END       
IF OBJECT_ID('tempdb..#TempValvular2') IS NOT NULL BEGIN DROP TABLE #TempValvular2  END       
IF OBJECT_ID('tempdb..#DetResolved') IS NOT NULL BEGIN DROP TABLE #DetResolved  END   
IF OBJECT_ID('tempdb..#CARTILLA_1') IS NOT NULL BEGIN DROP TABLE #CARTILLA_1  END   
IF OBJECT_ID('tempdb..#CARTILLA_2') IS NOT NULL BEGIN DROP TABLE #CARTILLA_2  END  
IF OBJECT_ID('tempdb..#ArticulosCategoriaCalibre') IS NOT NULL BEGIN DROP TABLE #ArticulosCategoriaCalibre  END       
  
  
  
