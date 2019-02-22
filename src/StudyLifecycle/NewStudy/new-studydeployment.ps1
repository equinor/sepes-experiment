<#
.SYNOPSIS
  Creates a new data sandbox study.

.DESCRIPTION
  This script creates a new data sandbox study (a Resource Group with a few common resources).

.PARAMETER studyName
  Provide a unique name of a study. Use alphanumeric values only (no dashes, underscores, or special characters). Max 80 characters.

.PARAMETER TemplateFile
  Provide a path to your resource manager (ARM) template file. It must be in the same folder as the script.

.PARAMETER location
  Provide a name of Azure region (e.g. North Europe) where all resources will be provisioned.

.PARAMETER subscriptionId
  Requires an Azure subscription ID, where the new study will be deployed.

.PARAMETER ValidateOnly
  Optional parameter (switch) in case you want to valide your template only, not deploy.

.INPUTS

.NOTES

.VERSION 0.2

.AUTHOR dapazd_msft

.COMPANYNAME Equinor

.TAGS Azure Resource Provisioning

.OUTPUTS

.EXAMPLE
  Example usage: .\new-studydeployment.ps1 -studyName StudyA -subscriptionId 48d84223d-48327ffdf-dfdf3383-xdf4832

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
# and defend Us and Our suppliers from and against any claims or lawsuits, including attorneys� fees,
# that arise or result from the use or distribution of the Sample Code.
# Please note: None of the conditions outlined in the disclaimer above will supersede the terms and
# conditions contained within the Premier Customer Services Description.

#Requires -Version 3.0
#Requires -Module Az.Accounts
#Requires -Module Az.Resources

Param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern("^[a-zA-Z0-9_]+$")]
    [string]
    $studyName = "",
    [string]
    $TemplateFile = 'newstudy.json',
    [Parameter(Mandatory = $true)]
    [string]
    $location = "North Europe",
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $subscriptionId = "",
    [switch]
    $ValidateOnly
)

try {
    [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("VSAzureTools-$UI$($host.name)".replace(' ', '_'), '3.0.0')
}
catch { }

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3

function Format-ValidationOutput {
    param ($ValidationOutput, [int] $Depth = 0)
    Set-StrictMode -Off
    return @($ValidationOutput | Where-Object { $_ -ne $null } | ForEach-Object { @('  ' * $Depth + ': ' + $_.Message) + @(Format-ValidationOutput @($_.Details) ($Depth + 1)) })
}

# Check if template file exist
$TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateFile))
if (!(Test-Path $TemplateFile)) {
    Write-Error -Message "ARM Template file $TemplateFile was not found! Please fix!"
    Break
}

# Check if location param entered by a user (overwriting the default) corresponds with an Azure region name.
$regions = Get-AzLocation
$regionExists = $false

foreach ($region in $regions) {
    If (($region.DisplayName -eq $location) -or ($region.Location -eq $location)) {
        $regionExists = $true
    }
}
If ($regionExists -eq $false) {
    Write-Error -Message "Provided location - $location - does not correspond to any Azure region!"
    Break
}

# Checks if admin is logged on and sets context to use a particular subscription (if the admin account has access to several).
If (!(Get-AzContext)) {
    Write-Host "Please login to your Azure account"
    Login-AzAccount
}

# Check, if subscriptionId was entered correctly (i.e. if it exists and the context can be set).
If (!(Set-AzContext -Subscription $subscriptionId -ErrorAction SilentlyContinue)) {
    Write-Error -Message "Cannot switch context to $subscriptionId subscription! Please check your permissions or related parameter for typos!"
    Break
}



# Create a hashtable with parameters for the deployment
$params = @{}
$params.Add('studyName', $studyName)
$params.Add('location', $location)

# Check if RG exists
$myResourceGroupName = $studyName + '-study-rg'
Get-AzResourceGroup -Name $myResourceGroupName -ErrorVariable notPresent -ErrorAction SilentlyContinue

if ($notPresent) {
    Write-Verbose -Message "Resource group $myResourceGroupName for $studyName study does not exist (expected). It will be created."
    New-AzResourceGroup -Name $myResourceGroupName -Location $location -Tag @{studyName = $studyName}
}
else {
    Write-Warning -Message "Resource group $myResourceGroupName for $studyName study exists! Do you want to proceed?"
    $overwrite = Read-Host -Prompt "Overwrite the existing study (Resource Group)? N=no, anything_else=yes"
    if ($overwrite -eq "N") {
        Write-Warning -Message "Deployment is cancelled based on your selection!"
        Break
    }
}

if ($ValidateOnly) {
    #$ErrorMessages = Format-ValidationOutput (Test-AzureRmResourceGroupDeployment -TemplateFile $TemplateFile `
    $ErrorMessages = Format-ValidationOutput (Test-AzResourceGroupDeployment -TemplateFile $TemplateFile -ResourceGroupName $myResourceGroupName `
            -TemplateParameterObject $params )
    if ($ErrorMessages) {
        Write-Output '', 'Validation returned the following errors:', @($ErrorMessages), '', 'Template is invalid.'
    }
    else {
        Write-Output '', 'Template is valid.'
    }
}
else {
    New-AzResourceGroupDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
        -ResourceGroupName $myResourceGroupName `
        -TemplateFile $TemplateFile `
        -TemplateParameterObject $params `
        -Verbose `
        -ErrorVariable ErrorMessages

    if ($ErrorMessages) {
        Write-Output '', 'Template deployment returned the following errors:', @(@($ErrorMessages) | ForEach-Object { $_.Exception.Message.TrimEnd("`r`n") })
    }
}