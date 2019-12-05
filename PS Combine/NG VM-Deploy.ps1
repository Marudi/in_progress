<#	
	.NOTES
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2018 v5.5.148
	 Created on:   	11/20/2019 8:56 AM
	 Created by:   	marud
	 Organization: 	
	 Filename:     	
	===========================================================================
	.DESCRIPTION
		A description of the file.
#>

#### Stop Windows services ####

Write-Host "Stop NG Windows Services"
Get-Service | Where-Object { $_.DisplayName -like "NG*" } | ForEach-Object {
	Write-Output "Stopping $($_.name) ..."
	Stop-Service $_.name
	
	Write-Output "Removing $($_.name)..."
	$service = Get-WmiObject -Class Win32_Service -Filter "Name='$($_.name)'"
	$service.delete()
}

#### Generate Service Configuration AppSettings ####

#[CmdLetBinding()]
param (
	[parameter(Mandatory = $true)]
	[string]$environmentName
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
)

[Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null

$before = Get-Variable

# custom vars ### CODE_REVIEW: Parametrize it !!!
$IsHTTPS = "true"
$RedisConnectionString = "10.80.1.190"
$ApplicationInsights__InstrumentationKey = "849449c4-8fa6-45c1-97a7-577e66609572"
$ApplicationInsights__APIKey = "lfkyqhnjbs6fk6446g8yfxfqo82vn43r7g23wnlh"
$ApplicationInsights__ApplicationId = "98eadfe7-c9bd-42a7-9c73-15ee0ac0a699"
# end of custom vars

$after = Get-Variable -Exclude before

. $PSScriptRoot\lib\AppSettingsOverrideFunctions.ps1

$workingDirectory = "$PSScriptRoot\workdirectory"
New-Item $workingDirectory -ItemType Directory -Force | Out-Null

$sourceCodeZip = "$applicationPackagePath\Infra_ConfigurationServicePkg\Code.Origin.zip"
if (-Not (Test-Path $sourceCodeZip))
{
	Copy-Item "$applicationPackagePath\Infra_ConfigurationServicePkg\Code.zip" $sourceCodeZip | Out-Null
}

if (Test-Path $workingDirectory\code)
{
	Remove-Item $workingDirectory\code -Recurse -Force | Out-Null
}
Copy-Item $sourceCodeZip $workingDirectory\code.zip | Out-Null

##############################
#Unzip the file
#############################
[System.IO.Compression.ZipFile]::ExtractToDirectory("$workingDirectory\code.zip", "$workingDirectory\code")
Remove-Item $workingDirectory\code.zip | Out-Null

Write-Host "Generating Configuration Service files ... "
$releaseConfigFile = "$workingDirectory\Code\ConfigurationFiles\Release"

$tempFolder = "$workingDirectory\_temp"
New-Item -Path $tempFolder -ItemType Directory -Force | Out-Null

##########################################
# Apply replacement variables...
##########################################
Write-Host "    Applying replacement variables ... "
$variables = Compare-Object $after $before -Property Name | Select-Object -ExpandProperty Name

$files = Get-ChildItem -Path $releaseConfigFile\NG\AppSettings -Filter *.appsettings.json -Recurse
$files | ForEach-Object {
	$file = $_
	$fileContent = Get-Content $file.FullName
	foreach ($variable in $variables)
	{
		$fileContent = $fileContent.Replace("__$($variable)__", (Get-Variable $variable).Value)
	}
	#overwrite file => save as UTF8
	$fileContent | Out-File $file.FullName -Encoding UTF8 -Force
}

#############################################
# Generate AppSettings Configuration files
#############################################
write-host "Generate AppSettings configuration files..."
ConstructAppSettings -sourceConfigPath "$releaseConfigFile\NG" `
					 -infrastructureTarget $targetInfrastructure `
					 -outPath "$tempFolder\AppSettings" | Out-Null

if (Test-Path -Path "$workingDirectory\Code\ConfigurationFiles\$environmentName\NG")
{
	Write-Host "Replacement for $environmentName NG Application Settings..."
	ConstructAppSettings -sourceConfigPath "$tempFolder\AppSettings" `
						 -infrastructureTarget $targetInfrastructure `
						 -overrideConfigPath "$workingDirectory\Code\ConfigurationFiles\$environmentName\NG" `
						 -outPath "$tempFolder\AppSettings" | Out-Null
}

Copy-Item "$workingDirectory\Code\ConfigurationFiles\Release\NG" "$workingDirectory\Code\ConfigurationFiles\$environmentName" -Recurse -Force | Out-Null
Remove-Item "$workingDirectory\Code\ConfigurationFiles\$environmentName\NG\AppSettings" -Recurse -Force | Out-Null
Copy-Item "$tempFolder\AppSettings" "$workingDirectory\Code\ConfigurationFiles\$environmentName\NG\AppSettings" -Recurse -Force | Out-Null

Get-ChildItem $workingDirectory\Code\ConfigurationFiles -Exclude "$environmentName" | Remove-Item -Recurse -force | Out-Null

[System.IO.Compression.ZipFile]::CreateFromDirectory("$workingDirectory\Code", "$workingDirectory\Code.zip")
Copy-Item "$workingDirectory\Code.zip" "$applicationPackagePath\Infra_ConfigurationServicePkg\Code.zip" -Force | Out-Null
Remove-Item $workingDirectory -Recurse -Force | Out-Null

#### GEnerate Application Parameters ####

[Cmdletbinding()]
param (
	[parameter(mandatory = $true)]
	[string]$EnvironmentName
	 ,
	[string]$targetInfrastructure
	 ,
	[string]$toolPath
)

$ErrorActionPreference = "Stop"

. $PSScriptRoot\lib\SecurityTokenHelper.ps1

write-output "Generate ApplicationParameters.xml ..."

$securityKeys = GenerateRSAKeys -toolPath $toolPath

##########################################################################
# Service Fabric Application Parameters
##########################################################################
Write-Host "Generating Service Fabric Application parameters files ... "
[xml]$xml = Get-Content -Path "$PSScriptRoot\..\ApplicationParameters\ApplicationParameters.release.xml"

write-host "   Set ASPNETCORE_ENVIRONMENT"
$xmlElement = $xml.Application.Parameters.Parameter | Where-Object { $_.Name -eq "ASPNETCORE_ENVIRONMENT" }
$xmlElement.Value = $EnvironmentName

write-host "   Set ConfigurationServiceSettings__URL"
$xmlElement = $xml.Application.Parameters.Parameter | Where-Object { $_.Name -eq "ConfigurationServiceSettings__Url" }
if ($targetInfrastructure -eq "Azure")
{
	$xmlElement.Value = "http://localhost:19081/ASPlatform/Infra_ConfigurationService"
}
else
{
	$xmlElement.Value = "http://localhost:21015"
}

write-host "   Set JwtToken__PrivateKey"
$xmlElement = $xml.Application.Parameters.Parameter | Where-Object { $_.Name -eq "JwtToken__PrivateKey" }
$xmlElement.Value = $securityKeys.JwtToken__PrivateKey

write-host "   Set Security_JwtToken__PublicKey"
$xmlElement = $xml.Application.Parameters.Parameter | Where-Object { $_.Name -eq "Security__JwtToken__PublicKey" }
$xmlElement.Value = $securityKeys.Security__JwtToken__PublicKey

write-host "   Set LoaderSettings__AzureKeyVaultBaseUri"
$xmlElement = $xml.Application.Parameters.Parameter | Where-Object { $_.Name -eq "LoaderSettings__AzureKeyVaultBaseUri" }
if ($targetInfrastructure -eq "Azure")
{
	$xmlElement.Value = "https://$AzureKeyVaultName.vault.azure.net/"
}

# "Folder || AzureKeyVault"
write-host "   Set LoaderSettings__Method"
$xmlElement = $xml.Application.Parameters.Parameter | Where-Object { $_.Name -eq "LoaderSettings__Method" }
if ($targetInfrastructure -eq "Azure")
{
	$xmlElement.Value = "AzureKeyVault"
}
else
{
	$xmlElement.Value = "Folder"
}

$services = @(
	"BFF_FlightTracker",
	"BFF_ImageProvider",
	"BFF_StaticFileService",
	"BFF_TileServer",
	"BFF_WmsServer",
	"Domain_Aircraft",
	"Domain_Airline",
	"Domain_Airport",
	"Domain_Alert",
	"Domain_Area",
	"Domain_Field",
	"Domain_FlightPlan",
	"Domain_FlightTracking",
	"Domain_MapData",
	"Domain_Preferences",
	"Domain_UserManagement",
	"Domain_MessagingTemplating",
	"Infra_IdentityService",
	"Infra_LicenseManager"
)

foreach ($service in $services)
{
	# JwtTokenGenerator  [USER_ID]  [TENANT_PUBLIC_ID] [EXPIRY_IN_DAYS] [PRIVATE_KEY]
	$jwt = & "$PSScriptRoot\Tools\JwtTokenGenerator\JwtTokenGenerator.exe" $service * 3600 $securityKeys.JwtToken__PrivateKey --nonInteractive
	
	$xmlElement = $xml.Application.Parameters.Parameter | Where-Object { $_.Name -eq "$($service)_ServiceIdentityToken" }
	$xmlElement.Value = "$jwt"
}

$xml.Save("$PSScriptRoot\$EnvironmentName.xml")

Copy-Item "$PSScriptRoot\$EnvironmentName.xml" "$PSScriptRoot\..\ApplicationParameters" -Force
Remove-Item "$PSScriptRoot\$EnvironmentName.xml" -Force


#### Install Windows Services ####

[CmdLetBinding()]
param
(
	[ValidateScript({ Test-Path $_ })]
	[string]$sfAppPackageRootFolder
	 ,
	[ValidateScript({ Test-Path $_ })]
	[string]$sfApplicationParameterFile
)

Add-Type -AssemblyName System.IO.Compression.FileSystem

Write-Host "Deploying all windows services in progress ... "
$ErrorActionPreference = "stop"

###########################################################
# Dot source custom functions
###########################################################
. $PSScriptRoot\Lib\ServiceFabric-Functions.ps1
. $PSScriptRoot\Lib\Utility-Functions.ps1
. $PSScriptRoot\Lib\WindowsService-Utilities.ps1
. $PSScriptRoot\Lib\Unzip-Utility.ps1

############################################################
# Extract the list of micro-service packages
############################################################
$microServicePkgs = Get-ChildItem -Path $sfAppPackageRootFolder -Directory

#############################################################################
# Reorder microServicePkgs, put Infra_ConfigurationServicePkg to first place
#############################################################################
$sortedMicroServicePkgs = $microServicePkgs -match "Infra_ConfigurationServicePkg"

foreach ($microServicePkg in $microServicePkgs)
{
	if ($microServicePkg.Name -eq "Infra_ConfigurationServicePkg") { continue }
	$sortedMicroServicePkgs += $microServicePkg
}

############################################################
# Load ApplicationManifest file
############################################################
[xml]$applicationManifestXml = Get-Content "$sfAppPackageRootFolder\ApplicationManifest.xml"

############################################################
# Parses the list of parameters in the $sfApplicationParameterFile
############################################################
$appParamSettingsHash = ParseApplicationParameterFile $sfApplicationParameterFile

############################################################
# Loop in the list of micro-services
############################################################
foreach ($microServicePkg in $sortedMicroServicePkgs)
{
	Write-Output "Deploying windows service package: "$microServicePkg.Name
	
	$microServicePkgFolderName = $microServicePkg.Name
	#Load the ServiceManifest file
	[xml]$serviceManifestXml = Get-Content "$sfAppPackageRootFolder\$microServicePkgFolderName\ServiceManifest.xml"
	
	#Parse the microservice's ServiceManifest 
	$serviceManifestParseResult = ParseServiceManifest $serviceManifestXml
	
	$wsServiceName = $serviceManifestParseResult.ServiceName
	$wsProgramName = $serviceManifestParseResult.ProgramName
	$wsProgramPath = "$sfAppPackageRootFolder\$microServicePkgFolderName"
	
	$existingService = Get-Service | Where-Object { $_.Name -eq $wsServiceName }
	
	if ($existingService)
	{
		Delete-WindowsService -existingService $existingService -wsProgramName $wsProgramName
	}
	
	Unzip-Package -path $wsProgramPath -zipFile "Code.zip" -extractPath "Code"
	
	# Build the Target configuration folder
	
	Update-Appsettings -applicationManifestXml $applicationManifestXml -microServicePkgName $microServicePkg.Name -serviceManifestParseResult $serviceManifestParseResult -wsProgramPath $wsProgramPath
	
	#Install the micro-service as a Windows Service
	Install-WindowsService -wsServiceName $wsServiceName -wsProgramName $wsProgramName -wsProgramPath $wsProgramPath
	
	Start-WindowsService -wsServiceName $wsServiceName
	write-Output "--------------------------------------------------" -ForegroundColor Yellow
}

