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

# We need the MaximumSubscriptionExpirationDays variable to renew the subscription for the specified period of time
$MaximumSubscriptionExpirationDays = $env:varMaximumSubscriptionExpirationDays
# Testing expireDays between 1 and 29
if ($MaximumSubscriptionExpirationDays -notmatch '^(?:[1-9]|1[0-9]|2[0-9])$')
{
  Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::BadRequest
    Body = "ExpireDays must be between 1 and 29 days"
  })
  Return # stopping the function app   
}

# Loop through the lifecycle notifications in case we have more than one
foreach ($item in $Request.Body.value) 
{
  # switch by lifecycle event
  switch ($item.lifecycleEvent)
  {
    "reauthorizationRequired" 
    {
      Write-Host "Subscription $($item.subscriptionId) requires reauthorization" 
  
      # add $ExpirationDays days to the expiration date
      $expirationDateTime = Get-Date $item.subscriptionExpirationDateTime
      $newExpirationDateTime = $expirationDateTime.AddDays($env:varMaximumSubscriptionExpirationDays)
      $newExpirationDateTimeString = $newExpirationDateTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffffffZ")

      # patch the subscription with the new expiration date
      $uri = "https://graph.microsoft.com/v1.0/subscriptions/$($item.subscriptionId)"
  
      $body = @{
        expirationDateTime = $newExpirationDateTimeString
      } | ConvertTo-Json
  
      $response = Invoke-MgGraphRequest -Uri $uri -Method Patch -Body $body -ContentType "application/json"
   
      # Output response to log file
      $response
      
    }
    default 
    {
      Write-Host "Unknown lifecycle event: $($item.lifecycleEvent)"
    }
  }  
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $null
})

