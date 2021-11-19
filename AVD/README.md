# Scheduled Virtual Desktop Logoff

Prerequisites: Create a resource group for the resources to live in before deployment.

**Deploy from Terminal**

```
az login
```

If you have multiple Azure Subscriptions use the following command.

```
az account set --subscription "Name Of Subscription"
```

Use the following command to deploy. You must have already created a resource group. Use the same location as the resource group.

```
az deployment sub create --location westus2 --template-file main.bicep
```

After deployment completes browse to the Schedules in the Runbook in order to change the time the schedule runs.

The script will log off every user on every host pool available in the subscription.