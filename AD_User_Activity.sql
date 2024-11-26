declare @shellCommand varchar(8000);
declare @ou varchar(1000) = 'OU=...,DC=...,DC=com';

/* POWERSHELL SCRIPT
---------------------
Write-Host (Get-ADUser -Filter * -SearchBase $args[0] | Select-Object  SAMAccountName, Name | ConvertTo-Json)
*/
set @shellCommand = '"PowerShell.exe -noprofile Path\to\scripts\GetUsersByOU.ps1 ''' + @ou + '''"';

declare @output table (
	id int identity, 
	command varchar(max)
);
delete from @output;

insert into @output
exec master..xp_cmdshell @shellCommand;

declare @json varchar(max);
select @json = (
    select [command] + ''
    from @output FOR XML PATH('')
);

-- check for valid json
if isjson(@json) is null or isjson(@json) = 0
throw 50001, 'IVALID JSON', 1;

with recentActions as (
	select [username], max([date]) LastAction
	from [Database].[audti].[RecordAccessLog]
	group by [username]
),
nNames as (
	select Sam, [Name]
	from OPENJSON(@json, '$')
	with (
		[Sam] varchar(100) '$.SAMAccountName',
		[Name] varchar(50) '$.Name'
	)
)
select [Sam], [Name], LastAction
from nNames a
left join recentActions b
	on a.[Sam] = b.[username]
order by [username]