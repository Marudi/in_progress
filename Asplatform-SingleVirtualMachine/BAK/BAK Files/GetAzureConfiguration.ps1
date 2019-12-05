
param(
	[Parameter(Mandatory=$true)]
	[string]$resourceGroupName
,	[Parameter(Mandatory=$true)]
	[string]$tenantId = "XS"
,	[Parameter(Mandatory=$true)]
	[string]$envName
,	[String]$ServiceFabricCertPassword 
,   [Parameter(Mandatory=$false)]
	[string]$toolPath = "$PSScriptRoot\Tools"
,   [Parameter(Mandatory=$false)]
	[string]$TokenFilePath = "$PSScriptRoot\..\Out"
,	[Parameter(Mandatory=$false)]
	[string]$certLocation = "$PSScriptRoot\sfcerts"
,   [Parameter(Mandatory=$false)]
	[string]$subscriptionId
)

if($subscriptionId -ne ""){
	$loginResult = Login-AzureRmAccount -Subscription $subscriptionId
}

$ServiceFabricCertPasswordSecure = (ConvertTo-SecureString $ServiceFabricCertPassword -AsPlainText -Force)

$baseAzureName = "asplatform"

###########################################################
# Dot source custom functions
###########################################################
. $PSScriptRoot\Lib\Certificate-Functions.ps1
. $PSScriptRoot\Lib\Config-Functions.ps1

###########################################################
# Generate Configuration file
###########################################################
Write-Host "Generating the configuration file ... "

$result = GenerateConfigFile -resourceGroupName $ResourceGroupName `
							-domainNameLabel $baseAzureName `
							-envName $envName `
							-tenantId $tenantId `
							-serviceFabricCertPassword $ServiceFabricCertPasswordSecure `
							-certLocation $certLocation `
							-toolPath $toolPath `
							-tokenFilePath $TokenFilePath
							
Write-Host "Configuration file generation " -NoNewline
Write-Host "Completed" -ForegroundColor Green

if($subscriptionId -ne ""){
	$logoutResult = Logout-AzureRmAccount
}