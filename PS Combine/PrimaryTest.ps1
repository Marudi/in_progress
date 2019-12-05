[CmdLetBinding()]
param (
	[parameter(Mandatory = $true)]
	[string[]]$environmentName
	 ,
	[parameter(Mandatory = $true)]
	[string]$applicationPackagePath
	 ,
	[string]$targetInfrastructure
	 ,
	[string]$databaseServer
	 ,
	[string]$databaseUser
	 ,
	[string]$databasePwd
	 ,
	[string]$toolPath
	 ,
	[ValidateScript({ Test-Path $_ })]
	[string]$sfAppPackageRootFolder
	 ,
	[ValidateScript({ Test-Path $_ })]
	[string]$sfApplicationParameterFile
)

## Get Client IATA Code from Machine Name ##

$getServerName = $env:COMPUTERNAME.Split("-")
$getIata = $getServerName[$getServerName.Count – 2]

## Pass as Variable to Script Block ##

$environmentName = $getIata

. $PSScriptRoot\..\..\WindowsServices\Scripts\NG-StopWindowsServices.ps1
. $PSScriptRoot\GenerateServiceConfigurationSettings.ps1
. $PSScriptRoot\GenerateApplicationParameters.ps1
. $PSScriptRoot\..\..\WindowsServices\Scripts\Install-AllServices-WithServiceFabricSettings.ps1


$sfAppPackageRootFolder = "$PSScriptRoot\..\ApplicationPackage"
$sfApplicationParameterFile = "$PSScriptRoot\..\ApplicationParameters"
$ApplicationFolder = (get-item -Path $ApplicationLocation).parent

## Parameters to bind ####

$environmentName = "aa"
$toolPath = "$pwd\Tools"
$applicationPackagePath = "$PSScriptRoot\..\ApplicationPackage\"
$targetInfrastructure = "OnPremise"
$databaseServer = "localhost"
$databaseUser = "user"
$databasePwd = "password"


$test = "$PWD\..\"
write-host $test

$ApplicationLocation = "$PWD"
$ApplicationFolder = (get-item -Path $ApplicationLocation).parent

get-help Get-AzureStorageContainer -ShowWindow