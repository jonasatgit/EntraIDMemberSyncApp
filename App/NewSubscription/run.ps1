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

# Validate input first
if ($Request.Query.GroupID)
{
  $groupID = $Request.Query.GroupID

  # Testing group ID GUID
  if ($groupID -inotmatch '^[{(]?[0-9a-fA-F]{8}[-]?[0-9a-fA-F]{4}[-]?[0-9a-fA-F]{4}[-]?[0-9a-fA-F]{4}[-]?[0-9a-fA-F]{12}[)}]?$')
  {
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
      StatusCode = [HttpStatusCode]::BadRequest
      Body = "GroupID is not a valid unique identifier"
    })
    Return # stopping the function app   
  }

  # We need the MaximumSubscriptionExpirationDays variable to renew the subscription for the specified period of time
  $MaximumSubscriptionExpirationDays = $env:varMaximumSubscriptionExpirationDays
  # Testing expireDays between 1 and 29
  if ($MaximumSubscriptionExpirationDays -notmatch '^(?:[1-9]|1[0-9]|2[0-9])$')
  {
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
      StatusCode = [HttpStatusCode]::BadRequest
      Body = "varMaximumSubscriptionExpirationDays must be between 1 and 29 days"
    })
    Return # stopping the function app   
  }

  # Lets make sure we have a valid notification URL and clientstate value
  $NotificationUrl = $env:varNotificationUrl
  $LifecycleNotificationUrl = $env:varLifecycleNotificationUrl
  $ClientState = $env:varClientState

  if ($NotificationUrl -notmatch '^https://.+')
  {
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
      StatusCode = [HttpStatusCode]::BadRequest
      Body = "NotificationUrl is not a valid URL"
    })
    Return # stopping the function app   
  }

  if ($LifecycleNotificationUrl -notmatch '^https://.+')
  {
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
      StatusCode = [HttpStatusCode]::BadRequest
      Body = "LifecycleNotificationUrl is not a valid URL"
    })
    Return # stopping the function app   
  }

  if ([string]::IsNullOrEmpty($ClientState))
  {
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
      StatusCode = [HttpStatusCode]::BadRequest
      Body = "ClientState is missing"
    })
    Return # stopping the function app   
  }

}
else 
{
  Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::BadRequest
    Body = "Parameters missing"
  })
  Return # stopping the function app
}


<#
  # Create notification for group change example data

  # https://graph.microsoft.com/v1.0/subscriptions

  {
    "changeType": "updated",
    "notificationUrl": "https://intuneappv4.azurewebsites.net/api/NotifyGroupChange?code=xxxxx",
    "lifecycleNotificationUrl": "https://intuneappv4.azurewebsites.net/api/LifecycleNotifications?code=xxxx",
    "resource": "/groups/0bc7d487-fd6f-41a0-8362-71ec81074f11",
    "expirationDateTime": "2025-02-02T11:00:00.0000000Z",
    "clientState": "SecretClientState123456"
  }
#>

# Define expirationdate
$newExpirationDateTime = (Get-Date).AddDays($MaximumSubscriptionExpirationDays).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffffffZ")
# build body for graph request
$body = @{
  changeType = "updated"
  notificationUrl = $NotificationUrl
  lifecycleNotificationUrl = $LifecycleNotificationUrl
  resource = '/groups/{0}' -f $groupID
  expirationDateTime = $newExpirationDateTime 
  clientState = $clientState
} | ConvertTo-Json

# make the graph request
try 
{
  Write-Host "Connect-MgGraph with managed identity"
  Connect-MgGraph -Identity 
  $response = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/subscriptions" -Method Post -Body $body -ContentType "application/json" -OutputType HashTable
  
  # obfuscate the response to be able to output it without exposing sensitive data
  $responseJson = $response | ConvertTo-Json -Depth 10
  $responseJson = $responseJson -replace '(code=).*', 'code=xxxxxxxxxxxxxxxx",' -replace '("clientState": ).*', '"clientState": "xxxxxxxxxxxxxxxx",'

  #$response | Get-CustomDataType 

  Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::Ok
    Body = $responseJson
  })
  
}
catch 
{
  Write-Host "Error: $($_)"
  Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::BadRequest
    Body = $null
  })
}




