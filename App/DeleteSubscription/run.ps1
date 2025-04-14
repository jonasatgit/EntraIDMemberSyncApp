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

if ($Request.Query.SubscriptionID)
{
  $SubscriptionID = $Request.Query.SubscriptionID

  # Testing group ID GUID
  if ($SubscriptionID -inotmatch '^[{(]?[0-9a-fA-F]{8}[-]?[0-9a-fA-F]{4}[-]?[0-9a-fA-F]{4}[-]?[0-9a-fA-F]{4}[-]?[0-9a-fA-F]{12}[)}]?$')
  {
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
      StatusCode = [HttpStatusCode]::BadRequest
      Body = "SubscriptionID is not a valid unique identifier"
    })
    Return # stopping the function app   
  }
}

try 
{
  Write-Host "Connect-MgGraph with managed identity"
  Connect-MgGraph -Identity 

  Write-Host "DeleteSubscription"

  $uri = "https://graph.microsoft.com/v1.0/subscriptions/$SubscriptionID"

  $response = Invoke-MgGraphRequest -Uri $uri -Method DELETE
  
  # Associate values to output bindings by calling 'Push-OutputBinding'.
  Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $response
  })
  return 
  
}
catch 
{
  Write-Host "Error: $($_)"
  Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::BadRequest
    Body = $null
  })
}




