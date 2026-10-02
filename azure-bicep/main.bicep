param location string = resourceGroup().location

param vnetCidr string = '10.3.0.0/16'

param subnetCidr string = '10.3.1.0/24'

param gatewaySubnetCidr string = '10.3.255.0/27'

param awsTunnelIp string

param awsVpcCidr string = '10.2.0.0/16'

param sharedKey string

param adminUsername string = 'azureadmin'

@secure()
param adminPassword string

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: '${resourceGroup().name}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetCidr
      ]
    }
    subnets: [
    {
        name: 'test-subnet'
        properties: {
        addressPrefix: subnetCidr
        routeTable: {
            id: routeTable.id
        }
        }
    }
    {
        name: 'GatewaySubnet'
        properties: {
        addressPrefix: gatewaySubnetCidr
        }
    }
   ]
  }
}

resource vpnGatewayPip 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: '${resourceGroup().name}-vpn-pip'
  location: location
  sku: {
    name: 'Standard' // Modern standard tier public IP
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource vpnGateway 'Microsoft.Network/virtualNetworkGateways@2023-09-01' = {
  name: '${resourceGroup().name}-vpn-gateway'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'vnetGatewayConfig'
        properties: {
          publicIPAddress: {
            id: vpnGatewayPip.id
          }
          subnet: {
            id: '${vnet.id}/subnets/GatewaySubnet'
          }
        }
      }
    ]
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    sku: {
      name: 'VpnGw1AZ'
      tier: 'VpnGw1AZ'
    }
  }
}

resource localGateway 'Microsoft.Network/localNetworkGateways@2023-09-01' = {
  name: '${resourceGroup().name}-local-gateway'
  location: location
  properties: {
    localNetworkAddressSpace: {
      addressPrefixes: [
        awsVpcCidr
      ]
    }
    gatewayIpAddress: awsTunnelIp
  }
}

resource vpnConnection 'Microsoft.Network/connections@2023-09-01' = {
  name: '${resourceGroup().name}-vpn-connection'
  location: location
  properties: {
    connectionType: 'IPsec'
    virtualNetworkGateway1: {
      id: vpnGateway.id
      properties: {}
    }
    localNetworkGateway2: {
      id: localGateway.id
      properties: {}
    }
    sharedKey: sharedKey
  }
}

resource routeTable 'Microsoft.Network/routeTables@2023-09-01' = {
  name: '${resourceGroup().name}-route-table'
  location: location
  properties: {
    routes: [
      {
        name: 'to-aws-vpc'
        properties: {
          addressPrefix: awsVpcCidr
          nextHopType: 'VirtualNetworkGateway'
        }
      }
    ]
    disableBgpRoutePropagation: true
  }
}

resource vmNic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: '${resourceGroup().name}-vm-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: '${vnet.id}/subnets/test-subnet'
          }
        }
      }
    ]
  }
}

resource testVm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: '${resourceGroup().name}-test-vm'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2as_v4'
    }
    osProfile: {
      computerName: 'testvm'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vmNic.id
        }
      ]
    }
  }
}
