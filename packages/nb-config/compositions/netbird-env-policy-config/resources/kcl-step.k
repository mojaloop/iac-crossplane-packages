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

_cc_network_resource_group = {
  apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
  kind = "NbGroup"
  metadata = {
    name = "{}-cc-network-resource-group".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "cc-network-resource-group"
      "crossplane.io/external-name": parameters.envProperties.groupNames.ccNetworkResource
    }
  }
  spec = {
    forProvider = {
      name = parameters.envProperties.groupNames.ccNetworkResource
    }
    providerConfigRef = {
      name = spec?.providerConfigsRef?.netbirdProviderConfigName
    }
    managementPolicies = ["Observe"]
  }
}

_sc_network_resource_group = {
  apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
  kind = "NbGroup"
  metadata = {
    name = "{}-sc-network-resource-group".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "sc-network-resource-group"
      "crossplane.io/external-name": parameters.envProperties.groupNames.scNetworkResource
    }
  }
  spec = {
    forProvider = {
      name = parameters.envProperties.groupNames.scNetworkResource
    }
    providerConfigRef = {
      name = spec?.providerConfigsRef?.netbirdProviderConfigName
    }
    managementPolicies = ["Observe"]
  }
}

_env_k8s_nodes_group = {
    apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
    kind = "NbGroup"
    metadata = {
        name = "{}-env-k8s-nodes-group".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "env-k8s-nodes-group"
            "crossplane.io/external-name": parameters.envProperties.groupNames.envK8sNodes
        }
    }
    spec = {
        forProvider = {
            name = parameters.envProperties.groupNames.envK8sNodes
        }
        providerConfigRef = {
            name = spec?.providerConfigsRef?.netbirdProviderConfigName
        }
        managementPolicies = ["Observe"]
    }
}


_env_k8s_nodes_network_policy = {
    apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
    kind = "NbPolicy"
    metadata = {
        name = "{}-env-k8s-nodes-network-policy".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "env-k8s-nodes-network-policy"
        }
    }
    spec = {
        forProvider = {
            name = "{}-env-k8s-nodes-network-policy".format(oxr.metadata.name)
            enabled = True
            description = "Policy for connecting to internal network for env k8s nodes for {}".format(oxr.metadata.name)
            rules = [
                {
                    action = "accept"
                    bidirectional = False
                    description = "internal cc network accept"
                    name = "internal-cc-network-accept-rule"
                    enabled = True
                    destinations = [
                        {
                            id = ocds["cc-network-resource-group"]?.Resource?.status?.atProvider?.id or ""
                        }
                    ]
                    sources = [
                        {
                            id = ocds["env-k8s-nodes-group"]?.Resource?.status?.atProvider?.id or ""
                        }
                    ]
                    protocol = "tcp"
                    ports = cc_ports
                },
                {
                    action = "accept"
                    bidirectional = False
                    description = "internal sc network accept"
                    name = "internal-sc-network-accept-rule"
                    enabled = True
                    destinations = [
                        {
                            id = ocds["sc-network-resource-group"]?.Resource?.status?.atProvider?.id or ""
                        }
                    ]
                    sources = [
                        {
                            id = ocds["env-k8s-nodes-group"]?.Resource?.status?.atProvider?.id or ""
                        }
                    ]
                    protocol = "tcp"
                    ports = sc_ports
                }
            ]
        }
        providerConfigRef = {
            name = spec.providerConfigsRef.netbirdProviderConfigName
        }
        managementPolicies = spec.managementPolicies
    }
}
_usage_env_k8s_nodes_network_policy = {
    apiVersion = "apiextensions.crossplane.io/v1alpha1"
    kind = "Usage"
    metadata = {
      name = "{}-env-k8s-nodes-network-policy-usage".format(oxr.metadata.name)
      annotations = {
        "krm.kcl.dev/composition-resource-name": "env-k8s-nodes-network-policy-usage"
      }
  }
    spec: {
        replayDeletion = True
        by = {
            apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
            kind = "NbPolicy"
            resourceRef = {
              name = "{}-env-k8s-nodes-network-policy".format(oxr.metadata.name)
            }
        }
        of = {
            apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
            kind = "NbGroup"
            resourceRef = {
              name = "{}-env-k8s-nodes-group".format(oxr.metadata.name)
            }
        }
    }
}

cc_ports_str = parameters.envProperties.policy.ccPorts or ""
cc_ports = [p for p in cc_ports_str.split(",") if p != ""]
sc_ports_str = parameters.envProperties.policy.scPorts or ""
sc_ports = [p for p in sc_ports_str.split(",") if p != ""]


# Add the resources to the items list
_items += [
  _cc_network_resource_group,
  _sc_network_resource_group,
  _env_k8s_nodes_group,
]
if readyBasedOnConditions(ocds["cc-network-resource-group"]) and readyBasedOnConditions(ocds["sc-network-resource-group"]) and readyBasedOnConditions(ocds["env-k8s-nodes-group"]):
    _items += [
      _env_k8s_nodes_network_policy,
      _usage_env_k8s_nodes_network_policy,
    ]

dxr = {
  **oxr
}

items = _items + [dxr]
