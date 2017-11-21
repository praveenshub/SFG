USE [databyte]
GO
/****** Object:  StoredProcedure [dbo].[POS_Markdown_Export]    Script Date: 21/11/2017 4:16:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Michael Moura
-- Create date: 06/05/2013
-- Description:	creates a markdown file based on the new exception logic and sends the data to pos to process
-- =============================================
ALTER PROCEDURE [dbo].[POS_Markdown_Export]

----2013-05-21 Paul M. changed NULL in output fields to blank
----2015-07-02 Paul M. added logic to block New Zealand International prices from being exported.
----2017-11-21 Praveen D. Added logic to output fields for new merch 5.0


--/*
--	new logic is to remove all entries where the markdown location type is 2 and the md_type is not 
--	pricing group or pricing group\colour 

--	Marksdown document location key
	
--	0 = Jurisdiction
--	1 = Location
--	2 = Pricing Group
--*/

	/*
	2015-07-30 Paul M. adding logic for Emporium
	Added new "full_location_code" field to ##storeMarkdown to link to dummy pricing store 
	For Australian non-location level prices:
	Insering every line from final temp table back into temp table replacing actual brand code with brand code 08 (Emporium).
	For Australian location level prices:
	Replace dummy store record with record corresponding to each Emporium store mapped to the dummy store
	2016-04-01 Paul M. added logic to delete all temporary price change records from the Emporium output	
	2017-01-23 Paul M. addded logic to parameterise which brands temporary price change records will be blocked from going to OW.
		The business request is for all brands' temporary price change records to go to OW
	*/
AS
    BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
        SET NOCOUNT ON;

        IF OBJECT_ID('tempdb..#one_woman_promo_brands') IS NOT NULL
            DROP TABLE #one_woman_promo_brands;
        CREATE TABLE #one_woman_promo_brands
            (
             brand_code VARCHAR(2) PRIMARY KEY CLUSTERED
            );
        INSERT  INTO #one_woman_promo_brands
                ( brand_code )
      SELECT DISTINCT brand_code FROM databyte.dbo.StyleSummary ss WHERE ss.brand_code BETWEEN '01' AND '05'

        IF OBJECT_ID('tempdb..#pos_Markdowns') IS NOT NULL
            DROP TABLE #pos_Markdowns
        IF OBJECT_ID('tempdb..#plu_price') IS NOT NULL
            DROP TABLE #plu_price
        IF OBJECT_ID('tempdb..##storeMarkdown') IS NOT NULL
            DROP TABLE ##storeMarkdown
	
--	truncate table databyte..#pos_Markdowns


        SELECT  *
        INTO    #plu_price
        FROM    [me_01].[dbo].[plu_price_change]
        WHERE   plu_price_change_id >= ( SELECT last_plu_price_change_id + 1
                                         FROM   databyte..markdown_Last_Queue_Item
                                         WHERE  id = ( SELECT MAX(id)
                                                       FROM   databyte..markdown_Last_Queue_Item
                                                       WHERE  comment = 'success'
                                                     )
                                       )
