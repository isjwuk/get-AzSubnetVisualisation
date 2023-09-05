## Functions
### Get-AzSubnetVisualisationHTML
Produces HTML output of the IP space of a VNET showing available addresses and those assigned to subnets.
## Get-AzSubnetDetails
Used by Get-AzSubnetVisualisationHTML to create a detailed list of the subnets in a VNET.

## Deployment of Test Environment
The following can be run from a local or CloudShell PowerShell session
1. Create a Resource Group
2. Create an example VNET and subnets
3. Create a storage account (with unique name) and turn on Static Website hosting
4. Download function from Github
5. Run script against example VNET
6. Upload result to storage account.

```powershell
#Create a Resource Group
$RSG=New-AzResourceGroup -Name "test-subnet-visualisation-rsg" -Location centralus

#Create an example VNET and subnets
$frontendSubnet = New-AzVirtualNetworkSubnetConfig -Name frontendSubnet -AddressPrefix "10.0.1.0/26"
$backendSubnet  = New-AzVirtualNetworkSubnetConfig -Name backendSubnet  -AddressPrefix "10.0.1.64/26"
$anotherSubnet  = New-AzVirtualNetworkSubnetConfig -Name anotherSubnet  -AddressPrefix "10.0.0.0/28"
New-AzVirtualNetwork    -Name "test-subnet-visualisation-vnet" `
                        -ResourceGroupName $RSG.ResourceGroupName `
                        -Location centralus `
                        -AddressPrefix "10.0.0.0/22" `
                        -Subnet $frontendSubnet,$backendSubnet,$anotherSubnet 

#Create a uniquely named storage account
$storageAccountName=((New-Guid).Guid -replace ("-","")).Substring(0,24)
while (!(Get-AzStorageAccountNameAvailability -Name $storageAccountName)){
    $storageAccountName=((New-Guid).Guid -replace ("-","")).Substring(0,24)
}
$storageAccount = New-AzStorageAccount  -ResourceGroupName $RSG.ResourceGroupName `
                                        -Name $storageAccountName `
                                        -Location centralus `
                                        -SkuName Standard_LRS `
                                        -Kind StorageV2
#Turn on Static Website hosting
$storageAccount.Context | Enable-AzStorageStaticWebsite -IndexDocument "index.html"

#Download function from Github

#Run script against example VNET
. .\get-AzSubnetVisualisation.ps1
Get-AzSubnetVisualisationHTML -VnetName "test-subnet-visualisation-vnet" > index.html

#Upload result to storage account.

```

To tidy this up, just remove the Resource Group:
```powershell
Remove-AzResourceGroup -Name "test-subnet-visualisation-rsg"
```