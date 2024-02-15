# Check if the resource group exists, if not create it
$resourceGroupExists = Get-AzResourceGroup -name $deployArgs.ResourceGroupName -ErrorAction SilentlyContinue

if ($null -eq $resourceGroupExists) {
    New-AzResourceGroup -Name $deployArgs.ResourceGroupName -Location "West Europe"
}

# Deploy params jump box vm
$deployBastionJumpBoxVmArgs = @{
    TemplateFile          = "iac\az-controllers\bastionJumpBox.bicep"
    TemplateParameterFile = "params\bastionJumpBox.json"
    ResourceGroupName     = "djn-s-dmo-rg001"
    Name                  = "bastionJumpBox-parent-deployment"
}
New-AzResourceGroupDeployment @deployBastionJumpBoxVmArgs

# Deploy the server VM
$deployServerVmArgs = @{
    TemplateFile          = "iac\az-controllers\serverVM.bicep"
    TemplateParameterFile = "params\serverVm.json"
    ResourceGroupName     = "djn-s-dmo-rg001"
    Name                  = "serverVm-parent-deployment"
}
New-AzResourceGroupDeployment @deployServerVmArgs


# Install IIS on the server VM
$runCommandArgs = @{
    ResourceGroupName = "djn-s-dmo-rg001"
    Name              = "djn-s-dmo-vm002"
    CommandId         = 'RunPowerShellScript'
    ScriptString      = "Install-WindowsFeature -name Web-Server -IncludeManagementTools"
}
Invoke-AzVMRunCommand @runCommandArgs
