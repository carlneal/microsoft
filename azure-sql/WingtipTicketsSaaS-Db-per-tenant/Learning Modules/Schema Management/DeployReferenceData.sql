-- Connect to and run against the jobaccount database in the catalog-<user> server
-- Replace <user> below with the User value used when the sample app was deployed
DECLARE @WtpUser nvarchar(50);
DECLARE @server1 nvarchar(50);
DECLARE @server2 nvarchar(50);
SET @WtpUser = '<user>';

-- Add a target group containing server(s)
EXEC [jobs].sp_add_target_group @target_group_name = 'DemoServerGroup'

-- Add a server target member, includes all databases in tenant server
SET @server1 = 'tenants1-dpt-' + @WtpUser + '.database.windows.net'

EXEC [jobs].sp_add_target_group_member
@target_group_name =  'DemoServerGroup',
@membership_type = 'Include',
@target_type = 'SqlServer',
@refresh_credential_name='myrefreshcred',
@server_name=@server1

-- Add the database target member of the 'golden' database and analysis database
SET @server2 = 'catalog-dpt-' + @WtpUser + '.database.windows.net'

EXEC [jobs].sp_add_target_group_member
@target_group_name =  'DemoServerGroup',
@membership_type = 'Include',
@target_type = 'SqlDatabase',
@server_name=@server2,
@database_name='basetenantdb'

EXEC [jobs].sp_add_target_group_member
@target_group_name =  'DemoServerGroup',
@membership_type = 'Include',
@target_type = 'SqlDatabase',
@server_name=@server2,
@database_name='adhocreporting'

-- Add a job to deploy new reference data
EXEC jobs.sp_add_job
@job_name='Reference Data Deployment',
@description='Deploy new VenueTypes reference data',
@enabled=1,
@schedule_interval_type='Once'
GO

-- Add a job step to extend the set of VenueTypes using an idempotent MERGE script
EXEC jobs.sp_add_jobstep
@job_name='Reference Data Deployment',
@command=N'
MERGE INTO [dbo].[VenueTypes] AS [target]
USING (VALUES
    (''multipurpose'',''Multi-Purpose'',''Event'', ''Event'',''Events'',''en-us''),
    (''classicalmusic'',''Classical Music'',''Classical Concert'',''Concert'',''Concerts'',''en-us''),
    (''jazz'',''Jazz'',''Jazz Session'',''Session'',''Sessions'',''en-us''),
    (''judo'',''Judo'',''Judo Tournament'',''Tournament'',''Tournaments'',''en-us''),
    (''soccer'',''Soccer'',''Soccer Match'', ''Match'',''Matches'',''en-us''),
    (''motorracing'',''Motor Racing'',''Car Race'', ''Race'',''Races'',''en-us''),
    (''dance'', ''Dance'', ''Performance'', ''Performance'', ''Performances'',''en-us''),
    (''blues'', ''Blues'', ''Blues Session'', ''Session'',''Sessions'',''en-us'' ),
    (''rockmusic'',''Rock Music'',''Rock Concert'',''Concert'', ''Concerts'',''en-us''),
    (''opera'',''Opera'',''Opera'',''Opera'',''Operas'',''en-us''),
    (''motorcycleracing'',''Motorcycle Racing'',''Motorcycle Race'', ''Race'', ''Races'', ''en-us''), -- NEW
    (''swimming'',''Swimming'',''Swimming Race'',''Race'',''Races'',''en-us'') -- NEW
) AS source(
    VenueType,VenueTypeName,EventTypeName,EventTypeShortName,EventTypeShortNamePlural,[Language]
)              
ON [target].VenueType = source.VenueType
-- update existing rows
WHEN MATCHED THEN
    UPDATE SET 
        VenueTypeName = source.VenueTypeName,
        EventTypeName = source.EventTypeName,
        EventTypeShortName = source.EventTypeShortName,
        EventTypeShortNamePlural = source.EventTypeShortNamePlural,
        [Language] = source.[Language]
-- insert new rows
WHEN NOT MATCHED BY TARGET THEN
    INSERT (VenueType,VenueTypeName,EventTypeName,EventTypeShortName,EventTypeShortNamePlural,[Language])
    VALUES (VenueType,VenueTypeName,EventTypeName,EventTypeShortName,EventTypeShortNamePlural,[Language])
;
GO',
@credential_name='mydemocred',
@target_group_name='DemoServerGroup'

--
-- Views
-- Job and Job Execution Information and Status
--
SELECT * FROM [jobs].[jobs] WHERE job_name = 'Reference Data Deployment'
SELECT * FROM [jobs].[jobsteps] WHERE job_name = 'Reference Data Deployment'

WAITFOR DELAY '00:00:10'
--View parent execution status
SELECT * FROM [jobs].[job_executions] 
WHERE job_name = 'Reference Data Deployment' and step_id IS NULL
ORDER BY end_time DESC

--View all execution status
SELECT * FROM [jobs].[job_executions] 
WHERE job_name = 'Reference Data Deployment'
ORDER BY end_time DESC

-- View summary of job and step execution status
SELECT 
    MIN(create_time) AS StartTime,
    MAX(end_time) AS EndTime, 
    (CASE WHEN step_id IS NULL THEN 'Job' ELSE 'Step' END) AS [Job/Step],
    SUM(CASE WHEN lifecycle = 'Created' THEN 1 ELSE 0 END) AS Created,
    SUM(CASE WHEN lifecycle = 'InProgress' THEN 1 ELSE 0 END) AS InProgress, 
    SUM(CASE WHEN lifecycle like 'Waiting*' THEN 1 ELSE 0 END) AS Waiting,      
    SUM(CASE WHEN lifecycle = 'Succeeded' THEN 1 ELSE 0 END) AS Succeeded,
    SUM(CASE WHEN lifecycle = 'Failed' THEN 1 ELSE 0 END) AS Failed
    FROM [jobs].[job_executions] 
WHERE job_name = 'Reference Data Deployment'
GROUP BY job_execution_id, step_id
ORDER BY EndTime DESC

--Manually run the job (again)
--EXEC [jobs].[sp_start_job] 'Reference Data Deployment' 

--Stop the job execution, requires active job_execution_id from [jobs].[job_executions] view
--EXEC [jobs].[sp_stop_job] '9B0FB896-CA10-44B0-8D9E-51149D925DB2'

-- Cleanup
--EXEC [jobs].[sp_delete_job] 'Reference Data Deployment'
--EXEC [jobs].[sp_delete_target_group] 'DemoServerGroup'
