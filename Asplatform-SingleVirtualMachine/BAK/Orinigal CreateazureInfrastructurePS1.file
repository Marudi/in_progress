[CmdletBinding()]
Param(
	[Parameter(Mandatory=$true)]
	[string] $TenantId
,	[Parameter(Mandatory=$true)]
    [string] $ResourceGroupName
,	[Parameter(Mandatory=$true)]
 	[string] $Environment
,	[Parameter(Mandatory=$true)]
 	[string] $location
,	[string] $vnetCIDR = "10.19.0.0/16"
,	[string] $AdminUsername
,	[string] $AdminPassword
,	[bool]$DeployBastion = $false
,	[string]$ServiceFabricCertPassword
,	[string]$certFilePath
,	[string]$FrontendCertPassword
,   [string]$subscriptionId = ""
,   [string]$environmentSize = "small"
)

$ErrorActionPreference = "Stop"

$ServiceFabricCertPasswordSecure = (ConvertTo-SecureString $ServiceFabricCertPassword -AsPlainText -Force)

$fileBytes = get-Content $certFilePath -Encoding Byte
$certData = [System.Convert]::ToBase64String($fileBytes)

$FrontendCertData = $certData
$uniqueId = New-Guid
$ProfileContext = "$PSScriptRoot\$uniqueId.json"

$fromServicePrincipal = $false

# set VNet addressing
$rootIPAddress = ($vnetCIDR.Split(".", 3) | Select -Index 0,1) -join "."   #should give you "10.0"
$backendSubnetCIDR = $rootIPAddress + ".0.0/24" #should give "10.0.0.0/24"
$bffSubnetCIDR = $rootIPAddress + ".1.0/24" #should give "10.0.1.0/24" 
$mgmtSubnetCIDR =  $rootIPAddress + ".2.0/24" #should give "10.0.2.0/24" 
$appGatewaySubnetCIDR = $rootIPAddress + ".3.0/24" #should give "10.0.1.0/24" 
$bastionPrivateIp = $rootIPAddress + ".2.20" #should give "10.0.2.20" 

if($subscriptionId -eq ""){
    Save-AzureRmContext -Path $ProfileContext -Force	
} else {
    Save-AzureRMContext -Profile (Connect-AzureRMAccount -Subscription $subscriptionId) -Path $ProfileContext -Force	
}

