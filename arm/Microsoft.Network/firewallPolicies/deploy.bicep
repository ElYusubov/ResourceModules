@description('Required. Name of the Firewall Policy.')
param name string

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@description('Optional. Tags of the Firewall policy resource.')
param tags object = {}

@description('Optional. Enables system assigned managed identity on the resource.')
param systemAssignedIdentity bool = false

@description('Optional. The ID(s) to assign to the resource.')
param userAssignedIdentities object = {}

@description('Optional. Resource ID of the base policy.')
param basePolicyResourceId string = ''

@description('Optional. Enable DNS Proxy on Firewalls attached to the Firewall Policy.')
param enableProxy bool = false

@description('Optional. FQDNs in Network Rules are supported when set to true.')
param requireProxyForNetworkRules bool = false

@description('Optional. List of Custom DNS Servers.')
param servers array = []

@description('Optional. When set to true, explicit proxy mode is enabled.')
param enableExplicitProxy bool = false

@description('Optional. Port number for explicit proxy http protocol, cannot be greater than 64000.')
@maxValue(64000)
param httpPort int = 0

@description('Optional. Port number for explicit proxy https protocol, cannot be greater than 64000.')
@maxValue(64000)
param httpsPort int = 0

@description('Optional. SAS URL for PAC file.')
param pacFile string = ''

@description('Optional. Port number for firewall to serve PAC file.')
param pacFilePort int = 0

@description('Optional. A flag to indicate if the insights are enabled on the policy.')
param isEnabled bool = false

@description('Optional. Default Log Analytics Resource ID for Firewall Policy Insights.')
param defaultWorkspaceId string = ''

@description('Optional. List of workspaces for Firewall Policy Insights.')
param workspaces array = []

@description('Optional. Number of days the insights should be enabled on the policy.')
param retentionDays int = 365

@description('Optional. List of rules for traffic to bypass.')
param bypassTrafficSettings array = []

@description('Optional. List of specific signatures states.')
param signatureOverrides array = []

@description('Optional. The configuring of intrusion detection.')
@allowed([
  'Alert'
  'Deny'
  'Off'
])
param mode string = 'Off'

@description('Optional. Tier of Firewall Policy.')
@allowed([
  'Premium'
  'Standard'
])
param tier string = 'Premium'

@description('Optional. List of private IP addresses/IP address ranges to not be SNAT.')
param privateRanges array = []

@description('Optional. A flag to indicate if SQL Redirect traffic filtering is enabled. Turning on the flag requires no rule using port 11000-11999.')
param allowSqlRedirect bool = false

@description('Optional. The operation mode for Threat Intel.')
@allowed([
  'Alert'
  'Deny'
  'Off'
])
param threatIntelMode string = 'Off'

@description('Optional. List of FQDNs for the ThreatIntel Allowlist.')
param fqdns array = []

@description('Optional. List of IP addresses for the ThreatIntel Allowlist.')
param ipAddresses array = []

@description('Optional. Secret Id of (base-64 encoded unencrypted pfx) Secret or Certificate object stored in KeyVault.	')
param keyVaultSecretId string = ''

@description('Optional. Name of the CA certificate.')
param certificateName string = ''

@description('Optional. Customer Usage Attribution ID (GUID). This GUID must be previously registered')
param cuaId string = ''

@description('Optional. Rule collection groups.')
param ruleCollectionGroups array = []

@description('Optional. Rule groups.')
param ruleGroups array = []

var identityType = systemAssignedIdentity ? (!empty(userAssignedIdentities) ? 'SystemAssigned,UserAssigned' : 'SystemAssigned') : (!empty(userAssignedIdentities) ? 'UserAssigned' : 'None')

var identity = identityType != 'None' ? {
  type: identityType
  userAssignedIdentities: !empty(userAssignedIdentities) ? userAssignedIdentities : null
} : null

module pid_cuaId '.bicep/nested_cuaId.bicep' = if (!empty(cuaId)) {
  name: 'pid-${cuaId}'
  params: {}
}

resource firewallPolicy 'Microsoft.Network/firewallPolicies@2021-03-01' = {
  name: name
  location: location
  tags: tags
  identity: identity
  properties: {
    basePolicy: !empty(basePolicyResourceId) ? {
      id: basePolicyResourceId
    } : null
    dnsSettings: enableProxy ? {
      enableProxy: enableProxy
      requireProxyForNetworkRules: requireProxyForNetworkRules
      servers: servers
    } : null
    // explicitProxySettings: enableExplicitProxy ? {
    //   enableExplicitProxy: enableExplicitProxy
    //   httpPort: (httpPort > 0) ? httpPort : null
    //   httpsPort: (httpsPort > 0) ? httpsPort : null
    //   pacFile: !empty(pacFile) ? pacFile : null
    //   pacFilePort: (pacFilePort > 0) ? pacFilePort : null
    // } : null
    insights: isEnabled ? {
      isEnabled: isEnabled
      logAnalyticsResources: {
        defaultWorkspaceId: {
          id: !empty(defaultWorkspaceId) ? defaultWorkspaceId : null
        }
        workspaces: !empty(workspaces) ? workspaces : null
      }
      retentionDays: retentionDays
    } : null
    intrusionDetection: (mode != 'Off') ? {
      configuration: {
        bypassTrafficSettings: !empty(bypassTrafficSettings) ? bypassTrafficSettings : null
        signatureOverrides: !empty(signatureOverrides) ? signatureOverrides : null
      }
      mode: mode
    } : null
    sku: {
      tier: tier
    }
    snat: !empty(privateRanges) ? {
      privateRanges: privateRanges
    } : null
    // sql: allowSqlRedirect ? {
    //   allowSqlRedirect: allowSqlRedirect
    // } : null
    threatIntelMode: threatIntelMode
    threatIntelWhitelist: {
      fqdns: fqdns
      ipAddresses: ipAddresses
    }
    transportSecurity: (!empty(keyVaultSecretId) || !empty(certificateName)) ? {
      certificateAuthority: {
        keyVaultSecretId: !empty(keyVaultSecretId) ? keyVaultSecretId : null
        name: !empty(certificateName) ? certificateName : null
      }
    } : null
  }
}

module ruleCollectionGroups_resource 'ruleCollectionGroups/deploy.bicep' = [for (ruleCollectionGroup, index) in ruleCollectionGroups: {
  name: '${uniqueString(deployment().name, location)}-ruleCollectionGroup-${index}'
  params: {
    firewallPolicyName: firewallPolicy.name
    name: ruleCollectionGroup.name
    priority: ruleCollectionGroup.priority
    ruleCollections: ruleCollectionGroup.ruleCollections
  }
  dependsOn: [
    firewallPolicy
  ]
}]

module ruleGroups_resource 'ruleGroups/deploy.bicep' = [for (ruleGroup, index) in ruleGroups: {
  name: '${uniqueString(deployment().name, location)}-ruleGroup-${index}'
  params: {
    firewallPolicyName: firewallPolicy.name
    name: ruleGroup.name
    priority: ruleGroup.priority
    rules: ruleGroup.rules
  }
  dependsOn: [
    firewallPolicy
  ]
}]

@description('The name of the deployed firewall policy')
output firewallPolicyName string = firewallPolicy.name

@description('The resource ID of the deployed firewall policy')
output firewallPolicyResourceId string = firewallPolicy.id

@description('The resource group of the deployed firewall policy')
output firewallPolicyResourceGroup string = resourceGroup().name
