[cmdLetBinding()]
param (
    [string]$actionMode = "Add"
,	[Parameter(mandatory=$true)]
    [string]$targetName
,   [string]$targetResourceGroupName
,   [string]$targetNetworkName
,   [string]$destName
,   [string]$destinationResourceGroupName
,   [string]$destinationNetworkName
,	[string]$subscriptionId = $null
)

. $PSScriptRoot\Lib\AzurePeering.ps1

$currentContext = Get-AzureRMContext
if($currentContext.Account -eq $null){
	$loginResult = Login-AzureRmAccount -Subscription $subscriptionId
}

if($actionMode -eq "Add") {
    AddNetworkPeering -targetName $targetName -targetSubscriptionId $subscriptionId -targetResourceGroupName $targetResourceGroupName -targetNetworkName $targetNetworkName `
                      -destName $destName -destinationSubscriptionId $subscriptionId -destinationResourceGroupName $destinationResourceGroupName -destinationNetworkName $destinationNetworkName
} elseif($actionMode -eq "Remove"){
    RemoveNetworkPeering -targetName $targetName -targetSubscriptionId $subscriptionId -targetResourceGroupName $targetResourceGroupName -targetNetworkName $targetNetworkName `
                         -destName $destName -destinationSubscriptionId $subscriptionId -destinationResourceGroupName $destinationResourceGroupName -destinationNetworkName $destinationNetworkName
}

if($subscriptionId -ne ""){
	$logoutResult = Logout-AzureRmAccount
}