USE [vps_awsdev-integration]
GO

/****** Object:  StoredProcedure [dbo].[spGetRules]    Script Date: 12/23/2015 4:09:55 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spGetRules] 
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


