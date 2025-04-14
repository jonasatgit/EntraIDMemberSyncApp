#************************************************************************************************************
# Disclaimer
#
# This sample script is not supported under any Microsoft standard support program or service. This sample
# script is provided AS IS without warranty of any kind. Microsoft further disclaims all implied warranties
# including, without limitation, any implied warranties of merchantability or of fitness for a particular
# purpose. The entire risk arising out of the use or performance of this sample script and documentation
# remains with you. In no event shall Microsoft, its authors, or anyone else involved in the creation,
# production, or delivery of this script be liable for any damages whatsoever (including, without limitation,
# damages for loss of business profits, business interruption, loss of business information, or other
# pecuniary loss) arising out of the use of or inability to use this sample script or documentation, even
# if Microsoft has been advised of the possibility of such damages.
#
#************************************************************************************************************

# Azure Functions profile.ps1
#
# This profile.ps1 will get executed every "cold start" of your Function App.
# "cold start" occurs when:
#
# * A Function App starts up for the very first time
# * A Function App starts up after being de-allocated due to inactivity
#
# You can define helper functions, run commands, or specify environment variables
# NOTE: any variables defined that are not environment variables will get reset after the first execution

# Authenticate with Azure PowerShell using MSI.
# Remove this if you are not planning on using MSI or Azure PowerShell.

# Required for function "GetStorageURL" to get SAS tokens
#Import-Module 'Az.Accounts'
#Import-Module 'Az.Storage' 

# Required for function "GetGroupMemberInfo"
# The function will also require an Azure AD app registration with the following permissions:
# - Directory.Read.All
# - Group.Read.All
# - User.Read.All
# - User.ReadWrite.All
# - User.ReadBasic.All
Import-Module 'Microsoft.Graph.Authentication' 
Import-module 'SqlServer'

<#
if ($env:MSI_SECRET) {
    Disable-AzContextAutosave -Scope Process | Out-Null
    Connect-AzAccount -Identity
}
#>

# HELPER FUNCTION TO GET DATA TYPES
function Get-CustomDataType 
{
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $Input
    )
    Write-Host "----------DATATYPE-------------"
    $filename = [System.IO.Path]::GetTempFileName() -replace 'tmp$', 'xml'
    Write-Host "FILENAME: $filename"
    $Input | Export-Clixml -Path $filename
    Write-Host "CONTENT:"
    Get-Content -Path $filename -Raw
    Remove-Item -Path $filename -Force
}

# Uncomment the next line to enable legacy AzureRm alias in Azure PowerShell.
# Enable-AzureRmAlias

# You can also define functions or aliases that can be referenced in any of your PowerShell functions.
