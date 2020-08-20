/*
 * SQL Patch 314
 *
 * Description: 
 * - 
 *
 * Updates:
 * - 20150706 IG? First Version
 */

declare @zErrNo int
declare @zPatchNo int
set @zPatchNo = 314

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

--SELECT * FROM rules_formulation -- sp_help rules_formulation
--SELECT * FROM rules_definition -- sp_help rules_definition
--SELECT * FROM rules
--spGetRules NULL

IF EXISTS(SELECT * FROM sys.columns WHERE Name = N'type' AND OBJECT_ID = OBJECT_ID(N'rules_formulation'))
BEGIN
	ALTER TABLE rules_formulation DROP CONSTRAINT DF_type
	ALTER TABLE rules_formulation DROP COLUMN [type]
END
GO
ALTER TABLE rules_formulation ADD [type] NVARCHAR(20)
ALTER TABLE rules_formulation ADD CONSTRAINT DF_type DEFAULT 'Text' FOR [type]
GO
UPDATE rules_formulation SET [type] = 'Text'

IF EXISTS(SELECT * FROM sys.columns WHERE Name = N'email_body_alttext' AND OBJECT_ID = OBJECT_ID(N'rules_definition'))
	ALTER TABLE rules_definition DROP COLUMN email_body_alttext
ALTER TABLE rules_definition ADD email_body_alttext NVARCHAR(MAX)
GO
UPDATE rules_definition SET email_body_alttext = email_body
GO 

ALTER TABLE rules_definition ALTER COLUMN email_subject NVARCHAR(200) NOT NULL
ALTER TABLE rules_definition ALTER COLUMN email_body NVARCHAR(MAX) NOT NULL
ALTER TABLE rules_definition ALTER COLUMN email_body_alttext NVARCHAR(MAX) NOT NULL

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
	SELECT	d.id, 
			d.email_subject, 
			d.email_body, 
			d.email_body_alttext, 
			f.formula,
			f.[type], 
			7 AS params_offset,
			r.param_id, 
			CONCAT(r.param_value, '','', r.param_type) AS param_value
	FROM rules r
	JOIN rules_definition d ON r.definition_id = d.id
	JOIN rules_formulation f ON d.formula_id = f.id 
	' + @WhereTag + '
) AS normalized_rules 
PIVOT (MAX(param_value) FOR param_id in (' +  @ParamId + ')) AS pvt'

PRINT @DynamicPivotQuery

EXEC sp_executesql @DynamicPivotQuery

GO

/*
 * ----------------------
 * End DB Changes
 * ----------------------
 */
declare @zPatchDesc nvarchar(3000)
set @zPatchDesc = N''
declare @zPatchNo int
set @zPatchNo = 314

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