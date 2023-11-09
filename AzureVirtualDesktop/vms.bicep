

resource nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: '${vmPrefix}-${networkAdapterPostfix}'

}
