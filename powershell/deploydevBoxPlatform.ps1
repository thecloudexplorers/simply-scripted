


# Load the required functions
. powershell\functions\Connect-AzInAppRegistrationContext.ps1




# Check if the resource group exists, if not create it
$resourceGroupExists = Get-AzResourceGroup -name $deployBastionJumpBoxVmArgs.ResourceGroupName -ErrorAction SilentlyContinue

# Deploy params jump box vm
$deployBastionJumpBoxVmArgs = @{
    TemplateFile          = "iac\az-controllers\devBoxPlatform.bicep"
    TemplateParameterFile = "params\devBoxPlatform.json"
    ResourceGroupName     = "djn-dmo-s-rg002"
    Name                  = "devBox-parent-deployment"
}

# Deploy the jump box bicep controller
New-AzResourceGroupDeployment @deployBastionJumpBoxVmArgs
