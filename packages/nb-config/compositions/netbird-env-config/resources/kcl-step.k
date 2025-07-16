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

_env_k8s_nodes_group = {
    apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
    kind = "NbGroup"
    metadata = {
        name = "{}-env-k8s-nodes-group".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "env-k8s-nodes-group"
        }
    }
    spec = {
        forProvider = {
            name = parameters.envProperties.groupNames.envK8sNodes
        }
        providerConfigRef = {
            name = spec?.providerConfigsRef?.netbirdProviderConfigName
        }
        managementPolicies = spec?.managementPolicies
    }
}

_env_k8s_nodes_setup_key = {
  apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
  kind = "NbSetupKey"
  metadata = {
    name = "{}-env-k8s-nodes-setup-key".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "env-k8s-nodes-setup-key"
    }
  }
  spec = {
    forProvider = {
      name = "{} env k8s setup key".format(parameters.envProperties.setupKey.name)
      type = "reusable"
      auto_groups = [
        ocds["env-k8s-nodes-group"]?.Resource?.status?.atProvider?.id or ""
      ]
      ephemeral = True
      usage_limit = 0
      expires_in = 7776000
      allow_extra_dns_labels = False
      revoked = False
    }
    providerConfigRef = {
      name = spec?.providerConfigsRef?.netbirdProviderConfigName
    }
    writeConnectionSecretToRef = {
      name = parameters.envProperties.setupKey.name
      namespace = parameters.envProperties.setupKey.namespace
    }
    managementPolicies = spec?.managementPolicies
  }
}

_usage_env_k8s_nodes_setup_key = {
    apiVersion = "apiextensions.crossplane.io/v1alpha1"
    kind = "Usage"
    metadata = {
      name = "{}-env-k8s-nodes-setup-key-usage".format(oxr.metadata.name)
      annotations = {
        "krm.kcl.dev/composition-resource-name": "env-k8s-nodes-setup-key-usage"
      }
  }
    spec: {
        replayDeletion = True
        by = {
            apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
            kind = "NbSetupKey"
            resourceRef = {
              name = "{}-env-k8s-nodes-setup-key".format(oxr.metadata.name)
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

_push_secret_env_k8s_nodes_setup_key = {
  apiVersion = "kubernetes.crossplane.io/v1alpha2"
  kind = "Object"
  metadata = {
    name = "{}-push-secret-env-k8s-nodes-setup-key".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "push-secret-env-k8s-nodes-setup-key"
    }
  }
  spec = {
    forProvider = {
      manifest = {
        apiVersion = "external-secrets.io/v1alpha1"
        kind = "PushSecret"
        metadata = {
          name = parameters.envProperties.setupKey.name
          namespace = parameters.envProperties.setupKey.namespace
        }
        spec = {
          updatePolicy = parameters.pushSecret.esoUpdatePolicy
          deletionPolicy = parameters.pushSecret.esoDeletePolicy
          refreshInterval = parameters.pushSecret.esoRefreshInterval
          secretStoreRefs = [
            {
              name = parameters.pushSecret.vaultSecretStore
              kind = parameters.pushSecret.vaultSecretStoreKind
            }
          ]
          selector = {
            secret = {
              name = parameters.envProperties.setupKey.name
            }
          }
          data = [
            {
              match = {
                secretKey = "password"
                remoteRef = {
                  remoteKey = parameters.envProperties.setupKey.vaultSecretPath
                  property = "value"
                }
              }
            }
          ]
        }
      }
    }
    managementPolicies = spec.managementPolicies
    providerConfigRef = {
      name = spec.providerConfigsRef.k8sProviderConfigName
    }
  }
}

_env_k8s_nodes_cc_network_policy = {
    apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
    kind = "NbPolicy"
    metadata = {
        name = "{}-env-k8s-nodes-cc-network-policy".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "env-k8s-nodes-cc-network-policy"
        }
    }
    spec = {
        forProvider = {
            name = "{}-env-k8s-nodes-cc-network-policy".format(oxr.metadata.name)
            enabled = True
            description = "Policy for connecting to internal cc network for env k8s nodes for {}".format(oxr.metadata.name)
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
                    port_ranges = cc_port_ranges_formatted
                }
            ]
        }
        providerConfigRef = {
            name = spec.providerConfigsRef.netbirdProviderConfigName
        }
        managementPolicies = spec.managementPolicies
    }
}

_usage_env_k8s_nodes_cc_network_policy = {
    apiVersion = "apiextensions.crossplane.io/v1alpha1"
    kind = "Usage"
    metadata = {
      name = "{}-env-k8s-nodes-cc-network-policy-usage".format(oxr.metadata.name)
      annotations = {
        "krm.kcl.dev/composition-resource-name": "env-k8s-nodes-cc-network-policy-usage"
      }
  }
    spec: {
        replayDeletion = True
        by = {
            apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
            kind = "NbPolicy"
            resourceRef = {
              name = "{}-env-k8s-nodes-cc-network-policy".format(oxr.metadata.name)
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
cc_port_entries = [p.strip() for p in cc_ports_str.split(",") if p.strip() != ""]

# Convert all ports to port ranges (individual ports become ranges with same start/end)
cc_port_ranges_formatted = [
    {
        start = int(p.split("-")[0])
        end = int(p.split("-")[1]) if "-" in p else int(p.split("-")[0])
    } for p in cc_port_entries
] if cc_port_entries else []

# Add the resources to the items list
_items += [
  _cc_network_resource_group,
  _env_k8s_nodes_group,
]
if readyBasedOnConditions(ocds["env-k8s-nodes-group"]):
    _items += [
      _env_k8s_nodes_setup_key,
      _usage_env_k8s_nodes_setup_key,
      _env_k8s_nodes_cc_network_policy,
      _usage_env_k8s_nodes_cc_network_policy,
    ]
    if parameters.pushSecret.esoPushSecret:
      _items += [
        _push_secret_env_k8s_nodes_setup_key,
      ]

dxr = {
  **oxr
}

items = _items + [dxr]
