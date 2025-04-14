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

# This file enables modules to be automatically managed by the Functions service.
# See https://aka.ms/functionsmanageddependency for additional information.
#
@{
    # For latest supported version, go to 'https://www.powershellgallery.com/packages/Az'. Uncomment the next line and replace the MAJOR_VERSION, e.g., 'Az' = '5.*'
    #'Az.Storage' = '8.*'
    #'Az.Accounts' = '4.*'
    'Microsoft.Graph.Authentication' = '2.*'
    'SqlServer' = '21.1.18256'
    # See profile.ps1 for more information about module requirements
}


# Use the following script to set the required permissions for the managed indentity of the function app
<#
# NOTE: Change the managedIdentityName to the name of the managed identity you use for the Azure Function App
param
(
    [parameter(Mandatory=$false)]
    $managedIdentityName = "<Managed Idenity Name goes here>",
    [parameter(Mandatory=$false)]
    $appPermissionsList = ("Device.Read.All","Group.Read.All")
)


Connect-MgGraph -Scopes "Application.ReadWrite.All", "Directory.ReadWrite.All", "AppRoleAssignment.ReadWrite.All"
$managedIdentity = Get-MgServicePrincipal -Filter "displayName eq '$managedIdentityName'"
$graphServicePrincipal = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"  # Microsoft Graph App ID

foreach ($appPermission in $appPermissionsList) 
{
    $appRole = $graphServicePrincipal.AppRoles | Where-Object { $_.Value -eq $appPermission -and $_.AllowedMemberTypes -contains "Application" } 
    New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $managedIdentity.Id -PrincipalId $managedIdentity.Id -ResourceId $graphServicePrincipal.Id -AppRoleId $appRole.Id
}

#>