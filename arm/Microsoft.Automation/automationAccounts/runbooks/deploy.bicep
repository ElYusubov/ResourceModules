@description('Required. Name of the Automation Account runbook')
param name string

@description('Required. Name of the parent Automation Account')
param parent string

@allowed([
  'Graph'
  'GraphPowerShell'
  'GraphPowerShellWorkflow'
  'PowerShell'
  'PowerShellWorkflow'
])
@description('Required.')
param runbookType string

@description('Optional.')
param runbookDescription string = ''

@description('Optional.')
param uri string = ''

@description('Required.')
param version string

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@description('Optional. Tags of the Automation Account resource.')
param tags object = {}

@description('Optional. Customer Usage Attribution id (GUID). This GUID must be previously registered')
param cuaId string = ''

@description('Optional. SAS token validity length. Usage: \'PT8H\' - valid for 8 hours; \'P5D\' - valid for 5 days; \'P1Y\' - valid for 1 year. When not provided, the SAS token will be valid for 8 hours.')
param sasTokenValidityLength string = 'PT8H'

@description('Optional. Id of the runbook storage account.')
param scriptStorageAccountId string = ''

@description('Optional. Time used as a basis for e.g. the schedule start date')
param baseTime string = utcNow('u')

var accountSasProperties = {
  signedServices: 'b'
  signedPermission: 'r'
  signedExpiry: dateTimeAdd(baseTime, sasTokenValidityLength)
  signedResourceTypes: 'o'
  signedProtocol: 'https'
}

module pid_cuaId './.bicep/nested_cuaId.bicep' = if (!empty(cuaId)) {
  name: 'pid-${cuaId}'
  params: {}
}

resource runbook_automationAccount 'Microsoft.Automation/automationAccounts@2020-01-13-preview' existing = {
  name: parent
}

resource runbook 'Microsoft.Automation/automationAccounts/runbooks@2019-06-01' = {
  name: name
  parent: runbook_automationAccount
  location: location
  tags: tags
  properties: {
    runbookType: runbookType
    description: runbookDescription
    publishContentLink: {
      uri: (empty(uri) ? null : (empty(scriptStorageAccountId) ? '${uri}' : '${uri}${listAccountSas(scriptStorageAccountId, '2019-04-01', accountSasProperties).accountSasToken}'))
      version: (empty(version) ? null : version)
    }
  }
}

// @description('The name of the deployed runbook')
output runbookName string = runbook.name

// @description('The id of the deployed runbook')
output runbookResourceId string = runbook.id

// @description('The resource group of the deployed runbook')
output runbookResourceGroup string = resourceGroup().name