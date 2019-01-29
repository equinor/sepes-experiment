# Sandbox Components
#### Create Sepes User role
`az role definition create --role-definition ./roles/sepesuser.json`

sepesuser.json:
```
{
  "Name": "Sepes User",
  "IsCustom": true,
  "Description": "Can manage Sepes Data Sandbox Pods.",
  "Actions": [
    "Microsoft.Network/*/read",
    "Microsoft.Compute/*/read",
    "Microsoft.Compute/virtualMachines/start/action",
    "Microsoft.Compute/virtualMachines/restart/action",
    "Microsoft.Resources/subscriptions/resourceGroups/read"
  ],
  "NotActions": [

  ],
  "AssignableScopes": [
    "/subscriptions/<subscriptionId>"
  ]
}
```

# Common components
#### Create commoncomponents resource group
`az group create --location northeurope --name sandbox02-study01-commoncomponents`  

#### Create VNet
`az network vnet create --name sandbox02 --resource-group sandbox02-study01-commoncomponents`

#### Create OpenPod NSG
`az network nsg create --name OpenPod --resource-group sandbox02-study01-commoncomponents` 

#### Create ClosedPod NSG
`az network nsg create --name ClosedPod --resource-group sandbox02-study01-commoncomponents`

#### Create DenyAllOutbound rule
`az network nsg rule create --name DenyAllOutbound --nsg-name ClosedPod --priority 1000 --resource-group sandbox02-study01-commoncomponents --access Deny --description DenyAllOutbound --destination-port-ranges "*" --direction Outbound --protocol "*"`

#### Create DenyAllInbound rule
`az network nsg rule create --name DenyAllOutbound --nsg-name ClosedPod --priority 1000 --resource-group sandbox02-study01-commoncomponents --access Deny --description DenyAllInbound --destination-port-ranges "*" --direction Inbound --protocol "*"`

# Create Pod
#### Create resource group
`az group create --location northeurope --name sandbox02-study01-pod01`  
#### Assign Sepes User role
`az role assignment create --role "Sepes User" --assignee t_fmell@statoil.net --resource-group sandbox02-study01-pod01`

#### Assign Contributor role
`az role assignment create --role "Contributor" --assignee t_fmell@statoil.net --resource-group sandbox02-study01-pod01`

#### Create Pod subnet
`az network vnet subnet create --address-prefixes 10.0.0.0/24 --name sandbox02-study01-pod01 --resource-group sandbox02-study01-commoncomponents --vnet-name sandbox02 --network-security-group OpenPod`

# Lock Pod
`az network vnet subnet update -g sandbox02-study01-commoncomponents -n sandbox02-study01-pod01 --vnet-name sandbox02 --network-security-group ClosedPod`

