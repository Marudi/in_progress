#Requires -Version 3.0
#Requires -Module AzureRM.Resources
#Requires -Module Azure.Storage

Param(
	[string] $resourceGroupName,
	[string] $location
)

$resourceGroup = "SOA-ASP-"+$resourceGroupName

New-AzureRmResourceGroup -Name $resourceGroup -Location $location
New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName `
  -TemplateFile c:\Template\SingleVirtualMachine.json -TemplateParameterFile c:\Template\SingleVirtualMachineParams.json