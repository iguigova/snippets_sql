/*
 * SQL Patch 311
 *
 * Description: 
 * - Introduced Rules tables
 *
 * Updates:
 * - 20150617 IG First Version
 */

declare @zErrNo int
declare @zPatchNo int
set @zPatchNo = 311

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

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' AND TABLE_NAME='rules') 
	DROP TABLE rules

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' AND TABLE_NAME='rules_definition_tags') 
	DROP TABLE rules_definition_tags

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' AND TABLE_NAME='rules_definition') 
	DROP TABLE rules_definition

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' AND TABLE_NAME='rules_tags') 
	DROP TABLE rules_tags

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' AND TABLE_NAME='rules_parameters') 
	DROP TABLE rules_parameters

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' AND TABLE_NAME='rules_formulation') 
	DROP TABLE rules_formulation
GO 

CREATE TABLE rules_formulation
(
    id INT IDENTITY NOT NULL PRIMARY KEY,
    name NVARCHAR(100),
    formula NVARCHAR(MAX)
)

CREATE TABLE rules_parameters
(
    id INT IDENTITY NOT NULL PRIMARY KEY,
    name NVARCHAR(100) NOT NULL
)

CREATE TABLE rules_tags
(
    id INT IDENTITY NOT NULL PRIMARY KEY,
    name NVARCHAR(100) NOT NULL
)

CREATE TABLE rules_definition
(
    id INT IDENTITY NOT NULL PRIMARY KEY,
    name NVARCHAR(100),
    formula_id INT FOREIGN KEY REFERENCES rules_formulation(id),
	email_subject NVARCHAR(100),
    email_body NVARCHAR(MAX), 
	active BIT DEFAULT 1
	-- ASSUMPTION: In the code we iterate through the rule formulation dataset and call the template for each record)
    -- ASSUMPTION: The email is sent to the email_address field to be included with each record in the rule formulation dataset
	-- ASSUMPTION: The email is sent from the service/pen guid to be included with each record in the rule formulation dataset
)

CREATE TABLE rules_definition_tags
(
    id INT IDENTITY PRIMARY KEY,
    definition_id INT FOREIGN KEY REFERENCES rules_definition(id),
    tag_id INT FOREIGN KEY REFERENCES rules_tags(id)
)

CREATE TABLE rules
(
    id INT IDENTITY PRIMARY KEY,
    definition_id INT FOREIGN KEY REFERENCES rules_definition(id),
    param_id INT FOREIGN KEY REFERENCES rules_parameters(id),
	param_type NVARCHAR(10),
    param_value NVARCHAR(MAX)
)

GO 

INSERT INTO rules_formulation (name, formula) VALUES ('List of users that have registered x number of days ago', 'SELECT s.service_guid, us.email_address, r.performed_on FROM registration r JOIN user_services us ON r.user_service_id = us.id JOIN services s ON us.service_id = s.id WHERE DATEDIFF(DAY, r.performed_on, GETDATE()) = @param1')
INSERT INTO rules_formulation (name, formula) VALUES ('List of users where their first name starts with x', 'SELECT s.service_guid, us.email_address, r.performed_on FROM registration r JOIN user_services us ON r.user_service_id = us.id JOIN services s ON us.service_id = s.id WHERE DATEDIFF(DAY, r.performed_on, GETDATE()) = @param1')

INSERT INTO rules_parameters(name) VALUES ('param1')
INSERT INTO rules_parameters(name) VALUES ('param2')
INSERT INTO rules_parameters(name) VALUES ('param3')
INSERT INTO rules_parameters(name) VALUES ('param4')

INSERT INTO rules_tags(name) VALUES ('sample tag')

INSERT INTO rules_definition (name, formula_id, email_subject, email_body) VALUES ('List of users that have registered 5 days ago', 1, 'Hey {0}!', 'You have registered on {1}. It has been 5 days...')
INSERT INTO rules_definition (name, formula_id, email_subject, email_body) VALUES ('List of users that have registered 10 days ago', 1, 'Hey {0}!', 'You have registered on {1}. It has been 10 days...')

INSERT INTO rules (definition_id, param_id, param_type, param_value) VALUES (1, 1, 'Int', 5)
INSERT INTO rules (definition_id, param_id, param_type, param_value) VALUES (2, 1, 'Int', 10)

GO

/*
 * ----------------------
 * End DB Changes
 * ----------------------
 */
declare @zPatchDesc nvarchar(3000)
set @zPatchDesc = N''
declare @zPatchNo int
set @zPatchNo = 311

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