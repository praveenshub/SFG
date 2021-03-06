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

AS
    BEGIN
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
                    ,md_type VARCHAR(20)
                    ,location_grouping INT
                    )
		--exec tempdb..sp_help '#pos_Markdowns'
		--exec tempdb..sp_help '#chain'



-------------------------------***Get Chain Markdowns ***-------------------------------
        INSERT  INTO #pos_Markdowns
		SELECT  1,
				pc.price_change_no,
				j.jurisdiction_code,
				CONVERT(VARCHAR(10), pc.effective_from_date, 120) AS effective_from_date,
				CONVERT(VARCHAR(10), pc.effective_to_date, 120) AS effective_to_date,
				s.style_code,
				pci.calculation_value AS new_price,
				SUBSTRING(hg.hierarchy_group_code, 1, 2) AS brand,
				'' AS long_colour_description,
				'' AS location_code,
				pc.price_change_id,
				'' AS price_status_desc,
				s.style_id,
				'chain' AS md_type,
				pc.location_grouping
		FROM				[me_01].[dbo].[price_change_instruction] AS pci
				INNER JOIN  [me_01].[dbo].[price_change] AS pc ON pc.price_change_id = pci.price_change_id
				INNER JOIN  [me_01].[dbo].jurisdiction AS j ON j.jurisdiction_id = pci.jurisdiction_id
				INNER JOIN  [me_01].[dbo].[style] AS s ON s.style_id = pci.style_id
				INNER JOIN  [me_01].[dbo].[hierarchy_group] AS hg ON hg.hierarchy_group_id = pci.merch_hierarchy_group_id
				INNER JOIN  #plu_price AS pp ON pp.document_number = pc.price_change_no
		ORDER BY price_change_no ASC

		--select * from #pos_Markdowns

-------------------------------***Colour Exception***-------------------------------
        INSERT  INTO #pos_Markdowns
        		SELECT  3,
				pm.price_change_no,
				pm.jurisdiction_code,
				pm.effective_from_date,
				pm.effective_to_date,
				pm.style_code,
				pm.new_price,
				pm.brand,
				sc.long_desc AS long_colour_description,
				'' AS location_code,
				pm.price_change_id,
				pm. price_status_desc,
				pm.style_id,
				 'colour' AS md_type,
				location_grouping
		FROM	#pos_Markdowns AS pm 
		        INNER JOIN [me_01].[dbo].[price_change_instruction] AS pci ON pci.price_change_id = pm.price_change_id
				INNER JOIN  [me_01].[dbo].[style_color] AS sc ON sc.style_color_id = pci.style_color_id
		WHERE md_type = 'chain'
		ORDER BY price_change_no ASC

-------------------------------***Location Exception***-------------------------------

        INSERT  INTO #pos_Markdowns
				SELECT  2,
				pm.price_change_no,
				pm.jurisdiction_code,
				pm.effective_from_date,
				pm.effective_to_date,
				pm.style_code,
				pm.new_price,
				pm.brand,
				'' AS long_colour_description,
				l.location_code AS location_code,
				pm.price_change_id,
				pm. price_status_desc,
				pm.style_id,
				'location' AS md_type,
				location_grouping
		FROM	#pos_Markdowns AS pm 
		        INNER JOIN [me_01].[dbo].[price_change_instruction] AS pci ON pci.price_change_id = pm.price_change_id
				INNER JOIN  [me_01].[dbo].[location] AS l ON l.location_id = pci.location_id
		WHERE md_type = 'chain'
		ORDER BY price_change_no ASC

-------------------------------***Location\Color Exception-------------------------------
        INSERT  INTO #pos_Markdowns
        SELECT  4,
				pm.price_change_no,
				pm.jurisdiction_code,
				pm.effective_from_date,
				pm.effective_to_date,
				pm.style_code,
				pm.new_price,
				pm.brand,
				sc.long_desc AS long_colour_description,
				l.location_code AS location_code,
				pm.price_change_id,
				pm. price_status_desc,
				pm.style_id,
				'location\colour' AS md_type,
				location_grouping
		FROM	#pos_Markdowns AS pm
				INNER JOIN  [me_01].[dbo].[price_change_instruction] pci ON pm.price_change_id = pci.price_change_id
				INNER JOIN  [me_01].[dbo].[style_color] AS sc ON sc.style_color_id = pci.style_color_id
				INNER JOIN  [me_01].[dbo].[location] AS l ON l.location_id = pci.location_id
		WHERE md_type = 'chain'
		ORDER BY price_change_no ASC

		
		--select * from #pos_Markdowns

		--SELECT * FROM  ##storeMarkdown
		
-------------------------------section that deletes non pg and pg\colour likes where location group is 2-------------------------------
		
				DELETE  FROM #pos_Markdowns
				WHERE   md_type NOT LIKE 'pric%'
						AND location_grouping = 2
		
				DELETE  FROM #pos_Markdowns
				WHERE   md_type NOT LIKE 'location%'
						AND location_grouping = 1

-------------------------------Populate Store Markdowns-------------------------------
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
                WHERE   1 = 1  AND [jurisdiction_code] = 'nzi'
		
--------------------------------------------------------------Emporium section for One Woman---------------------------------------------------------------------------------------------	
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

                                           
--------------------------------------------------------------End of Emporium section for One Woman---------------------------------------------------------------------------------------------
		
--select * from ##storeMarkdown order by 1
--drop table ##storeMarkdown 
--		select price_change_no,jurisdiction_code,effective_from_date,effective_to_date,style_code,new_price,brand,long_colour_description ,location_code from ##storeMarkdown order by substring(price_change_no,2,len(price_change_no))
		
                DECLARE @sout VARCHAR(1000)
                ,   @filename VARCHAR(50)
                SET @sout = ''
                SET @filename = 'PRC' + CONVERT(VARCHAR(10), GETDATE(), 112)
                    + REPLACE(CONVERT(VARCHAR(5), GETDATE(), 108), ':', '')
                    + '.txt'  
                SET @sout = 'bcp "select substring(price_change_no,2,len(price_change_no)) as price_change_no,jurisdiction_code,effective_from_date,effective_to_date,style_code,new_price,brand,long_colour_description ,location_code from ##storeMarkdown order by price_change_no asc,md_type_id asc , style_code" queryout "\\dev-tailor-sa1\nsbpolldata$\'
                    + @filename + '" -c -t "," -Slocalhost -Usvc-SQL_FileWrite -PVz9*Zcm4'
		
                PRINT @sout
                EXEC master..xp_cmdshell @sout, no_output
		
--		--\\tailor-sa1\nsbpolldata$\  -- need to replace location of where the file gets main when deployed to live

	
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


