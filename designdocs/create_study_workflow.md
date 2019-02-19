# Create a new study workflow

![env_overview](img/create-study-workflow.png "New study workflow")

This workflow will create a new study in Azure.

This is how it works:

- An administrator (who has necessary permissions to create a study, i.e. Owner role on subscription level) will execute a `new-studydeployment.ps1` script from their PC (or Azure Cloud Shell)
- Input parameters are: `studyName`, `subscriptionId`, and `location`
- After authenticating against Azure AD, the script will deploy a template (`newstudy.json`) that will provision two resources: a resource group and a storage account (that will be shared among studies)
  