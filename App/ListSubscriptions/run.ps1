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

try 
{
  Write-Host "Connect-MgGraph with managed identity"
  Connect-MgGraph -Identity 

  Write-Host "ListSubscriptions"

  $uri = "https://graph.microsoft.com/v1.0/subscriptions"

  $response = Invoke-MgGraphRequest -Uri $uri -Method Get

  # we will add the group names to the output for better readability
  foreach ($subscription in $response.value) 
  {

    try 
    {
      $uri = 'https://graph.microsoft.com/v1.0{0}' -f $subscription.resource
      $group = Invoke-MgGraphRequest -Uri $uri -Method Get
      $subscription | Add-Member -MemberType NoteProperty -Name GroupDisplayName -Value $group.DisplayName
      
    }
    catch 
    {
      $subscription | Add-Member -MemberType NoteProperty -Name GroupDisplayName -Value 'Not able to determine group name'
    }    
  }

  # obfuscate the response to be able to output it without exposing sensitive data
  $responseJson = $response.value | ConvertTo-Json -Depth 10
  $responseJson = $responseJson -replace '(code=).*', 'code=xxxxxxxxxxxxxxxx",' -replace '("clientState": ).*', '"clientState": "xxxxxxxxxxxxxxxx",'

  # Associate values to output bindings by calling 'Push-OutputBinding'.
  Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    # obfuscate the response to be able to output it woithout exposing sensitive data
    Body =  $responseJson
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




