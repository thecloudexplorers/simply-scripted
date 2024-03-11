# Deploy params jump box vm
$deployBastionJumpBoxVmArgs = @{
    TemplateFile          = "iac\az-controllers\bastionJumpBox.bicep"
    TemplateParameterFile = "params\bastionJumpBox.json"
    ResourceGroupName     = "djn-s-dmo-rg001"
    Name                  = "bastionJumpBox-parent-deployment"
}

# Check if the resource group exists, if not create it
$resourceGroupExists = Get-AzResourceGroup -name $deployBastionJumpBoxVmArgs.ResourceGroupName -ErrorAction SilentlyContinue

if ($null -eq $resourceGroupExists) {
    New-AzResourceGroup -Name $deployBastionJumpBoxVmArgs.ResourceGroupName -Location "West Europe"
}

# Deploy the jump box bicep controller
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
