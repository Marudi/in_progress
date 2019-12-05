[CmdLetBinding()]

param
(
	[ValidateScript({Test-Path $_})]
	[string]$sfAppPackageRootFolder
,	[ValidateScript({Test-Path $_})]
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
$sortedMicroServicePkgs=$microServicePkgs -match "Infra_ConfigurationServicePkg"

foreach($microServicePkg in $microServicePkgs)
{
    if ($microServicePkg.Name -eq "Infra_ConfigurationServicePkg") {continue}
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
foreach($microServicePkg in $sortedMicroServicePkgs)
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

	$existingService = Get-Service | Where-Object {$_.Name -eq $wsServiceName}

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