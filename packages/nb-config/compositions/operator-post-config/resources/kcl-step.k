# Read the XR and the OCDs
oxr = option("params").oxr
ocds = option("params").ocds

spec = oxr.spec
parameters = spec.parameters
# Initialize the items list
_items = []

readyBasedOnConditions = lambda o: any -> bool {
    # Get conditions directly from status
    conditions = o?.Resource?.status?.conditions or []
    # Simply check if all conditions are True
    len(conditions) > 0 and all_true([c.status == "True" for c in conditions])
}

# _network_resource_group = {
#     apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
#     kind = "NbGroup"
#     metadata = {
#         name = "{}-network-resource-group".format(oxr.metadata.name)
#         annotations = {
#             "krm.kcl.dev/composition-resource-name": "network-resource-group"
#             "crossplane.io/external-name": parameters.groupNames.networkResourceGroup
#         }
#     }
#     spec = {
#         forProvider = {
#             name = parameters.groupNames.networkResourceGroup
#         }
#         providerConfigRef = {
#             name = spec?.providerConfigsRef?.netbirdProviderConfigName
#         }
#         managementPolicies = spec?.managementPolicies
#     }
# }


# _nb_network = {
#   apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
#   kind = "NbNetwork"
#   metadata = {
#     name = "{}-nb-network".format(oxr.metadata.name)
#     annotations = {
#       "krm.kcl.dev/composition-resource-name": "nb-network"
#       "crossplane.io/external-name": parameters.networkResource.networkName
#     }
#   }
#   spec = {
#     forProvider = {
#       name = parameters.networkResource.networkName
#     }
#     providerConfigRef = {
#       name = spec?.providerConfigsRef?.netbirdProviderConfigName
#     }
#     managementPolicies = ["Observe"]
#   }
# }

_nb_network_resource = {
  apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
  kind = "NbNetworkResource"
  metadata = {
    name = "{}-nb-network-resource".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "nb-network-resource"
    }
  }
  spec = {
    forProvider = {
      name = "{}-internal-network".format(parameters.networkResource.networkName)
      description = "{} internal network".format(parameters.networkResource.networkName)
      enabled = True
      groups = [
        {
          name = parameters.groupNames.networkResourceGroup
        }
      ]
      address = parameters.networkResource.CIDR
      network_name: parameters.networkResource.networkName
    }
    providerConfigRef = {
      name = spec?.providerConfigsRef?.netbirdProviderConfigName
    }
    managementPolicies = spec?.managementPolicies
  }
}



# Add the resources to the items list
_items += [
  _nb_network_resource
]


dxr = {
  **oxr
}

items = _items + [dxr]
