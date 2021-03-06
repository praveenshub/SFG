USE [databyte]
GO
/****** Object:  StoredProcedure [dbo].[REPMO38SOHByPack_Extra]    Script Date: 28/11/2017 3:44:53 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROC [dbo].[REPMO38SOHByPack_Extra] 
@FromStore varchar(10), @ToStore varchar(10), @Product varchar(1000), @ProdBrand VARCHAR(100), @ProdDept VARCHAR(100)
	,@cost varchar(20)

--SET @FromStore= '0001' 
--SET @ToStore = '0001'
--SET @Product = NULL
--SET @LocationType = NULL
--set @ProdBrand = null
--SET @ProdDept = null
--SET @cost = ''

--EXEC [REPMO38SOHByPack_Extra] '0001','0001','00003461','02','02-20',''
--EXEC [REPMO38SOHByPack_Extra] '0001','0001','NULL','NULL','NULL','NULL'
--EXEC [REPMO38SOHByPack] 'NULL','NULL','NULL','2,4','01'
--EXEC [REPMO38SOHByPack] 'NULL','NULL','NULL','NULL','NULL','NULL'


AS

--select top 10 * from [me_01].[dbo].sku

IF @FromStore = 'NULL' BEGIN SELECT TOP 1 @FromStore = [location_code] FROM [LocationSummary] ORDER BY CAST([location_code] AS INT)  END
IF @ToStore = 'NULL' BEGIN SELECT TOP 1 @ToStore = [location_code] FROM [LocationSummary] ORDER BY CAST([location_code] AS INT) DESC END 

PRINT @FromStore PRINT @ToStore

--SELECT * INTO #LocationSummary FROM [LocationSummary] WHERE [location_code] BETWEEN '0001' AND '0001'
SELECT * INTO #LocationSummary FROM [LocationSummary] (NOLOCK) WHERE CAST([location_code] AS INT) BETWEEN CAST(@FromStore AS INT) AND CAST(@ToStore AS INT)
SELECT * INTO #StyleSummary FROM [StyleSummary] (NOLOCK)

PRINT @Product 
--IF @Product <> 'NULL' BEGIN DELETE FROM #StyleSummary  WHERE [style_code] NOT IN (SELECT [value] FROM dbo.fn_Split(@Product,',')) END
IF @Product <> 'NULL' AND @product IS NOT null BEGIN DELETE FROM [#StyleSummary] WHERE [style_code] <> @Product END
PRINT @ProdBrand
IF @ProdBrand <> 'NULL' BEGIN DELETE FROM #StyleSummary WHERE [brand_code] NOT IN (SELECT value FROM dbo.[fn_Split](@ProdBrand,',')) END 
PRINT @ProdDept
IF @ProdDept <> 'NULL' BEGIN DELETE FROM #StyleSummary WHERE [department_code] NOT IN (SELECT value FROM dbo.[fn_Split](@ProdDept,',')) END 

SELECT l.[location_id],l.[location_code],l.[location_name],l.[brand_label],ss.[brand_name],ss.[style_code],
ps.[color_code], ps.[color_long_desc],
ss.[long_desc],
ps.[vendor_code],ss.[season],
ib.[total_on_hand_units] AS totalpacks,
ps.[pack_size], ib.[total_on_hand_units] * ps.[pack_size] AS units,
ps.[pack_id],ps.[pack_code],ps.[pack_description]
INTO #total
FROM [me_01].[dbo].[ib_pack_inventory_total] ib (NOLOCK)
INNER JOIN #LocationSummary l ON ib.[location_id] = l.[location_id]
INNER JOIN [v_PackSummary] ps ON ps.[pack_id] = ib.[pack_id]
INNER JOIN #StyleSummary ss ON ps.[style_id] = ss.[style_id]
WHERE ISNULL(ib.[total_on_hand_units],0) <> 0

--to do worklist from receipted stock.
SELECT l.[location_id],l.[location_code], l.[location_name], l.[brand_label], s.[brand_name],
s.[style_code], ps.[color_code], ps.[color_long_desc],
s.[long_desc],ps.[vendor_code],s.[season],
SUM(td.[po_line_total_units]) AS totalpacks,
ps.[pack_size]*SUM(td.[po_line_total_units]) AS units, 
ps.[pack_size],ps.[pack_id],ps.[pack_code],ps.[pack_description]

--added by noe 20130627
,MAX(pod.Dist_Channel_cd) AS [Distribution_Channel]
,MAX(pod.Consolidation_Cd) AS Consolidation_Code
,MAX(pod.POs_To_Consolidate) AS POs_To_Consolidate
,MAX(pod.PO_Consolidation_Remarks) AS Consolidation_Remarks
,SUM(pod.Consolidation_Qty) AS Consolidation_Qty

INTO #todo
FROM [me_01].[dbo].[to_do_entry] td (NOLOCK) 
INNER JOIN [v_PackSummary] ps ON td.[pack_id] = ps.[pack_id]
INNER JOIN [#LocationSummary] l ON l.[location_id] = td.[location_id]
INNER JOIN [#StyleSummary] s ON s.[style_id] = ps.[style_id]

--select top 100 * from [SFG-SRC-PRD].SFG_Live.dbo.Purchase_Order_Detail pod

--added by noe 20130627
LEFT JOIN [DEVSRCPRD01].SFG_Live.dbo.Purchase_Order_Header poh (NOLOCK) ON poh.PO_ID = td.po_id
LEFT JOIN [DEVSRCPRD01].SFG_Live.dbo.Purchase_Order_Detail pod (NOLOCK) ON poh.Po_No = pod.Po_No 
					AND td.po_line_id = pod.Po_LineNo

WHERE td.[document_source] IN(1,5,6) AND [request_type] = 1
and ISNULL(td.[po_line_total_units],0) <> 0
GROUP BY l.[location_id],l.[location_code], l.[location_name], l.[brand_label], s.[brand_name],
s.[style_code], ps.[color_code], ps.[color_long_desc],
s.[long_desc],ps.[vendor_code],s.[season],
ps.[pack_size],ps.[pack_id],ps.[pack_code],ps.[pack_description]

SELECT l.[location_id],ps.pack_id,
SUM(td.[po_line_total_units]) AS totalpacks

--added by noe 20130627
,MAX(pod.Dist_Channel_cd) AS [Distribution_Channel]
,MAX(pod.Consolidation_Cd) AS Consolidation_Code
,MAX(pod.POs_To_Consolidate) AS POs_To_Consolidate
,MAX(pod.PO_Consolidation_Remarks) AS Consolidation_Remarks
,SUM(pod.Consolidation_Qty) AS Consolidation_Qty

INTO #rework
--SELECT COUNT(*)
FROM [me_01].[dbo].[to_do_entry] td (NOLOCK) 
INNER JOIN [v_PackSummary] ps ON td.[pack_id] = ps.[pack_id]
INNER JOIN [#LocationSummary] l ON l.[location_id] = td.[location_id]
INNER JOIN [#StyleSummary] s ON s.[style_id] = ps.[style_id]

--added by noe 20130627
LEFT JOIN [DEVSRCPRD01].SFG_Live.dbo.Purchase_Order_Header poh (NOLOCK) ON poh.PO_ID = td.po_id
LEFT JOIN [DEVSRCPRD01].SFG_Live.dbo.Purchase_Order_Detail pod (NOLOCK) ON poh.Po_No = pod.Po_No 
					AND td.po_line_id = pod.Po_LineNo

WHERE td.[document_source] IN (1,5,6) AND [request_type] = 6
and ISNULL(td.[po_line_total_units],0) <> 0
GROUP BY l.[location_id],ps.[pack_id]

--distributions that don't'
SELECT l.[location_id],ps.[pack_id],
CASE WHEN ISNULL(ps.[pack_size],0)<>0 THEN SUM(dl.[total_distributed_detail_qty])/ps.[pack_size] ELSE 0 END AS totalpacks 
--SUM(dl.[total_distributed_detail_qty])/ps.[pack_size] AS totalpacks

--added by noe 20130627
,MAX(pod.Dist_Channel_cd) AS [Distribution_Channel]
,MAX(pod.Consolidation_Cd) AS Consolidation_Code
,MAX(pod.POs_To_Consolidate) AS POs_To_Consolidate
,MAX(pod.PO_Consolidation_Remarks) AS Consolidation_Remarks
,SUM(pod.Consolidation_Qty) AS Consolidation_Qty

INTO #distros
FROM [me_01].[dbo].[distribution] d (NOLOCK)
INNER JOIN [me_01].[dbo].[dist_line] dl ON d.[distribution_id] = dl.[distribution_id]
INNER JOIN [v_PackSummary] ps ON ps.[pack_id] = dl.[pack_id]
INNER JOIN [#LocationSummary] l ON l.[location_id] = d.[location_id]
INNER JOIN [#StyleSummary] s ON s.[style_id] = ps.[style_id]

--added by noe 20130627
LEFT JOIN [DEVSRCPRD01].SFG_Live.dbo.Purchase_Order_Header poh (NOLOCK) ON poh.PO_ID = d.po_id
LEFT JOIN [DEVSRCPRD01].SFG_Live.dbo.Purchase_Order_Detail pod (NOLOCK) ON poh.Po_No = pod.Po_No 
					AND dl.po_line_id = pod.Po_LineNo

--WHERE ([distribution_status] NOT IN (8,9)) --OR dl.[po_receipt_id] IS NOT NULL
WHERE ([document_source] IN(1,5,6) AND [distribution_status] NOT IN (8,9)) --OR dl.[po_receipt_id] IS NOT NULL
and ISNULL(dl.[total_distributed_detail_qty],0) <> 0
GROUP BY l.location_id, ps.pack_id, ps.[pack_size]

--UPDATE d
--SET d.[totalpacks] = r.[totalpacks]
--FROM [#distros] d
--INNER JOIN [#rework] r ON d.[location_id] = r.[location_id] AND d.[pack_id] = r.[pack_id]

SELECT ib.[location_id],ib.pack_id, SUM([total_on_order_units]) AS totalpacks 
INTO #onOrder
FROM [me_01].dbo.[ib_pack_on_order_total] ib (NOLOCK)

INNER JOIN [v_PackSummary] ps ON ps.[pack_id] = ib.[pack_id]
INNER JOIN [#LocationSummary] ls ON ib.[location_id] = ls.location_id
INNER JOIN [#StyleSummary] ss ON ps.[style_id] = ss.style_id
WHERE ISNULL(total_on_order_units,0) <> 0
GROUP BY ib.[location_id],ib.pack_id


--True Reserve = (SOH+OO)-(Distro+Todo)

--SELECT * FROM [#total]

SELECT * INTO #res FROM [#total]

UPDATE r
SET r.[totalpacks] = r.[totalpacks] + t.[totalpacks]
FROM #res r
INNER JOIN [#onOrder] t ON r.pack_id = t.pack_id AND r.location_id = t.[location_id]

UPDATE r
SET r.[totalpacks] = r.[totalpacks] - t.[totalpacks]
FROM #res r 
INNER JOIN #todo t ON r.pack_id = t.pack_id AND r.location_id = t.location_id

UPDATE r
SET r.[totalpacks] = r.[totalpacks] - t.[totalpacks]
FROM #res r 
INNER JOIN [#distros] t ON r.pack_id = t.pack_id AND r.location_id = t.location_id

/*
DROP TABLE [#todo]
DROP TABLE [#distros]
DROP TABLE [#total]
drop table #final
drop table #lines
*/

