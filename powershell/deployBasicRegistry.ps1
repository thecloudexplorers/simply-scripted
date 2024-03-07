$deployArgs = @{
    TemplateFile      = "iac\az-modules\Microsoft.ContainerRegistry\registries\basicRegistry.bicep"
    ResourceGroupName = "djn-s-dmo-rg002"
    Name              = "basic-registry-deployment"
}

# Check if the resource group exists, if not create it
$resourceGroupExists = Get-AzResourceGroup -name $deployArgs.ResourceGroupName -ErrorAction SilentlyContinue

if ($null -eq $resourceGroupExists) {
    New-AzResourceGroup -Name $deployArgs.ResourceGroupName -Location "West Europe"
}

# Deploy the basic registry
New-AzResourceGroupDeployment @deployArgs
