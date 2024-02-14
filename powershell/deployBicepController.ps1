# Deploy params, assuming resource group is already present
$deployArgs = @{
    TemplateFile      = "iac\az-controllers\bastionJumpBox.bicep"
    #TemplateParameterFile = "./src/params/starterParams.json"
    ResourceGroupName = "djn-s-dmo-rg001"
    Name              = "bastionJumpBox-parent-deployment"
}

$resourceGroupExists = Get-AzResourceGroup -name $deployArgs.ResourceGroupName -ErrorAction SilentlyContinue

if ($null -eq $resourceGroupExists) {
    New-AzResourceGroup -Name $deployArgs.ResourceGroupName -Location "West Europe"
}

New-AzResourceGroupDeployment @deployArgs
