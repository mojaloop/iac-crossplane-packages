# Read the XR and the OCDs
oxr = option("params").oxr
ocds = option("params").ocds

oxr_spec = oxr.spec
parameters = oxr_spec.parameters
# Initialize the items list
_items = []

readyBasedOnConditions = lambda o: any -> bool {
    # Get conditions directly from status
    conditions = o?.Resource?.status?.conditions or []
    # Simply check if all conditions are True
    len(conditions) > 0 and all_true([c.status == "True" for c in conditions])
}

# Get provider config references from the XR spec
_netbird_provider_config = oxr_spec?.providerConfigsRef?.netbirdProviderConfigName
_k8s_provider_config = oxr_spec?.providerConfigsRef?.scK8sProviderName
_management_policies = oxr_spec?.managementPolicies

# HostPortClass for netbird hostports
_hostport_class = {
    apiVersion = "hostport.rmb938.com/v1alpha1"
    kind = "HostPortClass"
    metadata = {
        name = "netbird-hostports"
        annotations = {
            "krm.kcl.dev/composition-resource-name": "hostport-class"
        }
    }
    spec = {
        pools = [
            {
                start = 51820
                end = 51830
            }
        ]
    }
    providerConfigRef = {
        name = _k8s_provider_config
    }
    managementPolicies = _management_policies
}

# Define router indices
_router_indices = [1, 2, 3]

# Create NBRoutingPeer resources for each router
_nb_routing_peers = [{
    apiVersion = "netbird.io/v1"
    kind = "NBRoutingPeer"
    metadata = {
        name = "router-{}".format(i)
        namespace = parameters.operatorNamespace
        finalizers = ["netbird.io/cleanup"]
        labels = {
            "app.kubernetes.io/component": "operator"
            "app.kubernetes.io/instance": "netbird-operator"
            "app.kubernetes.io/name": "kubernetes-operator"
        }
        annotations = {
            "krm.kcl.dev/composition-resource-name": "nb-routing-peer-{}".format(i)
        }
    }
    spec = {
        replicas = 1
    }
    providerConfigRef = {
        name = _netbird_provider_config
    }
    managementPolicies = _management_policies
} for i in _router_indices]

# Create HostPortClaim resources for each router
_hostport_claims = [{
    apiVersion = "hostport.rmb938.com/v1alpha1"
    kind = "HostPortClaim"
    metadata = {
        name = "netbird-router-{}".format(i)
        namespace = parameters.operatorNamespace
        annotations = {
            "krm.kcl.dev/composition-resource-name": "hostport-claim-{}".format(i)
        }
    }
    spec = {
        hostPortClassName = "netbird-hostports"
    }
    providerConfigRef = {
        name = _k8s_provider_config
    }
    managementPolicies = _management_policies
} for i in _router_indices]

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
        name = _netbird_provider_config
    }
    managementPolicies = _management_policies
  }
}

# Add the resources to the items list
_items += [
    _hostport_class
]
if readyBasedOnConditions(ocds["hostport-class"]):
    _items += [_hostport_claims]

_all_hostport_claims_ready = all_true([
    readyBasedOnConditions(ocds.get("hostport-claim-{}".format(i), {})) 
    for i in _hostport_claims
])

if _all_hostport_claims_ready:
    _items += [_nb_routing_peers]

# Check if all nb-routing-peers are ready
_all_nb_routing_peers_ready = all_true([
    readyBasedOnConditions(ocds.get("nb-routing-peer-{}".format(i), {})) 
    for i in _router_indices
])

if _all_nb_routing_peers_ready:
    _items += [_nb_network_resource]

dxr = {
  **oxr
}

items = _items + [dxr]