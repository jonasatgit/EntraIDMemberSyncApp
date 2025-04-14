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
using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# If we have a validation token, we need to respond with it in order to accept the webhook subscription
# This is a one time action when creating or renewing a subscription
# the content type needs to be text/plain
$validationToken = $Request.Query.ValidationToken
if ($validationToken) {
    Write-Host "Validation token found. Need to respond with it to activate or renew subscription"
    Write-Host "Validation token: $validationToken"
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        ContentType = "text/plain"
        Body = $validationToken
    })
    return
}


# The body will contain the change notification
#$Request.Body | ConvertTo-Json -Depth 20

<#
# EXAMPLE CHANGE NOTIFICATION 
{
"value": [
    {
      "changeType": "updated",
      "clientState": "SecretClientState",
      "resource": "Groups/0bc7d487-fd6f-41a0-8362-71ec81074f11",
      "resourceData": {
        "@odata.type": "#Microsoft.Graph.Group",
        "@odata.id": "Groups/0bc7d487-fd6f-41a0-8362-71ec81074f11",
        "id": "0bc7d487-fd6f-41a0-8362-71ec81074f11",
        "organizationId": "7d96d549-841b-4092-9c09-89abae4c860c",
        "members@delta": [
          {
            "id": "4d147cc8-10cb-4158-ac52-90ee8ff9d846"
          },
          {
            "id": "4d147cc8-10cb-4158-ac52-90ee8ff9d846",
            "@removed": "deleted"
          }
        ]
      },
      "subscriptionExpirationDateTime": "2025-02-02T11:00:00+00:00",
      "subscriptionId": "092ba742-89d2-4417-a4c7-c120db062842",
      "tenantId": "7d96d549-841b-4092-9c09-89abae4c860c"
    }
  ]
}
#>

# region handle change notification
# ClientState is used to prevent replay attacks. Value set as function app variable
$ClientState = $env:varClientState
if($null -eq $ClientState)
{
    Write-Error "ClientState is not set. Will not process change notification"
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::BadRequest
        Body = $null
    })
    return
}

# ServerInstance is used to connect to the SQL database. Value set as function app variable
$ServerInstance = $env:varAzureSQLInstance
if($null -eq $ServerInstance)
{
    Write-Error "ServerInstance is not set. Will not process change notification"
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::BadRequest
        Body = $null
    })
    return
}

# Database is used to connect to the SQL database. Value set as function app variable
$Database = $env:varAzureSQLDatabase
if($null -eq $Database)
{
    Write-Error "Database is not set. Will not process change notification"
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::BadRequest
        Body = $null
    })
    return
}

# Getting authentication token for SQL database using managed identity
$endpoint = $env:MSI_ENDPOINT
$secret = $env:MSI_SECRET
$sqlTokenURI = "https://database.windows.net/&api-version=2017-09-01"
$header = @{'Secret' = $secret}
$tokenUri = '{0}?resource={1}' -f $endpoint, $sqlTokenURI
$authenticationResult = Invoke-RestMethod -Method Get -Headers $header -Uri $tokenUri
$access_token = $authenticationResult.access_token

# Connect to Microsoft Graph using the managed identity
Connect-MgGraph -Identity

