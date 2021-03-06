param(
	[parameter(Mandatory = $true)]
	[String]$TestControllerServiceUserName,
	[parameter(Mandatory = $true)]
	[String]$LoadTestPackageSourcePath,
	[parameter(Mandatory = $true)]
	[String]$LoadTestDestinationPath,
	[parameter(Mandatory = $true)]
	[String]$AdminUserName,
	[parameter(Mandatory = $true)]
	[String]$AdminPWD,
	[parameter(Mandatory = $true)]
	[String]$SPSiteURL,
	[parameter(Mandatory = $true)]
	[String]$SPFarmSQLServerName,
	[parameter(Mandatory = $true)]
	[Int]$NumberOfUsers	
)
# Install the log to file module
$currentPath = Convert-Path .
$PSModulePath = "$($env:ProgramFiles)\WindowsPowerShell\Modules"
$LogToFileFolderName = "LogToFile"
$LogToFileFolderPath = Join-Path $PSModulePath $LogToFileFolderName
if(-not(Test-Path $LogToFileFolderPath))
{
	New-Item -Path $LogToFileFolderPath -ItemType directory
	$moduleFileName = "LogToFile.psm1"
	$moduleFilePath = Join-Path $currentPath $moduleFileName
	Copy-Item $moduleFilePath $LogToFileFolderPath
}
Import-Module LogToFile

# Create the log file
CreateLogFile

# Script names
$prepTargetScript = "PrepareTargetForRun.ps1"
$ltDownloadScript = "DownloadLoadTestPackage.ps1"
$enableSearchScript = "SharePointEnableSearchService.ps1"
$enableMMetadataScript = "SharePointEnableManagedMetadataService.ps1"
$enableUserProfScript = "SharePointPrepareUserProfileServiceForLoadTest.ps1"
$createUsersScript = "SharePointCreateUsersForLoadTest.ps1"

# Paths
$prepTargetScriptPath = Join-Path $currentPath $prepTargetScript
$ltDownloadScriptPath = Join-Path $currentPath $ltDownloadScript
$enableSearchScriptPath = Join-Path $currentPath $enableSearchScript
$enableMMetadataScriptPath = Join-Path $currentPath $enableMMetadataScript
$enableUserProfScriptPath = Join-Path $currentPath $enableUserProfScript
$createUsersScriptPath = Join-Path $currentPath $createUsersScript

# Other variables
$Domain = (Get-CimInstance -ClassName Win32_ComputerSystem).Domain
$secpasswd = ConvertTo-SecureString $AdminPWD -AsPlainText -Force
$adminCreds = New-Object System.Management.Automation.PSCredential ("$($Domain)\$($AdminUserName)", $secpasswd)
$sqlSrvFQDN = "$($SPFarmSQLServerName).$($Domain)"
$wspSubPath = "SharePointLoadTest\wsp\15\LoadGenerationSharePointSolution.wsp"
$wspFullPath = Join-Path $LoadTestDestinationPath $wspSubPath

# Invoke prep target script
try
{
	LogToFile -Message "Starting the prepare target for load test script"
	$targetSession = New-PSSession -Credential $adminCreds -Authentication Credssp
	Invoke-Command -Session $targetSession -FilePath $prepTargetScriptPath -ArgumentList $TestControllerServiceUserName
}
catch
{
	LogToFile -Message "ERROR:Execution of the prepare target for load test script failed"
	throw [System.Exception] "Execution of the prepare target for load test script failed"
}
finally
{
	if($targetSession)
	{
		Remove-PSSession -Session $targetSession
	}
}
LogToFile -Message "Prepare target for load test script done"

# Invoke lt download script (needed to download the wsp file)
LogToFile -Message "Starting download load test script"
Invoke-Command -ComputerName localhost -FilePath $ltDownloadScriptPath -ArgumentList $LoadTestPackageSourcePath,$LoadTestDestinationPath
LogToFile -Message "Download load test script done"

# Invoke the enable search service script
try
{
	LogToFile -Message "Starting the enable search service script"
	$searchServSession = New-PSSession -Credential $adminCreds -Authentication Credssp
	Invoke-Command -Session $searchServSession -FilePath $enableSearchScriptPath
}
catch
{
	LogToFile -Message "ERROR:Execution of the enable search service script failed"
	throw [System.Exception] "Execution of the enable search service script failed"
}
finally
{
	if($searchServSession)
	{
		Remove-PSSession -Session $searchServSession
	}
}
LogToFile -Message "Enable search service script done"

# Invoke the enable managed metadata service script
try
{
	LogToFile -Message "Starting the enable managed metadata service script"
	$metadataServSession = New-PSSession -Credential $adminCreds -Authentication Credssp
	Invoke-Command -Session $metadataServSession -FilePath $enableMMetadataScriptPath -ArgumentList $SPSiteURL,$sqlSrvFQDN,$AdminUserName
}
catch
{
	LogToFile -Message "ERROR:Execution of the enable managed metadata service script failed"
	throw [System.Exception] "Execution of the enable managed metadata service script failed"
}
finally
{
	if($metadataServSession)
	{
		Remove-PSSession -Session $metadataServSession
	}
}
LogToFile -Message "Enable managed metadata service script done"

# Invoke the enable user profile service script
try
{
	LogToFile -Message "Starting the enable user profile service script"
	$userProfSession = New-PSSession -Credential $adminCreds -Authentication Credssp
	Invoke-Command -Session $userProfSession -FilePath $enableUserProfScriptPath -ArgumentList $AdminUserName,$AdminPWD,$SPSiteURL,$wspFullPath,$NumberOfUsers
}
catch
{
	LogToFile -Message "ERROR:Execution of the enable user profile service script failed"
	throw [System.Exception] "Execution of the enable user profile service script failed"
}
finally
{
	if($userProfSession)
	{
		Remove-PSSession -Session $userProfSession
	}
}
LogToFile -Message "Enable user profile service script done"

# Invoke the create users script
try
{
	LogToFile -Message "Starting the create load test users script"
	$createUsers = New-PSSession -Credential $adminCreds -Authentication Credssp
	Invoke-Command -Session $createUsers -FilePath $createUsersScriptPath -ArgumentList $SPSiteURL,$NumberOfUsers
}
catch
{
	LogToFile -Message "ERROR:Execution of the create load test users script failed"
	throw [System.Exception] "Execution of the create load test users script failed"
}
finally
{
	if($createUsers)
	{
		Remove-PSSession -Session $createUsers
	}
}
LogToFile -Message "Create load test users script done"