--	select * from #plu_price
        IF ( ( SELECT   COUNT(*)
               FROM     #plu_price
             ) > 0 )
            BEGIN

                CREATE TABLE #pos_Markdowns
                    (
                     md_type_id INT
                    ,price_change_no VARCHAR(20)
                    ,jurisdiction_code VARCHAR(20)
                    ,effective_from_date VARCHAR(10)
                    ,effective_to_date VARCHAR(10)
                    ,style_code VARCHAR(20)
                    ,new_price DECIMAL(14, 2)
                    ,brand VARCHAR(20)
                    ,long_colour_description VARCHAR(100)
                    ,location_code VARCHAR(4)
                    ,price_change_id DECIMAL(12, 0)
                    ,price_status_desc VARCHAR(30)
                    ,style_id DECIMAL(12, 0)
                    ,price_change_style_id DECIMAL(12, 0)
                    ,md_type VARCHAR(20)
                    ,location_grouping INT
                    )
		--exec tempdb..sp_help '#pos_Markdowns'
		--exec tempdb..sp_help '#chain'



		--***Get Chain Markdowns ***
                INSERT  INTO #pos_Markdowns
                        SELECT  1
                        ,
	--	'1' + substring(pc.price_change_no,2,len(pc.price_change_no)) as price_change_no
                                pc.price_change_no
                        ,       j.jurisdiction_code
                        ,       CONVERT(VARCHAR(10), pc.effective_from_date, 120) AS effective_from_date
		--, case when pc.effective_to_date is null then '' else Convert(varchar(10),pc.effective_to_date,120) end  as effective_to_date
                        ,       CONVERT(VARCHAR(10), pc.effective_to_date, 120) AS effective_to_date
                        ,       s.style_code
                        ,       CASE WHEN pcs.new_price IS NULL
                                     THEN pcs.old_price
                                     ELSE pcs.new_price
                                END new_price
	--	,pcs.new_price
                        ,       hg.[hierarchy_group_code] AS brand
                        ,       '' AS long_colour_description
                        ,       '' AS location_code
                        ,       pc.price_change_id
                        ,       '' AS price_status_desc
	--	,ps.price_status_desc
                        ,       s.style_id
                        ,       pcs.price_change_style_id
                        ,       'chain' AS md_type
                        ,       location_grouping
	--	into #chain
                        FROM    [me_01].[dbo].[price_change] AS pc --	inner join [me_01].[dbo].[price_status] as ps on ps.price_status_id = pc.price_status_id
                                INNER JOIN [me_01].[dbo].[price_change_style]
                                AS pcs ON pcs.price_change_id = pc.price_change_id
                                INNER JOIN [me_01].[dbo].[style] AS s ON s.style_id = pcs.style_id
                                INNER JOIN [me_01].[dbo].[jurisdiction] AS j ON j.jurisdiction_id = pc.jurisdiction_id
                                INNER JOIN [me_01].[dbo].[style_group] AS sg ON sg.style_id = s.style_id
                                INNER JOIN [me_01].[dbo].[merch_group_parent] mgp ( NOLOCK ) ON sg.[hierarchy_group_id] = mgp.[hierarchy_group_id]
                                                              AND mgp.[hierarchy_level_id] = 10000002
                                INNER JOIN [me_01].[dbo].[hierarchy_group] hg ( NOLOCK ) ON mgp.[parent_hierarchy_group_id] = hg.[hierarchy_group_id]
                                INNER JOIN #plu_price AS pp ON pp.document_number = pc.price_change_no
	--	where pc.price_change_no in  ('012373','012374','012375','012376','012377','012378')
                        ORDER BY price_change_no ASC

		--select * from #pos_Markdowns
		
		--'012333','012339','012344','012349','012350','012351'
