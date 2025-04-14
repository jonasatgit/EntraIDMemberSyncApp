# Entra ID Member Sync

Entra ID Member Sync is an Azure Functions App designed to sync Entra ID group memberships into an Azure SQL database

## Features

The Functions App consists of the following functions:
1. **NewSubscription**
   - Parameter: **GroupID** -> Entra ID group object ID
   - Will create a change notification subscription for the specified group
   - Required global app variables:
      - **varMaximumSubscriptionExpirationDays** -> One or a maximum of 29 days until the subscription will be deleted
      - **varNotificationUrl** -> Url of function **NotifyGroupChange** with access token
      - **varLifecycleNotificationUrl** -> Url of function **SubscriptionLifecycle** with access token
      - **varClientState** -> PAssword like string to avoid relay attacks
1. **ListSubscriptions**
   - Will list all active subscription for the Functions App managed identity
1. **DeleteSubscription**
   - Parameter: **SubscriptionID** -> ID of subscription to be deleted
1. **NotifyGroupChange**
   - Will receive change notifications from Microsoft Graph
   - Will add or remove members from a SQL table to keep Entra ID group memberships and data in SQL consistent
1. **SubscriptionLifecycle**
   - Will receive service notifications from Microsoft Graph. 
   - Will automatically renew subscriptions about to expire. 
   - Required global app variable:
      - **varMaximumSubscriptionExpirationDays** -> One or a maximum of 29 days until the subscription will be deleted

**NOTE** Use script **Set-ManagedIdentityPermissions.ps1** to set required permissions for managed identity


## Contributing
Contributions are welcome! Please fork the repository and submit a pull request.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Contact

For any questions or issues, please open an issue on GitHub.