SELECT [location_id],[pack_id] INTO #Lines 
FROM [#total]
UNION
SELECT [location_id],[pack_id] FROM [#todo] 
UNION 
SELECT [location_id],[pack_id] FROM [#distros]

SELECT l.[location_id] AS locid, l.[pack_id] packid,t.*, ss.[department_code] AS dept_code, ss.[department_name] AS dept_name,0 AS NotAvail, 0 AS Distro, 0 AS Reserve,0 AS OnOrder

,CAST(NULL AS VARCHAR(255)) AS [Distribution_Channel]
,CAST(NULL AS VARCHAR(255)) AS Consolidation_Code
,CAST(NULL AS VARCHAR(500)) AS POs_To_Consolidate
,CAST(NULL AS VARCHAR(500)) AS Consolidation_Remarks
,CAST(NULL AS INT) AS Consolidation_Qty

INTO #final
FROM #Lines l
LEFT JOIN #total t ON t.[location_id] = l.[location_id] AND t.[pack_id] = l.[pack_id]
LEFT JOIN [#StyleSummary] ss ON t.[style_code] = ss.[style_code]

UPDATE [#final] SET [NotAvail] = 0, [Distro] = 0 

UPDATE f
SET [NotAvail] = [NotAvail] + ISNULL(t.[totalpacks],0)
	,f.Distribution_Channel = t.Distribution_Channel
	,f.Consolidation_Code = t.Consolidation_Code
	,f.POs_To_Consolidate = t.POs_To_Consolidate
	,f.Consolidation_Remarks = t.Consolidation_Remarks
	,f.Consolidation_Qty = t.Consolidation_Qty
FROM [#final] f, [#todo] t
WHERE f.[locid] = t.[location_id] AND f.[packid] = t.[pack_id]


UPDATE f
SET Distro = ISNULL(f.Distro,0) + ISNULL(t.[totalpacks],0)
	,f.Distribution_Channel = t.Distribution_Channel
	,f.Consolidation_Code = t.Consolidation_Code
	,f.POs_To_Consolidate = t.POs_To_Consolidate
	,f.Consolidation_Remarks = t.Consolidation_Remarks
	,f.Consolidation_Qty = t.Consolidation_Qty
FROM [#final] f, [#distros] t
WHERE f.[locid] = t.[location_id] AND f.[packid] = t.[pack_id]

UPDATE f
SET Reserve = r.[totalpacks]
FROM #final f
INNER JOIN [#res] r ON f.[packid] = r.pack_id AND f.[locid] = r.location_id

UPDATE f
SET f.[OnOrder] = o.[totalpacks]
FROM #final f
INNER JOIN [#onOrder] o ON f.[packid] = o.pack_id AND f.[locid] = o.[location_id]

--EXEC [REPMO38SOHByPack] 'NULL','NULL','00004140','NULL','NULL','NULL'
--EXEC [REPMO38SOHByPack_MM] '0001','0001','00002711','02','02-20',''

SELECT f.*, 
	CASE WHEN total_on_hand_units = 0 THEN 0 ELSE (total_on_hand_cost / total_on_hand_units) END AS cost
	,ps.sku_quantity, total_on_hand_units
INTO #final_cost
FROM #final f
INNER JOIN me_01..pack_sku ps (NOLOCK) ON f.pack_id = ps.pack_id
INNER JOIN me_01..ib_inventory_total i (NOLOCK) ON ps.sku_id = i.sku_id AND f.location_id = i.location_id
WHERE ISNULL(totalpacks,0) <> 0

SELECT MAX(f.location_code) AS location_code, MAX(f.location_name) AS location_name,
	   MAX(f.brand_label) AS brand_label, MAX(f.brand_name) AS brand_name, MAX(ss.[category_name]) AS Category,MAX(ss.[story_name]) AS story, 
	   MAX(f.style_code) AS style_code,
	   MAX(f.color_code) AS color_code, MAX(f.color_long_desc) AS color_long_desc, MAX(f.long_desc) AS long_desc, MAX(f.vendor_code) AS vendor_code,
	   MAX(f.season) AS season, ISNULL(MAX(f.totalpacks),0) AS totalpacks, MAX(NotAvail) AS NotAvail, MAX([Distro]) AS [distributed], 
	   MAX(ISNULL(OnOrder,0)) AS OnOrder,
	   MAX(Reserve) AS reserve,
	   --(ISNULL(MAX(totalpacks),0)-(ISNULL(MAX(NotAvail),0)+ISNULL(MAX(Distro),0))) AS reserveOld ,
	   MAX(pack_size) AS pack_size,
	   max(totalpacks * pack_size) AS pack_units,
	   pack_id,
	   MAX(pack_code) AS pack_code,
	   MAX(pack_description) AS pack_description,
	   CASE WHEN MAX(cost) = 0 THEN min(cost) ELSE MAX(cost) end AS cost,
	   SUM(cost * sku_quantity) as [Pack Cost],
	   SUM(cost * sku_quantity * totalpacks) as [Extended Cost],
	   MAX(f.dept_code) AS dept_code,
	   MAX(f.dept_name) AS dept_name,
	   MAX(ss.[original_retail]/ls.tax_rate*totalpacks * pack_size)AS [Extended_Original_Retail_ex_GST], MAX(ss.[Current_Retail]/ls.tax_rate *totalpacks * pack_size) AS [Extended_Current_Retail_ex_GST]
	   
	   ,MAX(Distribution_Channel) AS Distribution_Channel
	   ,MAX(Consolidation_Code) AS Consolidation_Code
	   ,MAX(POs_To_Consolidate) AS POs_To_Consolidate
	   ,MAX(Consolidation_Remarks) AS Consolidation_Remarks
	   ,SUM(Consolidation_Qty) AS Consolidation_Qty
	   
INTO #temp
FROM [#final_cost] f
INNER JOIN [#StyleSummary] ss ON ss.[style_code] = f.style_code
INNER JOIN [#LocationSummary] ls ON ls.location_code = f.location_code 
GROUP BY f.location_id, f.pack_id
--491

declare @sql varchar(2000)

set @sql='select * from #temp'

declare @cos varchar(50)
set @cos=convert(varchar(10),@cost,120)
if len(@cos)>0 and @cost <> 'NULL'
begin
set @sql =@sql+ '  where cost  '+ @cost 
end
exec(@sql)