--'012327','012328','012329','012330','012331','012332'

		--***Colour Exception***
                INSERT  INTO #pos_Markdowns
                        SELECT  3
                        ,
		--'2' + substring(cd.price_change_no,2,len(cd.price_change_no)) as price_change_no
                                cd.price_change_no
                        ,       cd.jurisdiction_code
                        ,       cd.effective_from_date
                        ,       cd.effective_to_date
                        ,       cd.style_code
                        ,       pcsc.new_price
                        ,       cd.brand
                        ,       sc.[long_desc]
                        ,       '' AS location_code
                        ,       cd.price_change_id
                        ,       cd.price_status_desc
                        ,       cd.style_id
                        ,       cd.price_change_style_id
                        ,       'colour' AS md_type
                        ,       location_grouping
                        FROM    [me_01].[dbo].[price_change_style_color] pcsc
                                INNER JOIN #pos_Markdowns AS cd ON cd.price_change_id = pcsc.price_change_id
                                                              AND cd.price_change_style_id = pcsc.price_change_style_id
                                INNER JOIN [me_01].[dbo].[style_color] AS sc ON sc.color_id = pcsc.color_id
                                                              AND cd.style_id = sc.style_id
                        WHERE   md_type = 'chain'
                        ORDER BY price_change_no ASC

		--***Location Exception***

                INSERT  INTO #pos_Markdowns
                        SELECT  2
                        ,
	--	'3' + substring(cd.price_change_no,2,len(cd.price_change_no)) as price_change_no
                                cd.price_change_no
                        ,       cd.jurisdiction_code
                        ,       cd.effective_from_date
                        ,       cd.effective_to_date
                        ,       cd.style_code
                        ,       pcsl.new_price
                        ,       cd.brand
                        ,       '' AS long_colour_description
                        ,       l.location_code AS location_code
                        ,       cd.price_change_id
                        ,       cd.price_status_desc
                        ,       cd.style_id
                        ,       cd.price_change_style_id
                        ,       'location' AS md_type
                        ,       location_grouping
                        FROM    [me_01].[dbo].price_change_style_loc AS pcsl
                                INNER JOIN #pos_Markdowns AS cd ON cd.price_change_id = pcsl.price_change_id
                                                              AND cd.price_change_style_id = pcsl.price_change_style_id
                                INNER JOIN [me_01].[dbo].location AS l ON l.location_id = pcsl.location_id
                        WHERE   md_type = 'chain'
                        ORDER BY price_change_no ASC

		--***Location\Color Exception
                INSERT  INTO #pos_Markdowns
                        SELECT  4
                        ,
		--'4' + substring(cd.price_change_no,2,len(cd.price_change_no)) as price_change_no
                                cd.price_change_no
                        ,       cd.jurisdiction_code
                        ,       cd.effective_from_date
                        ,       cd.effective_to_date
                        ,       cd.style_code
                        ,       pcscl.new_price
                        ,       cd.brand
                        ,       sc.[long_desc]
                        ,       l.location_code AS location_code
                        ,       cd.price_change_id
                        ,       cd.price_status_desc
                        ,       cd.style_id
                        ,       cd.price_change_style_id
                        ,       'location\colour' AS md_type
                        ,       location_grouping
                        FROM    [me_01].[dbo].[price_change_stl_col_loc] AS pcscl
                                INNER JOIN #pos_Markdowns AS cd ON cd.price_change_id = pcscl.price_change_id
                                                              AND cd.price_change_style_id = pcscl.price_change_style_id
                                INNER JOIN [me_01].[dbo].location AS l ON l.location_id = pcscl.location_id
                                INNER JOIN [me_01].[dbo].[style_color] AS sc ON sc.color_id = pcscl.color_id
                                                              AND cd.style_id = sc.style_id
                        WHERE   md_type = 'chain'
                        ORDER BY price_change_no ASC

		--***Pricing Group***
                INSERT  INTO #pos_Markdowns
                        SELECT  2
                        ,
	--	'3' + substring(cd.price_change_no,2,len(cd.price_change_no)) as price_change_no
                                cd.price_change_no
                        ,       cd.jurisdiction_code
                        ,       cd.effective_from_date
                        ,       cd.effective_to_date
                        ,       cd.style_code
                        ,       pcsp.new_price
                        ,       cd.brand
                        ,       ''
                        ,       l.location_code AS location_code
                        ,       cd.price_change_id
                        ,       cd.price_status_desc
                        ,       cd.style_id
                        ,       cd.price_change_style_id
                        ,       'pricing group' AS md_type
                        ,       location_grouping
                        FROM    [me_01].[dbo].price_change_style_pg AS pcsp
                                INNER JOIN #pos_Markdowns AS cd ON cd.price_change_id = pcsp.price_change_id
                                                              AND cd.price_change_style_id = pcsp.price_change_style_id
                                INNER JOIN [me_01].[dbo].[pricing_group] AS pc ON pc.pricing_group_id = pcsp.pricing_group_id
                                INNER JOIN [me_01].[dbo].[pricing_group_location]
                                AS pgl ON pgl.pricing_group_id = pc.pricing_group_id
                                INNER JOIN [me_01].[dbo].[location] AS l ON l.location_id = pgl.location_id
                        WHERE   md_type = 'chain'
                        ORDER BY price_change_no ASC

		--***Pricing Group Colours***

                INSERT  INTO #pos_Markdowns
                        SELECT  4
                        ,
		--'4' + substring(cd.price_change_no,2,len(cd.price_change_no)) as price_change_no
                                cd.price_change_no
                        ,       cd.jurisdiction_code
                        ,       cd.effective_from_date
                        ,       cd.effective_to_date
                        ,       cd.style_code
                        ,       pcspc.new_price
                        ,       cd.brand
                        ,       sc.[long_desc]
                        ,       l.location_code AS location_code
                        ,       cd.price_change_id
                        ,       cd.price_status_desc
                        ,       cd.style_id
                        ,       cd.price_change_style_id
                        ,       'pricing group colour' AS md_type
                        ,       location_grouping
                        FROM    [me_01].[dbo].[price_change_stl_pg_col] AS pcspc
                                INNER JOIN #pos_Markdowns AS cd ON cd.price_change_id = pcspc.price_change_id
                                                              AND cd.price_change_style_id = pcspc.price_change_style_id
                                INNER JOIN [me_01].[dbo].[style_color] AS sc ON sc.color_id = pcspc.color_id
                                                              AND cd.style_id = sc.style_id
                                INNER JOIN [me_01].[dbo].[pricing_group] AS pc ON pc.pricing_group_id = pcspc.pricing_group_id
                                INNER JOIN [me_01].[dbo].[pricing_group_location]
                                AS pgl ON pgl.pricing_group_id = pc.pricing_group_id
                                INNER JOIN [me_01].[dbo].[location] AS l ON l.location_id = pgl.location_id
                        WHERE   md_type = 'chain'
                        ORDER BY price_change_no ASC

		--select price_change_no,jurisdiction_code,effective_from_date,isnull(effective_to_date,' ') as effective_to_date
		--,style_code,new_price,brand,isnull(long_colour_description,' ') as long_colour_description,isnull(substring(location_code,2,4),' ') as location_code
		--into ##storeMarkdown
		--select * from #pos_Markdowns
		
		-- section that deletes non pg and pg\colour likes where location group is 2
		
                DELETE  FROM #pos_Markdowns
                WHERE   md_type NOT LIKE 'pric%'
                        AND location_grouping = 2
		
                DELETE  FROM #pos_Markdowns
                WHERE   md_type NOT LIKE 'location%'
                        AND location_grouping = 1
		
                SELECT DISTINCT
                        md_type_id
                ,       price_change_no
                ,       jurisdiction_code
                ,       effective_from_date
                ,       ( effective_to_date ) AS effective_to_date
                ,       style_code
                ,       new_price
                ,       brand
                ,       CASE WHEN long_colour_description = '' THEN NULL
                             ELSE long_colour_description
                        END AS long_colour_description
                ,       CASE WHEN location_code = '' THEN NULL
                             ELSE SUBSTRING(location_code, 2, 4)
                        END AS location_code
                ,       location_code AS [full_location_code]--PJM added to facilitate mapping to pricing dummy store
                INTO    ##storeMarkdown
                FROM    #pos_Markdowns
                ORDER BY price_change_no ASC
                ,       md_type_id ASC
                ,       style_code 
		
                UPDATE  ##storeMarkdown
                SET     brand = atse.attribute_set_code
                FROM    me_01.dbo.attribute_set AS atse
                        INNER JOIN me_01.dbo.entity_attribute_set AS eas ON atse.attribute_set_id = eas.attribute_set_id
                        INNER JOIN StyleSummary AS ss ON eas.parent_id = ss.category_id
                        INNER JOIN ##storeMarkdown ON ss.style_code = ##storeMarkdown.style_code
                WHERE   ( ss.brand_code = '12' ) --Brand 12 is consignment
                        AND ( eas.parent_type = 5 ) --entity type 5 is Merch hierarchy group
                        AND ( eas.attribute_id = 175 ) --attribute_id 175 is the new PLU BRAND attribute which is attached to Merchandise hierarchy groups

                DELETE  FROM ##storeMarkdown
                WHERE   1 = 1
                        AND [jurisdiction_code] = 'nzi'
		