try{
		
	$startTime = get-date

	###########################################################
	# Dot source custom functions
	###########################################################
	Write-Host "Current Parameters values"
	Write-Host "TenantId: $tenantId"
	#Write-Host "SubscriptionId: $subscriptionId"
	Write-Host "ResourceGroupName: $resourceGroupName"
	Write-Host "Environment: $environment"
	Write-Host "Location: $location"
	Write-Host "DeployBastion: $deployBastion"
	Write-Host "CertFilePath: $certFilePath"

	$ErrorActionPreference = "Stop"

	#########################################################
	# Create the Azure Resource Group
	#########################################################

	$baseAzureName = "asplatform"
	$VaultName = "$baseAzureName-$($Environment)"

	Workflow DeployAzureBaseResource {
		param(
			[string]$resourceGroupName
		,	[string]$Location
		,	[string]$BaseAzureName
		,	[string]$environment
		,	[string]$vaultName
		,	[string]$AdminUsername
		,	[string]$AdminPassword
		,	[string]$FrontendCertData
		,	[string]$FrontendCertPassword
		,	[SecureString]$ServiceFabricCertPassword
		,	[bool]$DeployBastion
		,	[string]$bastionPrivateIp
		,	[string]$vnetCIDR
		,	[string]$bffSubnetCIDR
		,	[string]$backendSubnetCIDR
		,	[string]$mgmtSubnetCIDR
		,	[string]$appGatewaySubnetCIDR
		,	[string]$ProfileContext
		,	[string]$ExecPath
		,   [string]$environmentSize
		)

		InlineScript {
			. "$Using:ExecPath\Lib\Common-AzureFunctions.ps1"
			$rs = Import-AzureRMContext -Path $Using:ProfileContext

			Write-Host "Deploying Azure Resource Group ... " -NoNewLine
			$result = New-AzureRmResourceGroup -Name $Using:resourceGroupName `
												-Location $Using:Location `
												-Force
		}

		
		# Azure Base Resources
		Parallel {
			InlineScript {
				. "$Using:ExecPath\Lib\Common-AzureFunctions.ps1"
				$rs = Import-AzureRMContext -Path $Using:ProfileContext
				DeployVNET -ResourceGroupName $Using:ResourceGroupName `
							-vnetCIDR $using:vnetCIDR `
							-bffSubnetCIDR $using:bffSubnetCIDR `
							-backendSubnetCIDR $using:backendSubnetCIDR `
							-mgmtSubnetCIDR $using:mgmtSubnetCIDR `
							-appGatewaySubnetCIDR $using:appGatewaySubnetCIDR `
							-ExecPath $Using:ExecPath
			}

			InlineScript {
				. "$Using:ExecPath\Lib\Common-AzureFunctions.ps1"
				$rs = Import-AzureRMContext -Path $Using:ProfileContext
                DeployKeyVault -ResourceGroupName $Using:ResourceGroupName `
								-Environment $Using:environment `
								-VaultName $Using:vaultName `
								-ExecPath $Using:ExecPath
			}
		}

		# Pushing Certificates to KeyVault
		InlineScript {
			. "$Using:ExecPath\Lib\Common-AzureFunctions.ps1"
			. "$Using:ExecPath\Lib\Certificate-Functions.ps1"
			$rs = Import-AzureRMContext -Path $Using:ProfileContext
			PushCertificatesToKeyVault -VaultName $Using:vaultName `
										-resourceGroupName $Using:resourceGroupName `
										-ServiceFabricCertPassword $Using:ServiceFabricCertPassword `
										-ExecPath $using:ExecPath
		}

		# Application Services Requirements
		Parallel{
			InlineScript {
				. "$Using:ExecPath\Lib\Common-AzureFunctions.ps1"
				$rs = Import-AzureRMContext -Path $Using:ProfileContext
				DeployBastion -deployBastion $using:deployBastion -resourceGroupName $using:resourceGroupName `
							-baseAzureName $using:baseAzureName -environment $using:environment `
							-bastionPrivateIp $using:bastionPrivateIp `
							-AdminUsername $using:AdminUsername -AdminPassword $using:AdminPassword `
							-EnvironmentSize $using:environmentSize `
							-ExecPath $using:execPath
			}

			InlineScript {
				. "$Using:ExecPath\Lib\Common-AzureFunctions.ps1"
				$rs = Import-AzureRMContext -Path $Using:ProfileContext
				DeployApplicationGateway -resourceGroupName $using:resourceGroupName `
										-baseAzureName $using:baseAzureName `
										-environment $using:environment `
										-FrontendCertData $using:FrontendCertData `
										-FrontendCertPassword $using:FrontendCertPassword `
										-EnvironmentSize $using:environmentSize `
										-ExecPath $using:execPath
			}

			InlineScript {
				. "$Using:ExecPath\Lib\Common-AzureFunctions.ps1"
				. "$Using:ExecPath\Lib\Certificate-Functions.ps1"
				$rs = Import-AzureRMContext -Path $Using:ProfileContext
				DeployServiceFabric -resourceGroupName $using:resourceGroupName `
									-baseAzureName $using:baseAzureName `
									-Environment $using:environment `
									-bffSubnetCIDR $using:bffSubnetCIDR `
									-backendSubnetCIDR $using:backendSubnetCIDR `
									-AdminUsername $using:AdminUsername `
									-AdminPassword $using:AdminPassword `
									-VaultName $using:vaultName `
									-EnvironmentSize $using:environmentSize `
									-ExecPath $using:execPath
			}
			
		}

		# Deploy Redis and ServiceBus (during the pending update on sf)
		Parallel {
			InlineScript {
				. "$Using:ExecPath\Lib\Common-AzureFunctions.ps1"
				$rs = Import-AzureRMContext -Path $Using:ProfileContext
				DeployRedisCache -resourceGroupName $using:resourceGroupName `
								-baseAzureName $using:baseAzureName `
								-VaultName $using:vaultName `
								-Environment $using:Environment `
								-EnvironmentSize $using:environmentSize `
								-ExecPath $using:execPath
			}
		}

		# Security & Application Insights
		Parallel {
			InlineScript {
				. "$Using:ExecPath\Lib\Common-AzureFunctions.ps1"
				$rs = Import-AzureRMContext -Path $Using:ProfileContext
				DeployClusterSecurity -ResourceGroupName $using:resourceGroupName `
							-bastionPrivateIp $using:bastionPrivateIp `
							-bffSubnetCIDR $using:bffSubnetCIDR `
							-backendSubnetCIDR $using:backendSubnetCIDR `
							-ExecPath $using:execPath
			}

			InlineScript {
				. "$Using:ExecPath\Lib\Common-AzureFunctions.ps1"
				$rs = Import-AzureRMContext -Path $Using:ProfileContext
				GrantReadOnlyPermissionsToKeyVault -ResourceGroupName $using:ResourceGroupName `
													-VaultName $using:vaultName
			}

			InlineScript {
				. "$Using:ExecPath\Lib\Common-AzureFunctions.ps1"
				$rs = Import-AzureRMContext -Path $Using:ProfileContext
				DeployAzureApplicationInsight -resourceGroupName $using:ResourceGroupName `
												-BaseAzureName $using:baseAzureName `
												-environment $using:environment `
												-EnvironmentSize $using:environmentSize `
												-ExecPath $using:ExecPath
			}
		}
	}

	write-host "Deploying Azure base resources ..."
	DeployAzureBaseResource -resourceGroupName $resourceGroupName `
							-Location $location `
							-BaseAzureName $baseAzureName `
							-environment $environment `
							-vaultName $vaultName `
							-DeployBastion $DeployBastion `
							-bastionPrivateIp $bastionPrivateIp `
							-vnetCIDR $vnetCIDR `
							-bffSubnetCIDR $bffSubnetCIDR `
							-backendSubnetCIDR $backendSubnetCIDR `
							-mgmtSubnetCIDR $mgmtSubnetCIDR `
							-appGatewaySubnetCIDR $appGatewaySubnetCIDR `
							-AdminUsername $AdminUsername `
							-AdminPassword $AdminPassword `
							-FrontendCertData $FrontendCertData `
							-FrontendCertPassword $FrontendCertPassword `
							-ServiceFabricCertPassword $ServiceFabricCertPasswordSecure `
							-ProfileContext $ProfileContext `
							-ExecPath ($PSScriptRoot) `
							-EnvironmentSize $environmentSize

	write-host "Start at: $startTime"
	write-host "End at $(get-date)"
	$totalMinutes = (get-date) - $startTime
	write-host "Total Minutes taken (TotalTimes): $totalMinutes"
} finally {
	if($subscriptionId -ne ""){
		$authLogoutResult = Logout-AzureRmAccount
	}
	Remove-Item $ProfileContext
}