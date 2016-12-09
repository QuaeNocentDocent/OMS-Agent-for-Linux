#Kemp LoadMaster Extension for OMS

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2F101-webappazure-oms-monitoring%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2F101-webappazure-oms-monitoring%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

This is an example solution for OMS. The following components are deployed:

- OMS Log Analytics Workspace
  - View to display Tesla Supercharger Data
- Azure Automation Account
  - Variable "OMS Workspace ID"
  - Variable "OMS Workspace Key"
  - Runbook "Tesla-IngestSuperchargerData"
- Solution "Supercharger"

https://github.com/krnese/AzureDeploy/tree/master/OMS/MSOMS

https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-template-workspace-configuration


`Tags: tesla, supercharger, oms, msoms, solution, example, walkthrough`