-------------------------------Emporium section	
                INSERT  INTO ##storeMarkdown
                        ( [md_type_id]
                        ,[price_change_no]
                        ,[jurisdiction_code]
                        ,[effective_from_date]
                        ,[effective_to_date]
                        ,[style_code]
                        ,[new_price]
                        ,[brand]
                        ,[long_colour_description]
                        ,[location_code]
                        ,[full_location_code]
                        )
                        SELECT  [md_type_id]
                        ,       [price_change_no]
                        ,       [jurisdiction_code]
                        ,       [effective_from_date]
                        ,       [effective_to_date]
                        ,       [style_code]
                        ,       [new_price]
                        ,       '08' AS [brand]
                        ,       [long_colour_description]
                        ,       [location_code]
                        ,       [full_location_code]
                        FROM    ##storeMarkdown
                        WHERE   ISNULL([location_code], '') = ''
                                AND [jurisdiction_code] = 'AU'
                                AND [brand] NOT IN ( '06', '07', '08' )

                IF OBJECT_ID('tempdb..#dummy_pricing_records') IS NOT NULL
                    DROP TABLE #dummy_pricing_records
                SELECT  [md_type_id]
                ,       [price_change_no]
                ,       [jurisdiction_code]
                ,       [effective_from_date]
                ,       [effective_to_date]
                ,       [style_code]
                ,       [new_price]
                ,       [brand]
                ,       [long_colour_description]
                ,       [location_code]
                ,       [full_location_code]
                INTO    #dummy_pricing_records
                FROM    ##storeMarkdown
                WHERE   [full_location_code] IN (
                        SELECT DISTINCT
                                [custom_property_value] AS dummy_pricing_store
                        FROM    [me_01].[dbo].[entity_custom_property] ecp
                                INNER JOIN [me_01].[dbo].[custom_property] cp ON ecp.[custom_property_id] = cp.[custom_property_id]
                                INNER JOIN [me_01].[dbo].location l ON ecp.parent_id = l.location_id
                        WHERE   ecp.parent_type = 2
                                AND cp.cust_prop_code = 'PRCSTO' )
  
                DELETE  FROM ##storeMarkdown
                WHERE   [full_location_code] IN (
                        SELECT DISTINCT
                                [custom_property_value] AS dummy_pricing_store
                        FROM    [me_01].[dbo].[entity_custom_property] ecp
                                INNER JOIN [me_01].[dbo].[custom_property] cp ON ecp.[custom_property_id] = cp.[custom_property_id]
                                INNER JOIN [me_01].[dbo].location l ON ecp.parent_id = l.location_id
                        WHERE   ecp.parent_type = 2
                                AND cp.cust_prop_code = 'PRCSTO' )

                INSERT  INTO ##storeMarkdown
                        ( [md_type_id]
                        ,[price_change_no]
                        ,[jurisdiction_code]
                        ,[effective_from_date]
                        ,[effective_to_date]
                        ,[style_code]
                        ,[new_price]
                        ,[brand]
                        ,[long_colour_description]
                        ,[location_code]
                        ,[full_location_code]
                        )
                        SELECT  d.[md_type_id]
                        ,       d.[price_change_no]
                        ,       d.[jurisdiction_code]
                        ,       d.[effective_from_date]
                        ,       d.[effective_to_date]
                        ,       d.[style_code]
                        ,       d.[new_price]
                        ,       '08' AS [brand]
                        ,       d.[long_colour_description]
                        ,       SUBSTRING([Emporium_store], 2, 4) AS [location_code]
                        ,       [full_location_code]
                        FROM    #dummy_pricing_records d
                                INNER JOIN ( SELECT l.location_code AS [Emporium_store]
                                             ,      [custom_property_value] AS [dummy_pricing_store]
                                             FROM   [me_01].[dbo].[entity_custom_property] ecp
                                                    INNER JOIN [me_01].[dbo].[custom_property] cp ON ecp.[custom_property_id] = cp.[custom_property_id]
                                                    INNER JOIN [me_01].[dbo].location l ON ecp.parent_id = l.location_id
                                             WHERE  ecp.parent_type = 2
                                                    AND cp.cust_prop_code = 'PRCSTO'
                                           ) emporium_dummy_mapping ON d.[full_location_code] = emporium_dummy_mapping.[dummy_pricing_store]
                                           
                                           
