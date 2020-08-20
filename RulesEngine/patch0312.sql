/*
 * SQL Patch 312
 *
 * Description: 
 * - Introduced Rules tables
 *
 * Updates:
 * - 20150618 IG First Version
 */

declare @zErrNo int
declare @zPatchNo int
set @zPatchNo = 312

print '**'
print '** Starting Patch ' + cast(@zPatchNo as varchar)
print '** ' + cast(getdate() as varchar)
print '**'

-- confirm patch hasn't been applied already
if exists(select 1 from [dbo].patches p where p.patch_number = @zPatchNo) begin
	RAISERROR ('Patch has already been applied. No changes required.', 9, 127)
end

/*
 * ----------------------
 * Start DB Changes
 * ----------------------
 */

-- spGetRules NULL

-- http://stackoverflow.com/questions/2072086/how-to-check-if-a-stored-procedure-exists-before-creating-it

IF NOT EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'spGetRules')
   exec('CREATE PROCEDURE [dbo].[spGetRules] AS BEGIN SET NOCOUNT ON; END')
GO

ALTER PROCEDURE [dbo].[spGetRules] 
	@Tag NVARCHAR(50)
AS

-- http://stackoverflow.com/questions/15931607/convert-rows-to-columns-using-pivot-in-sql-server

-- DECLARE @Tag AS NVARCHAR(50)
DECLARE @DynamicPivotQuery AS NVARCHAR(MAX)
DECLARE @ParamId AS NVARCHAR(MAX)
DECLARE @WhereTag AS NVARCHAR(MAX)

SELECT @ParamId= ISNULL(@ParamId + ',','') 
       + QUOTENAME(id)
FROM (SELECT DISTINCT id FROM rules_parameters) AS Params

SET @WhereTag = 'WHERE d.active = 1'
IF @Tag IS NOT NULL SET @WhereTag = @WhereTag + 	
N' AND EXISTS 
(
	SELECT 1 
	FROM rules_definition_tags dt 
	JOIN rules_tags t ON dt.tag_id = t.id 
	WHERE t.name = ' + @Tag + '
) '

SET @DynamicPivotQuery = 
N'SELECT * FROM 
(
	SELECT d.id, r.param_id, CONCAT(r.param_value, '','', r.param_type) AS param_value, d.email_subject, d.email_body, f.formula 
	FROM rules r
	JOIN rules_definition d ON r.definition_id = d.id
	JOIN rules_formulation f ON d.formula_id = f.id 
	' + @WhereTag + '
) AS normalized_rules 
PIVOT (MAX(param_value) FOR param_id in (' +  @ParamId + ')) AS pvt'

PRINT @DynamicPivotQuery

EXEC sp_executesql @DynamicPivotQuery

GO

--spGetRules NULL

/*
 * ----------------------
 * End DB Changes
 * ----------------------
 */
declare @zPatchDesc nvarchar(3000)
set @zPatchDesc = N''
declare @zPatchNo int
set @zPatchNo = 312

if not exists (select '1' from [dbo].patches where patch_number = @zPatchNo) begin
	insert into [dbo].patches (patch_number, applied_on, patch_description)
	 values (@zPatchNo, getdate(), @zPatchDesc)
end
else begin
	update [dbo].patches 
	 set applied_on = getdate(), 
		patch_description = @zPatchDesc + N' (upd)'
	 where patch_number = @zPatchNo
end

-- done
print 'Done.'

go