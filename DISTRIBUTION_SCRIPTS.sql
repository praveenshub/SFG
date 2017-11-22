USE [Transactions_Store_Dev]
GO
DECLARE	@return_value int
EXEC	@return_value = [dbo].[REFRESH_DESADV_OUTBOUND]
SELECT	'Return Value' = @return_value
GO
-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
SELECT DATE_INSERTED,* FROM dbo.DESADV_OUTBOUND WHERE CONTAINER_NUMBER = '00831313' AND SHIPMENT_NUMBER = 301288 
SELECT DATE_INSERTED,* FROM dbo.DESADV_OUTBOUND WHERE CONTAINER_NUMBER = '55555555' AND SHIPMENT_NUMBER = 301289
SELECT DATE_INSERTED,* FROM dbo.DESADV_OUTBOUND WHERE CONTAINER_NUMBER = '11111111' AND SHIPMENT_NUMBER = 301287 
-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
USE [Transactions_Store_Dev]
GO
DECLARE	@return_value int
EXEC	@return_value = [dbo].[ERP_Insert_Toll_RecAdv]
		@Container_Number = N'44444444'
SELECT	'Return Value' = @return_value
GO
-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
SELECT * FROM dbo.RECADV WHERE CONTAINER_NUMBER = '44444444' AND SHIPMENT_NUMBER = 301288
SELECT * FROM dbo.RECADV WHERE CONTAINER_NUMBER = '55555555' AND SHIPMENT_NUMBER = 301289
SELECT * FROM dbo.RECADV WHERE CONTAINER_NUMBER = '11111111' AND SHIPMENT_NUMBER = 301287 
-----------------------------------------------------------------------------------------------------------------------

--RUN EPICOR_PORECEIPT TALEND JOB & WAIT FOR PO RECEIPT XML TO PROCESS

-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
USE [Transactions_Store_Dev]
GO
DECLARE	@return_value int
EXEC	@return_value = [dbo].[REFRESH_INSDES]
SELECT	'Return Value' = @return_value
GO
-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
SELECT * FROM dbo.INSDES WHERE ALLOCATION_NUMBER = '0000831462'
-----------------------------------------------------------------------------------------------------------------------
UPDATE dbo.INSDES SET DESPATCH_DATE = GETDATE() WHERE  ALLOCATION_NUMBER = '0000831462'
-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
USE [Transactions_Store_Dev]
GO
DECLARE	@return_value int
EXEC	@return_value = [dbo].[EXPORT_INSDES_RETAIL]
SELECT	'Return Value' = @return_value
GO
-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------

--RUN THE FREEZE TALEND JOB AND WAIT FOR DISTRIBUTION TO FREEZE IN MERCH


--___DONE TILL HERE ----

-- CONTINUE HERE TOMORROW----

-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
USE [Transactions_Store_Dev]
GO
DECLARE	@return_value int
EXEC	@return_value = [dbo].[ERP_Insert_Toll_DesAdv]
		@Allocation_Number = N'0000831462'
SELECT	'Return Value' = @return_value
GO
-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------

--RUN THE MODIFY PACK & MODIFY UPC TALEND JOB

--RUN THE SHIPMENT TALEND JOB AND WAIT FOR SHIPMENT XML TO PROCESS

--RUN THE COMPLETE TALEND JOB AND VERIFY IN MERCH

-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------