DELETE FROM ##storeMarkdown
WHERE [brand]='08'
AND ISNULL( [effective_to_date],'')<>''
AND style_code in (select style_code from databyte..stylesummary where brand_code not in (select brand_code from #one_woman_promo_brands))

                                           
-------------------------------End of Emporium section
		
		--select * from ##storeMarkdown order by 1
--drop table ##storeMarkdown 
--		select price_change_no,jurisdiction_code,effective_from_date,effective_to_date,style_code,new_price,brand,long_colour_description ,location_code from ##storeMarkdown order by substring(price_change_no,2,len(price_change_no))
		
                DECLARE @sout VARCHAR(1000)
                ,   @filename VARCHAR(50)
                SET @sout = ''
                SET @filename = 'PRC' + CONVERT(VARCHAR(10), GETDATE(), 112)
                    + REPLACE(CONVERT(VARCHAR(5), GETDATE(), 108), ':', '')
                    + '.txt'  
	--	SET @sout = 'bcp "select DISTINCT * from ##storeMarkdown" queryout "\\smoogle\public\michael\' + @filename + '" -c -t "," -Slocalhost -Usa -Pmillers'
                SET @sout = 'bcp "select substring(price_change_no,2,len(price_change_no)) as price_change_no,jurisdiction_code,effective_from_date,effective_to_date,style_code,new_price,brand,long_colour_description ,location_code from ##storeMarkdown order by price_change_no asc,md_type_id asc , style_code" queryout "\\tailor-sa1\nsbpolldata$\'
                    + @filename + '" -c -t "," -Slocalhost -Usa -Pmillers'
		
                PRINT @sout
                EXEC master..xp_cmdshell @sout, no_output
		
--		--\\tailor-sa1\nsbpolldata$\  -- need to replace location of where the file gets main when deployed to live

--\\smoogle\public\Michael\markdowns\
		
                DECLARE @maxID INT
                SET @maxID = ( SELECT   MAX(plu_price_change_id)
                               FROM     #plu_price
                             )
		
                INSERT  INTO markdown_Last_Queue_Item
                        ( last_plu_price_change_id
                        ,last_Run_Date
                        ,comment
                        )
                VALUES  ( @maxID
                        ,GETDATE()
                        ,'Success'
                        )
		
            END
        ELSE
            IF ( ( SELECT   COUNT(*)
                   FROM     #plu_price
                 ) = 0 )
                BEGIN
                    INSERT  INTO markdown_Last_Queue_Item
                            ( last_plu_price_change_id
                            ,last_Run_Date
                            ,comment
                            )
                    VALUES  ( @maxID
                            ,GETDATE()
                            ,'No New Data'
                            )
                END

    END