# Just a devider for the log
Write-Host '########################################################'
# Loop through the changes. See example change notification above
$Request.Body.value
Write-Host '########################################################'
foreach ($item in $Request.Body.value) {

    if ($item.clientState -ne $ClientState) 
    {
        Write-Error "clientState value does not match. Will not process change notification"
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body = $null
        })
        return
    }

    $groupID = $item.resourceData.id

    Write-Host "Output Metadata to log"
    Write-host "SubscriptionExpirationDateTime: $($item.subscriptionExpirationDateTime)"
    Write-Host "Resource: $($item.resource)"
    Write-Host "GroupID: $($groupID)"
    Write-Host "ChangeType: $($item.changeType)"


    if ($item.resourceData.'members@delta'.count -ge 1000) 
    {
        Write-Warning "More than 1000 member changes in the group. Cannot process this group due to microsoft.graph.getByIds limit!"
        continue
    }

    try 
    {
        $idArray = @()
        foreach ($member in $item.resourceData.'members@delta') 
        {
            if ($member.'@removed') 
            {
                # we don't need more information about removed members
                # we can just remove them by their Entra ID object id
            }
            else 
            {
                $idArray += $member.id
            }
        }
        # Making sure we have an array
        $idArray = @($idArray)
        # Lets first get all object types of the members by creating a body with the ids and types
        # This will give us more information about the members. Like if it is a user or a device and the deviceID
        $body = [hashtable]@{
            ids = $idArray
            types = ("user","device")
        }
        Write-Host "Body for getByIds:"
        $($body | ConvertTo-Json -Depth 20)

        $uri = "https://graph.microsoft.com/v1.0/directoryObjects/microsoft.graph.getByIds"
        if ($idArray.count -ge 1) 
        {
            # If we just remove members, we don't need to get the object info and we would not have any ids in the body
            # Function app needs at least read permissions for the requested types
            Write-Host "Calling graph to get object info: `"$uri`""
            $objectInfo = Invoke-MgGraphRequest -Uri $uri -Method Post -Body ($body | ConvertTo-Json) 
        }
        else 
        {
            Write-Host "Not calling graph. Looks like we have only remove requests: `"$uri`""
        }
                
    }
    catch 
    {
        # Not albe to get object info. We will skip this group
        Write-Error "Error getting object info: $($_.Exception.Message)"
        if ($_.Exception.InnerException) {
            Write-Error "Error details: $($_.Exception.InnerException.Message)"
        }
        Write-Warning "Skipping this group"
        continue
    }
 

    # Loop through the changes. See example change notification above
    foreach ($member in $item.resourceData.'members@delta') 
    {
        Write-Host "Member Entra ID object id: $($member.id)"

        # add remove detection here
        if ($member.'@removed') 
        {
            Write-Host "Remove member:"
            # The stored procedure will not return anything if the member is not found. Because we want to remove the item anyway.
            $sqlCommand = "EXEC DeleteGroupMember @group_id = '{0}', @object_id = '{1}'" -f $groupID, $member.id
        }
        else 
        {
            $entraIdObject = $objectInfo.value | Where-Object { $_.id -eq $member.id }
            if ($null -eq $entraIdObject) 
            {
                Write-Warning "Object not found in object info. Check Function App permissions! Skipping this member"
                continue
            }
            else 
            {
                # There are two possible odata types: #microsoft.graph.device or #microsoft.graph.user
                switch ($entraIdObject.'@odata.type') 
                {
                    "#microsoft.graph.device" 
                    {
                        # devices have an object id AND a device id
                        $objectType = 'device'
                        $memberID = $entraIdObject.deviceId
                        $objectID = $entraIdObject.id
                    }
                    "#microsoft.graph.user" 
                    {
                        # user and groups only have an object id
                        $objectType = 'user'
                        $memberID = $entraIdObject.id
                        $objectID = $entraIdObject.id
                    }
                    default 
                    {
                        Write-Warning "Unknown object type: $($entraIdObject.'@odata.type'). Skipping this member"
                        continue
                    }
                }
                
                Write-Host "Add $($objectType) to memberslist of group: $($groupID)"
                # The stored procedure will not return anything if the member is already in the group. Because we want to add the item anyway.
                $sqlCommand = "EXEC NewGroupMember @group_id = '{0}', @member_id = '{1}', @object_id = '{2}', @object_type = '{3}'" -f $groupID, $memberID, $objectID, $objectType
            }
        }

        Write-Host "SQL command: $sqlCommand"
        try 
        {
          $sqlCommandResult = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -AccessToken $access_token -query $sqlCommand  
        }
        catch 
        {
            Write-Host "SQL error: $($_.Exception.Message)"
            if ($_.Exception.InnerException) {
                Write-Host "SQL error details: $($_.Exception.InnerException.Message)"
            }

            # Lets stop and return a bad request. This will trigger a retry of the change notification and gives us time to fix the issue
            Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body = $null
            })
            return
        }        
        Write-Host "SQL command result:"
        $sqlCommandResult
    }
}
# Just a devider for the log
Write-Host '########################################################'
# endregion handle change notification

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $null
})
