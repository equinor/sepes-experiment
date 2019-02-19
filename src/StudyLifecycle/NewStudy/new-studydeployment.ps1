<#
.SYNOPSIS
  Creates a new data sandbox study.

.DESCRIPTION
  This script creates a new data sandbox study (a Resource Group with a few common resources).

.PARAMETER studyName
  Provide a unique name of a study (it will become a prefix for a Resource Group name and other resources).

.PARAMETER TemplateFile
  Provide a path to your resource manager (ARM) template file.

.PARAMETER location
  Provide a name of Azure region (e.g. North Europe) where all resources will be provisioned.

.PARAMETER subscriptionId
  Requires an Azure subscription ID, where the new study will be deployed.

.PARAMETER ValidateOnly
  Optional parameter (switch) in case you want to valide your template only, not deploy.

.INPUTS

.NOTES

.VERSION 0.1

.AUTHOR dapazd_msft

.COMPANYNAME Equinor

.TAGS Azure Resource Provisioning

.OUTPUTS

.EXAMPLE
  Example usage: .\new-studydeployment.ps1 -subscriptionId 48d84223d-48327ffdf-dfdf3383-xdf4832

.LINK
  https://github.com/equinor/sepes/issues/13

.NOTES

#>

# ---Disclaimer---
# This Sample Code is provided for the purpose of illustration only and is not intended to be used
# in a production environment.  THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT
# WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.  We grant You a nonexclusive,
# royalty-free right to use and modify the Sample Code and to reproduce and distribute the object code
# form of the Sample Code, provided that You agree: (i) to not use Our name, logo, or trademarks to market
# Your software product in which the Sample Code is embedded; (ii) to include a valid copyright notice
# on Your software product in which the Sample Code is embedded; and (iii) to indemnify, hold harmless,
# and defend Us and Our suppliers from and against any claims or lawsuits, including attorneys’ fees,
# that arise or result from the use or distribution of the Sample Code.
# Please note: None of the conditions outlined in the disclaimer above will supersede the terms and
# conditions contained within the Premier Customer Services Description.

#Requires -Version 3.0
#Requires -Module Az

Param(
    [Parameter(Mandatory = $true)] [string] $studyName = "",
	[string] $TemplateFile = 'newstudy.json',
	[Parameter(Mandatory = $true)] [string] $location = "North Europe",
	[Parameter(Mandatory = $true)] [string] $subscriptionId = "",
    [switch] $ValidateOnly
)

try {
    [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("VSAzureTools-$UI$($host.name)".replace(' ','_'), '3.0.0')
} catch { }

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3

function Format-ValidationOutput {
    param ($ValidationOutput, [int] $Depth = 0)
    Set-StrictMode -Off
    return @($ValidationOutput | Where-Object { $_ -ne $null } | ForEach-Object { @('  ' * $Depth + ': ' + $_.Message) + @(Format-ValidationOutput @($_.Details) ($Depth + 1)) })
}

$OptionalParameters = New-Object -TypeName Hashtable
$TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateFile))
$TemplateParametersFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateParametersFile))

# Sets context to use a particular subscription (if the admin account has access to several).
Set-AzContext -Subscription $subscriptionId

# Create or update the resource group using the specified template file and template parameters file
#New-AzResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Verbose -Force

# Create a hashtable with parameters for the deployment
$params = @{}
$OpenWith.Add('studyName', $studyName)
$OpenWith.Add('location', $location)

if ($ValidateOnly) {
    #$ErrorMessages = Format-ValidationOutput (Test-AzureRmResourceGroupDeployment -TemplateFile $TemplateFile `
	$ErrorMessages = Format-ValidationOutput (Test-AzResourceGroupDeployment -TemplateFile $TemplateFile `
                                                                                  -TemplateParameterObject $params `
                                                                                  @OptionalParameters)
    if ($ErrorMessages) {
        Write-Output '', 'Validation returned the following errors:', @($ErrorMessages), '', 'Template is invalid.'
    }
    else {
        Write-Output '', 'Template is valid.'
    }
}
else {
    <# New-AzureRmResourceGroupDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
                                       -ResourceGroupName $ResourceGroupName `
                                       -TemplateFile $TemplateFile `
                                       -TemplateParameterFile $TemplateParametersFile `
                                       @OptionalParameters `
                                       -Force -Verbose `
                                       -ErrorVariable ErrorMessages
	#>

	New-AzDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
	  -Location $location `
	  -TemplateFile $TemplateFile `
	  -TemplateParameterObject $params
      -Force -Verbose `
      -ErrorVariable ErrorMessages

    if ($ErrorMessages) {
        Write-Output '', 'Template deployment returned the following errors:', @(@($ErrorMessages) | ForEach-Object { $_.Exception.Message.TrimEnd("`r`n") })
    }
}