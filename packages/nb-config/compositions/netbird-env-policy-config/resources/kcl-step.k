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


_env_k8s_nodes_sc_network_policy = {
    apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
    kind = "NbPolicy"
    metadata = {
        name = "{}-env-k8s-nodes-sc-network-policy".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "env-k8s-nodes-sc-network-policy"
        }
    }
    spec = {
        forProvider = {
            name = "{}-env-k8s-nodes-sc-network-policy".format(oxr.metadata.name)
            enabled = True
            description = "Policy for connecting to internal sc network for env k8s nodes for {}".format(oxr.metadata.name)
            rules = [
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
                    port_ranges = sc_port_ranges_formatted
                }
            ]
        }
        providerConfigRef = {
            name = spec.providerConfigsRef.netbirdProviderConfigName
        }
        managementPolicies = spec.managementPolicies
    }
}


sc_ports_str = parameters.envProperties.policy.scPorts or ""
sc_port_entries = [p.strip() for p in sc_ports_str.split(",") if p.strip() != ""]

# Convert all ports to port ranges (individual ports become ranges with same start/end)
sc_port_ranges_formatted = [
    {
        start = int(p.split("-")[0])
        end = int(p.split("-")[1]) if "-" in p else int(p.split("-")[0])
    } for p in sc_port_entries
] if sc_port_entries else []



# Add the resources to the items list
_items += [
  _sc_network_resource_group,
  _env_k8s_nodes_group,
]
if readyBasedOnConditions(ocds["sc-network-resource-group"]) and readyBasedOnConditions(ocds["env-k8s-nodes-group"]):
    _items += [
      _env_k8s_nodes_sc_network_policy,
    ]

dxr = {
  **oxr
}

items = _items + [dxr]
