USE [databyte]
GO
/****** Object:  StoredProcedure [dbo].[POS_Plu_Generation]    Script Date: 22/11/2017 10:37:05 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
ALTER PROCEDURE [dbo].[POS_Plu_Generation] 
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

   
	--2012-10-18 Paul M. added PLU style resend entity 925
	--2012-10-18 Paul M. DISTINCT BCP SELECT
	--2012-10-18 Paul M. added join to me_01..size_category to populate size code
	--2012-10-31 Paul M. removed Stylesummary from SELECT which populates ##POS_ITEMDCN.  Timing issues with styles not yet in stylesummary were resulting in missing records in the output.
	--2013-10-16 David M. Removed update that set Cost = d.last_net_po_cost 
	--2013-10-25 Michael M. added in new section to get current price 
	/*
	2015-07-30 Paul M. adding logic for Emporium
	Insering every line from final temp table back into temp table replacing actual brand code with brand code 08 (Emporium).
	*/

	IF OBJECT_ID('tempdb..##POS_ITEMDCN') IS NOT NULL DROP TABLE ##POS_ITEMDCN;
	CREATE TABLE ##POS_ITEMDCN (Item varchar(10), SKU varchar(20), ItemID VARCHAR(20), Div VARCHAR(20), ItemName varchar(30), ItemDesc varchar(50) --6
		, Dept VARCHAR(20), SubDept VARCHAR(20), Cat VARCHAR(10), SubCat VARCHAR(10), SizeCode varchar(10), SizeType varchar(4), ColorCode varchar(10) --13
		, StyleCode varchar(20), LifestyleCode varchar(4), Brand varchar(30), Season varchar(10), PermPrice VARCHAR(20), MfgSugPrice VARCHAR(20) --19
		, POSDesc varchar(50), DiscountCode VARCHAR(20), CustDiscountCode VARCHAR(20), EmplDiscountCode VARCHAR(20), ThreshDiscountCode VARCHAR(20), MarkdownCode VARCHAR(20), PriceOverrideCode VARCHAR(20) --26
		, AlertCode varchar(20), Class VARCHAR(20), SubClass VARCHAR(20), FiscalYear VARCHAR(20), MeasUnitCode varchar(4), WtUnitCode varchar(4), PkgWt VARCHAR(10) --33
		, CustOrderFlg VARCHAR(20), DirectOrderFlg VARCHAR(20), ItemKeyWord varchar(25), TaxGroup VARCHAR(20), AcctRestrictID VARCHAR(20), AccntLimitFlg VARCHAR(20) --39
		, AgeRestrictCode varchar(10), SpecialRestrictCode varchar(10), AllowQtyKeyFlg VARCHAR(20), PriceEntryFlg VARCHAR(20), SerialNoFlg VARCHAR(20) --44
		, OpenDrawerFlg VARCHAR(20), SpiffCode varchar(10), BusDiscountCode VARCHAR(20), AllowRetFlg VARCHAR(20), CouponMltplFlg VARCHAR(20), PriceVerifyFlg VARCHAR(20) --50
		, WeightEntryFlg VARCHAR(20), CustLoyaltyFlg VARCHAR(20), CustLoyaltyCnt VARCHAR(20), CouponFlg VARCHAR(20), FoodStampFlg VARCHAR(20), GiveAwayFlg VARCHAR(20) --56
		, PromotionFlg VARCHAR(20), Cost VARCHAR(20), UnitPriceFactor varchar(10), LongItemDesc varchar(255), ImageName varchar(255), ItemStatusCode VARCHAR(20) --62
		, Alerttype varchar(4), AssociationGrpId VARCHAR(20), ModelNum varchar(50), PriceAuthAmt VARCHAR(20), ActivateFlg VARCHAR(20), TenderTypeId VARCHAR(20) --68
		, ItemTypeCode varchar(4), color_desc VARCHAR(20), upc_number varchar(14), NZPrice varchar(20), Company varchar(10), RSAPrice varchar(20),color_id int --) --73
		, USAPrice varchar(20) )


	DECLARE @last_core_rep_id BIGINT, @max_core_rep_id BIGINT
	SELECT TOP 1 @last_core_rep_id = ISNULL(to_core_replication_queue_id,0) FROM dbo.[_plu_rep_audit] ORDER BY id DESC
	SELECT @max_core_rep_id = MAX(core_replication_queue_id) FROM me_01..core_replication_queue

	--INSERT INTO dbo.[_plu_rep_audit] (from_core_replication_queue_id, to_core_replication_queue_id, last_update)
	--SELECT 14070000, 14070000, GETDATE()
	--DELETE FROM _plu_rep_audit WHERE id IN(25119,25118,25117,25116,25115,25114)
	--SELECT * FROM _plu_rep_audit order by last_update desc

	SET @last_core_rep_id = ISNULL(@last_core_rep_id,0)

	SELECT @last_core_rep_id, @max_core_rep_id

	IF OBJECT_ID('tempdb..#style_changes') IS NOT NULL DROP TABLE #style_changes;
	CREATE TABLE #style_changes (style_id BIGINT)

	---------------------------------------------------------------------------------
	--Get Style Changes
	---------------------------------------------------------------------------------
	--style 301, 302 style reclass AND 925 PLU Style Resend
	INSERT INTO	#style_changes ( style_id )
	SELECT entity_id
	FROM me_01..core_replication_queue cq
	WHERE cq.entity_code IN (301,302,925)
	AND cq.replication_action<>'X'
	AND core_replication_queue_id BETWEEN @last_core_rep_id AND @max_core_rep_id

	--310 style desc
	INSERT INTO	#style_changes ( style_id )
	SELECT sd.style_id
	FROM me_01..core_replication_queue cq
	INNER JOIN me_01..style_description sd ON cq.entity_id = sd.style_description_id
	WHERE cq.entity_code IN (310)
	AND cq.replication_action<>'X'	
	AND core_replication_queue_id BETWEEN @last_core_rep_id AND @max_core_rep_id

	--311	style color
	INSERT INTO	#style_changes ( style_id )
	SELECT sc.style_id
	FROM me_01..core_replication_queue cq
	INNER JOIN me_01..style_color sc ON cq.entity_id = sc.style_color_id
	WHERE cq.entity_code IN (311,312,313,314,315,317)
	AND cq.replication_action<>'X'	
	AND core_replication_queue_id BETWEEN @last_core_rep_id AND @max_core_rep_id

	--351	sku
	INSERT INTO	#style_changes ( style_id )
	SELECT sk.style_id
	FROM me_01..core_replication_queue cq
	INNER JOIN me_01..sku sk ON cq.entity_id = sk.sku_id
	WHERE cq.entity_code IN (351)
	AND cq.replication_action<>'X'	
	AND core_replication_queue_id BETWEEN @last_core_rep_id AND @max_core_rep_id

	--322 style detail
	INSERT INTO	#style_changes ( style_id )
	SELECT sd.style_id
	FROM me_01..core_replication_queue cq
	INNER JOIN me_01..style_detail sd ON cq.entity_id = sd.style_detail_id
	WHERE cq.entity_code IN (321,331)
	AND cq.replication_action<>'X'		
	AND core_replication_queue_id BETWEEN @last_core_rep_id AND @max_core_rep_id

	--452 style attribute
	INSERT INTO	#style_changes ( style_id )
	SELECT entity_id
	FROM me_01..core_replication_queue cq
	WHERE cq.entity_code IN (452)
	AND cq.replication_action<>'X'	
	AND core_replication_queue_id BETWEEN @last_core_rep_id AND @max_core_rep_id

	INSERT INTO	#style_changes ( style_id )
	SELECT primary_entity_key
	FROM me_01..core_replication_queue cq
	WHERE cq.entity_code IN (512)
	and replication_action = 'I'
	AND core_replication_queue_id BETWEEN @last_core_rep_id AND @max_core_rep_id
	AND ISNUMERIC(primary_entity_key) = 1

	--361 upc
	INSERT INTO	#style_changes ( style_id )
	SELECT style_id
	FROM me_01..core_replication_queue cq
	inner join me_01..upc u on u.upc_id = cq.entity_id
	inner join me_01..sku s on s.sku_id = u.sku_id
	WHERE cq.entity_code IN (361)
	AND cq.replication_action<>'X'	
	AND core_replication_queue_id BETWEEN @last_core_rep_id AND @max_core_rep_id

	--select * from #style_changes

		INSERT INTO ##POS_ITEMDCN (Item, ItemID, SKU, StyleCode, ItemName,ItemDesc,Dept,Season,PermPrice,POSDesc,DiscountCode,CustDiscountCode,EmplDiscountCode,ThreshDiscountCode
				,MarkdownCode,PriceOverrideCode,FiscalYear,PkgWt,TaxGroup,AllowQtyKeyFlg,PriceEntryFlg,AllowRetFlg,PromotionFlg,Cost,ItemStatusCode,ItemTypeCode, ModelNum
				, Color_desc, NZPrice, ColorCode, SizeType,RSAPrice,color_id, USAPrice)
		SELECT distinct Item = 'Item'
			  , ItemID = s.style_id
			  , SKU = k.sku_id
			  , StyleCode = s.style_code
			  , ItemName = s.short_desc
			  , ItemDesc = s.short_desc
			  , Dept = null
			  , season = sn.season_code
			  , PermPrice = dbo.fn_SellPricebyJurisdiction (1, getdate(), s.style_code)
			  , POSDesc = s.plu_desc
			  , DiscountCode = 3
			  , CustDiscountCode = 3
			  , EmplDiscountCode = 3
			  , ThreshDiscountCode = 3
			  , MarkdownCode = 3
			  , PriceOverrideCode = 1
			  , FiscalYear = null
			  , PkgWt = 0
			  , TaxGroup = 10
			  , AllowQtyKeyFlg = 1
			  , PriceEntryFlg = 0
			  , AllowRetFlg = 1
			  , PromotionFlg = CASE WHEN s.promo_flag = 0 THEN 1 ELSE 0 END
			  , Cost = sd.last_net_final_po_cost
			  , ItemStatusCode = 'ACTV'
			  , ItemTypeCode = 'MDSE'
			  , ModelNum = null
			  , color_desc = sc.long_desc
			  , NZPrice = dbo.fn_SellPricebyJurisdiction (2, getdate(), s.style_code)
			  , ColorCode = c.color_code
				, SizeType = scat.size_category_code
				, RSAPrice = dbo.fn_SellPricebyJurisdiction (7, getdate(), s.style_code)
				,sc.color_id
				, USAPrice = dbo.fn_SellPricebyJurisdiction (3, getdate(), s.style_code)
		FROM	me_01.dbo.style s (NOLOCK) 
				INNER JOIN me_01..sku k (NOLOCK) ON s.style_id = k.style_id
				INNER JOIN me_01.dbo.style_color sc (NOLOCK) ON s.style_id = sc.style_id AND k.style_color_id = sc.style_color_id
				INNER JOIN me_01.dbo.color c (NOLOCK) ON sc.color_id = c.color_id 
				INNER JOIN me_01.dbo.entity_attribute_set eas (NOLOCK) ON s.style_id = eas.parent_id
				INNER JOIN me_01.dbo.attribute_set ats (NOLOCK) ON eas.attribute_set_id = ats.attribute_set_id
				INNER JOIN me_01.dbo.attribute a (NOLOCK) ON ats.attribute_id = a.attribute_id 
				INNER JOIN me_01.dbo.size_category AS scat (NOLOCK) ON s.size_category_id = scat.size_category_id
				INNER JOIN me_01.dbo.season AS sn (NOLOCK) ON s.season_id = sn.season_id
				 INNER JOIN me_01.dbo.style_detail AS sd (NOLOCK) ON s.style_id = sd.style_id
		WHERE	s.active_flag = 1
				AND s.style_id IN (SELECT DISTINCT style_id FROM #style_changes)


		
   UPDATE   p
   SET      PermPrice = [scr].[current_selling_retail]
   FROM     ##POS_ITEMDCN p
            INNER JOIN [databyte].dbo.[v_style_colour] AS [vsc] ON p.[StyleCode] = [vsc].[style_code]
                                                              AND p.[ColorCode] = vsc.[color_code]
            INNER JOIN [me_01].dbo.[style_color_retail] AS scr ON [vsc].[style_color_id] = [scr].[style_color_id]
   WHERE    [scr].[jurisdiction_id] = 1;


   UPDATE   p
   SET      NZPrice = [scr].[current_selling_retail]
   FROM     ##POS_ITEMDCN p
            INNER JOIN [databyte].dbo.[v_style_colour] AS [vsc] ON p.[StyleCode] = [vsc].[style_code]
                                                              AND p.[ColorCode] = vsc.[color_code]
            INNER JOIN [me_01].dbo.[style_color_retail] AS scr ON [vsc].[style_color_id] = [scr].[style_color_id]
   WHERE    [scr].[jurisdiction_id] = 2;

                
   UPDATE   p
   SET      USAPrice = [scr].[current_selling_retail]
   FROM     ##POS_ITEMDCN p
            INNER JOIN [databyte].dbo.[v_style_colour] AS [vsc] ON p.[StyleCode] = [vsc].[style_code]
                                                              AND p.[ColorCode] = vsc.[color_code]
            INNER JOIN [me_01].dbo.[style_color_retail] AS scr ON [vsc].[style_color_id] = [scr].[style_color_id]
   WHERE    [scr].[jurisdiction_id] = 3;                                               

                
   UPDATE   p
   SET      RSAPrice = [scr].[current_selling_retail]
   FROM     ##POS_ITEMDCN p
            INNER JOIN [databyte].dbo.[v_style_colour] AS [vsc] ON p.[StyleCode] = [vsc].[style_code]
                                                              AND p.[ColorCode] = vsc.[color_code]
            INNER JOIN [me_01].dbo.[style_color_retail] AS scr ON [vsc].[style_color_id] = [scr].[style_color_id]
   WHERE    [scr].[jurisdiction_id] = 7;                                             


	
		ALTER TABLE ##POS_ITEMDCN
		DROP COLUMN color_id		
			
		--/////////////////////////////// End of new section ////////////////////////////////////////////////////		

	--SELECT TOP 100 * FROM ##POS_ITEMDCN


	UPDATE i
	SET sizecode = UPPER(SUBSTRING(sm.prim_size_label,1,4))
	--SELECT  *
	FROM ##POS_ITEMDCN i 
	INNER JOIN me_01..sku k ON i.sku = k.sku_id
	INNER JOIN me_01..style_size sz ON sz.style_id = k.style_id AND sz.style_size_id = k.style_size_id
	inner join me_01..size_master sm on sm.size_master_id = sz.size_master_id
	inner join me_01..size_category sc on sm.size_category_id = sc.size_category_id
	where sc.number_of_dimensions = 1

	UPDATE i
	SET sizecode = UPPER(SUBSTRING(sm.prim_size_label,1,4)), SubCat = sm.sec_size_label
	--SELECT  *
	FROM ##POS_ITEMDCN i 
	INNER JOIN me_01..sku k ON i.sku = k.sku_id
	INNER JOIN me_01..style_size sz ON sz.style_id = k.style_id AND sz.style_size_id = k.style_size_id
	inner join me_01..size_master sm on sm.size_master_id = sz.size_master_id
	inner join me_01..size_category sc on sm.size_category_id = sc.size_category_id
	where sc.number_of_dimensions = 2


	DELETE FROM ##POS_ITEMDCN WHERE ItemID = ''

	--update i set Cost = d.last_net_po_cost
	--from ##POS_ITEMDCN i 
	--inner join me_01..style_detail d on i.ItemID = d.style_id

	update i set Dept = h.pos_merch_group_key, Company = LEFT(h.hierarchy_group_code,2)
	from ##POS_ITEMDCN i 
	inner join me_01..style s on i.StyleCode = s.style_code
	inner join me_01..style_group d on s.style_id = d.style_id 
	inner join me_01..hierarchy_group h on d.hierarchy_group_id = h.hierarchy_group_id 


	UPDATE i SET season = season_code + cast(calendar_year_code AS varchar)
	FROM ##POS_ITEMDCN i 
	INNER JOIN me_01..style s on i.StyleCode = s.style_code
	INNER JOIN me_01..season se ON s.season_id = se.season_id
	INNER JOIN me_01..calendar_year cy ON s.calendar_year_id = cy.calendar_year_id

	DELETE FROM ##POS_ITEMDCN WHERE sku = ''

	UPDATE i SET upc_number = u.upc_number
	FROM ##POS_ITEMDCN i 
	INNER JOIN me_01..upc u ON i.sku = u.sku_id

	DELETE FROM ##POS_ITEMDCN WHERE upc_number IS NULL

	--UPDATE i SET PermPrice = m.retaus
	--FROM ##POS_ITEMDCN i 
	--INNER JOIN [sfg-src-prd].NSB_Sourcing.dbo.magic_products m ON i.stylecode = m.product
	--WHERE i.permPrice = '0.00'

	UPDATE ##POS_ITEMDCN SET ItemName = REPLACE(ItemName,',',''), ItemDesc = REPLACE(ItemDesc,',',''), POSDesc = REPLACE(POSDesc,',',''), color_desc = REPLACE(color_desc,',','')

	UPDATE ##POS_ITEMDCN 
	SET Company = atse.attribute_set_code
	FROM    me_01.dbo.attribute_set AS atse
			INNER JOIN me_01.dbo.entity_attribute_set AS eas ON atse.attribute_set_id = eas.attribute_set_id
			INNER JOIN StyleSummary AS ss ON eas.parent_id = ss.category_id
			INNER JOIN ##POS_ITEMDCN ON ss.style_code = ##POS_ITEMDCN.StyleCode
	        
			WHERE   ( ss.brand_code = '12' ) --Brand 12 is consignment
			AND ( eas.parent_type = 5 ) --entity type 5 is Merch hierarchy group
			AND ( eas.attribute_id = 175 ) --attribute_id 175 is the new PLU BRAND attribute which is attached to Merchandise hierarchy groups
	

--Insert items back into ##POS_ITEMDCN, substituting product brand with Emporium brand (08)
INSERT INTO ##POS_ITEMDCN (Item,SKU,ItemID,Div,ItemName,ItemDesc,Dept,SubDept,Cat,SubCat,SizeCode,SizeType,ColorCode,StyleCode,LifestyleCode,Brand,Season,PermPrice,MfgSugPrice,POSDesc,DiscountCode,CustDiscountCode,EmplDiscountCode,ThreshDiscountCode,MarkdownCode,PriceOverrideCode,AlertCode,Class,SubClass,FiscalYear,MeasUnitCode,WtUnitCode,PkgWt,CustOrderFlg,DirectOrderFlg,ItemKeyWord,TaxGroup,AcctRestrictID,AccntLimitFlg,AgeRestrictCode,SpecialRestrictCode,AllowQtyKeyFlg,PriceEntryFlg,SerialNoFlg,OpenDrawerFlg,SpiffCode,BusDiscountCode,AllowRetFlg,CouponMltplFlg,PriceVerifyFlg,WeightEntryFlg,CustLoyaltyFlg,CustLoyaltyCnt,CouponFlg,FoodStampFlg,GiveAwayFlg,PromotionFlg,Cost,UnitPriceFactor,LongItemDesc,ImageName,ItemStatusCode,Alerttype,AssociationGrpId,ModelNum,PriceAuthAmt,ActivateFlg,TenderTypeId,ItemTypeCode,color_desc,upc_number,NZPrice,Company,RSAPrice,USAPrice)
SELECT Item,SKU,ItemID,Div,ItemName,ItemDesc,Dept,SubDept,Cat,SubCat,SizeCode,SizeType,ColorCode,StyleCode,LifestyleCode,Brand,Season,PermPrice,MfgSugPrice,POSDesc,DiscountCode,CustDiscountCode,EmplDiscountCode,ThreshDiscountCode,MarkdownCode,PriceOverrideCode,AlertCode,Class,SubClass,FiscalYear,MeasUnitCode,WtUnitCode,PkgWt,CustOrderFlg,DirectOrderFlg,ItemKeyWord,TaxGroup,AcctRestrictID,AccntLimitFlg,AgeRestrictCode,SpecialRestrictCode,AllowQtyKeyFlg,PriceEntryFlg,SerialNoFlg,OpenDrawerFlg,SpiffCode,BusDiscountCode,AllowRetFlg,CouponMltplFlg,PriceVerifyFlg,WeightEntryFlg,CustLoyaltyFlg,CustLoyaltyCnt,CouponFlg,FoodStampFlg,GiveAwayFlg,PromotionFlg,Cost,UnitPriceFactor,LongItemDesc,ImageName,ItemStatusCode,Alerttype,AssociationGrpId,ModelNum,PriceAuthAmt,ActivateFlg,TenderTypeId,ItemTypeCode,color_desc,upc_number,NZPrice,'08' AS [Company],RSAPrice,USAPrice
FROM ##POS_ITEMDCN p
WHERE [Company] NOT IN ('06', '07', '08')

--Insert Crossroads items back into ##POS_ITEMDCN, substituting product brand with Millers brand (01)
INSERT INTO ##POS_ITEMDCN (Item,SKU,ItemID,Div,ItemName,ItemDesc,Dept,SubDept,Cat,SubCat,SizeCode,SizeType,ColorCode,StyleCode,LifestyleCode,Brand,Season,PermPrice,MfgSugPrice,POSDesc,DiscountCode,CustDiscountCode,EmplDiscountCode,ThreshDiscountCode,MarkdownCode,PriceOverrideCode,AlertCode,Class,SubClass,FiscalYear,MeasUnitCode,WtUnitCode,PkgWt,CustOrderFlg,DirectOrderFlg,ItemKeyWord,TaxGroup,AcctRestrictID,AccntLimitFlg,AgeRestrictCode,SpecialRestrictCode,AllowQtyKeyFlg,PriceEntryFlg,SerialNoFlg,OpenDrawerFlg,SpiffCode,BusDiscountCode,AllowRetFlg,CouponMltplFlg,PriceVerifyFlg,WeightEntryFlg,CustLoyaltyFlg,CustLoyaltyCnt,CouponFlg,FoodStampFlg,GiveAwayFlg,PromotionFlg,Cost,UnitPriceFactor,LongItemDesc,ImageName,ItemStatusCode,Alerttype,AssociationGrpId,ModelNum,PriceAuthAmt,ActivateFlg,TenderTypeId,ItemTypeCode,color_desc,upc_number,NZPrice,Company,RSAPrice,USAPrice)
SELECT Item,SKU,ItemID,Div,ItemName,ItemDesc,Dept,SubDept,Cat,SubCat,SizeCode,SizeType,ColorCode,StyleCode,LifestyleCode,Brand,Season,PermPrice,MfgSugPrice,POSDesc,DiscountCode,CustDiscountCode,EmplDiscountCode,ThreshDiscountCode,MarkdownCode,PriceOverrideCode,AlertCode,Class,SubClass,FiscalYear,MeasUnitCode,WtUnitCode,PkgWt,CustOrderFlg,DirectOrderFlg,ItemKeyWord,TaxGroup,AcctRestrictID,AccntLimitFlg,AgeRestrictCode,SpecialRestrictCode,AllowQtyKeyFlg,PriceEntryFlg,SerialNoFlg,OpenDrawerFlg,SpiffCode,BusDiscountCode,AllowRetFlg,CouponMltplFlg,PriceVerifyFlg,WeightEntryFlg,CustLoyaltyFlg,CustLoyaltyCnt,CouponFlg,FoodStampFlg,GiveAwayFlg,PromotionFlg,Cost,UnitPriceFactor,LongItemDesc,ImageName,ItemStatusCode,Alerttype,AssociationGrpId,ModelNum,PriceAuthAmt,ActivateFlg,TenderTypeId,ItemTypeCode,color_desc,upc_number,NZPrice,'01' AS [Company],RSAPrice,USAPrice
FROM ##POS_ITEMDCN p
WHERE [Company]  IN ('05')


	INSERT INTO dbo.[_plu_rep_audit] (from_core_replication_queue_id, to_core_replication_queue_id, last_update)
	SELECT @last_core_rep_id, @max_core_rep_id, GETDATE()
	
	DECLARE @sout VARCHAR(1000), @filename VARCHAR(50)
	SET @sout = ''
	SET @filename = 'PRD' + CONVERT(VARCHAR(10), GETDATE(), 112) + REPLACE(CONVERT(VARCHAR(5), GETDATE(),108),':','') +  '.txt'  
	SET @sout = 'bcp "select DISTINCT * from ##POS_ITEMDCN" queryout "\\dev-tailor-sa1\nsbpolldata$\' + @filename + '" -c -t "," -Slocalhost -Usvc-SQL_FileWriter -PVz9*Zcm4'
	PRINT @sout
	EXEC master..xp_cmdshell @sout


				--\\tailor-sa1\nsbpolldata$\  -- need to replace location of where the file gets main when deployed to live
				--\\smoogle\public\michael\  --for testing
END

