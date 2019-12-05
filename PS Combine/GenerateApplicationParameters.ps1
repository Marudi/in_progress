[Cmdletbinding()]
param(
	[parameter(mandatory=$true)]
	[string]$EnvironmentName
,   [string]$targetInfrastructure
,   [string]$toolPath
)

$ErrorActionPreference = "Stop"

. $PSScriptRoot\lib\SecurityTokenHelper.ps1

write-output "Generate ApplicationParameters.xml ..."

$securityKeys = GenerateRSAKeys -toolPath $toolPath

##########################################################################
# Service Fabric Application Parameters
##########################################################################
Write-Host "Generating Service Fabric Application parameters files ... "
[xml] $xml = Get-Content -Path "$PSScriptRoot\..\ApplicationParameters\ApplicationParameters.release.xml"

write-host "   Set ASPNETCORE_ENVIRONMENT"
$xmlElement = $xml.Application.Parameters.Parameter | Where-Object {$_.Name -eq "ASPNETCORE_ENVIRONMENT"}
$xmlElement.Value = $EnvironmentName

write-host "   Set ConfigurationServiceSettings__URL"
$xmlElement = $xml.Application.Parameters.Parameter | Where-Object {$_.Name -eq "ConfigurationServiceSettings__Url"}
if($targetInfrastructure -eq "Azure") {
	$xmlElement.Value = "http://localhost:19081/ASPlatform/Infra_ConfigurationService"
} else {
	$xmlElement.Value = "http://localhost:21015"
}

write-host "   Set JwtToken__PrivateKey"
$xmlElement = $xml.Application.Parameters.Parameter | Where-Object {$_.Name -eq "JwtToken__PrivateKey"}
$xmlElement.Value = $securityKeys.JwtToken__PrivateKey

write-host "   Set Security_JwtToken__PublicKey"
$xmlElement = $xml.Application.Parameters.Parameter | Where-Object {$_.Name -eq "Security__JwtToken__PublicKey"}
$xmlElement.Value = $securityKeys.Security__JwtToken__PublicKey

write-host "   Set LoaderSettings__AzureKeyVaultBaseUri"
$xmlElement = $xml.Application.Parameters.Parameter | Where-Object { $_.Name -eq "LoaderSettings__AzureKeyVaultBaseUri" }
if($targetInfrastructure -eq "Azure") {
	$xmlElement.Value = "https://$AzureKeyVaultName.vault.azure.net/"
}

# "Folder || AzureKeyVault"
write-host "   Set LoaderSettings__Method"
$xmlElement = $xml.Application.Parameters.Parameter | Where-Object { $_.Name -eq "LoaderSettings__Method" }
if($targetInfrastructure -eq "Azure") {
	$xmlElement.Value = "AzureKeyVault" 
} else {
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
        
	$xmlElement = $xml.Application.Parameters.Parameter | Where-Object {$_.Name -eq "$($service)_ServiceIdentityToken"}
	$xmlElement.Value = "$jwt"
}

$xml.Save("$PSScriptRoot\$EnvironmentName.xml")

Copy-Item "$PSScriptRoot\$EnvironmentName.xml" "$PSScriptRoot\..\ApplicationParameters" -Force
Remove-Item "$PSScriptRoot\$EnvironmentName.xml" -Force