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
      "crossplane.io/external-name": parameters.envProperties.groupNames.ccNetworkResourceGroup
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
      "crossplane.io/external-name": parameters.envProperties.groupNames.scNetworkResourceGroup
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
      name = spec.providerConfigsRef.ccK8sProviderName
    }
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
                    bidirectional = True
                    description = "internal network accept"
                    name = "internal-network-accept-rule"
                    enabled = True
                    destinations = [
                        {
                            id = ocds["cc-network-resource-group"]?.Resource?.status?.atProvider?.id or ""
                        },
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
                }
            ]
        }
        providerConfigRef = {
            name = spec.providerConfigsRef.netbirdProviderConfigName
        }
        managementPolicies = spec.managementPolicies
    }
}

if parameters.managedService.enabled:
  _env_managed_svc_group = {
    apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
    kind = "NbGroup"
    metadata = {
        name = "{}-env-managed-svc-group".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "env-managed-svc-group"
        }
    }
    spec = {
        forProvider = {
            name = parameters.managedService.groupNames.managedSvc
        }
        providerConfigRef = {
            name = spec.providerConfigsRef.netbirdProviderConfigName
        }
        managementPolicies = spec.managementPolicies
    }
  }
  _env_managed_svc_setup_key = {
    apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
    kind = "NbSetupKey"
    metadata = {
      name = "{}-env-managed-svc-setup-key".format(oxr.metadata.name)
      annotations = {
        "krm.kcl.dev/composition-resource-name": "env-managed-svc-setup-key"
      }
    }
    spec = {
      forProvider = {
        name = "{} env managed svc setup key".format(parameters.managedService.setupKey.name)
        type = "reusable"
        auto_groups = [
          ocds["env-managed-svc-group"]?.Resource?.status?.atProvider?.id or ""
        ]
        ephemeral = True
        usage_limit = 0
        expires_in = 7776000
        allow_extra_dns_labels = False
        revoked = False
      }
      providerConfigRef = {
        name = spec.providerConfigsRef.netbirdProviderConfigName
      }
      writeConnectionSecretToRef = {
        name = parameters.managedService.setupKey.name
        namespace = parameters.managedService.setupKey.namespace
      }
      managementPolicies = spec.managementPolicies
    }
  }
  _push_secret_env_managed_svc_setup_key = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
      name = "{}-push-secret-env-managed-svc-setup-key".format(oxr.metadata.name)
      annotations = {
        "krm.kcl.dev/composition-resource-name": "push-secret-env-managed-svc-setup-key"
      }
    }
    spec = {
      forProvider = {
        manifest = {
          apiVersion = "external-secrets.io/v1alpha1"
          kind = "PushSecret"
          metadata = {
            name = parameters.managedService.setupKey.name
            namespace = parameters.managedService.setupKey.namespace
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
                name = parameters.managedService.setupKey.name
              }
            }
            data = [
              {
                match = {
                  secretKey = "password"
                  remoteRef = {
                    remoteKey = parameters.managedService.setupKey.vaultSecretPath
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
        name = spec.providerConfigsRef.ccK8sProviderName
      }
    }
  }
  _env_managed_svc_network_policy = {
    apiVersion = "vpn.netbird.crossplane.io/v1alpha1"
    kind = "NbPolicy"
    metadata = {
        name = "{}-env-managed-svc-cc-internal-network-policy".format(oxr.metadata.name)
        annotations = {
            "krm.kcl.dev/composition-resource-name": "env-managed-svc-internal-network-policy"
        }
    }
    spec = {
        forProvider = {
            name = "{}-env-managed-svc-network-policy".format(oxr.metadata.name)
            enabled = True
            description = "Policy for connecting to internal network for env managed svcs for {}".format(oxr.metadata.name)
            rules = [
                {
                    action = "accept"
                    bidirectional = True
                    description = "internal network accept"
                    name = "internal-network-accept-rule"
                    enabled = True
                    destinations = [
                        {
                            id = ocds["cc-network-resource-group"]?.Resource?.status?.atProvider?.id or ""
                        },
                        {
                            id = ocds["sc-network-resource-group"]?.Resource?.status?.atProvider?.id or ""
                        }
                    ]
                    sources = [
                        {
                            id = ocds["env-managed-svc-group"]?.Resource?.status?.atProvider?.id or ""
                        }
                    ]
                    protocol = "tcp"
                }
            ]
        }
        providerConfigRef = {
            name = spec.providerConfigsRef.netbirdProviderConfigName
        }
        managementPolicies = spec.managementPolicies
    }
  }


# Add the resources to the items list
_items += [
  _cc_network_resource_group,
  _sc_network_resource_group,
  _env_k8s_nodes_group,
]
if readyBasedOnConditions(ocds["cc-network-resource-group"]) and readyBasedOnConditions(ocds["sc-network-resource-group"]) and readyBasedOnConditions(ocds["env-k8s-nodes-group"]):
    _items += [
      _env_k8s_nodes_setup_key,
      _env_k8s_nodes_network_policy,
    ]
    if parameters.pushSecret.esoPushSecret:
      _items += [
        _push_secret_env_k8s_nodes_setup_key,
      ]

if parameters?.managedService?.enabled and readyBasedOnConditions(ocds["cc-network-resource-group"]) and readyBasedOnConditions(ocds["sc-network-resource-group"]):
    _items += [
      _env_managed_svc_group,
    ]
if parameters?.managedService?.enabled and readyBasedOnConditions(ocds["env-managed-svc-group"]):
    _items += [
      _env_managed_svc_setup_key,
      _push_secret_env_managed_svc_setup_key,
      _env_managed_svc_network_policy,
    ]
    if parameters.pushSecret.esoPushSecret:
      _items += [
        _push_secret_env_managed_svc_setup_key,
      ]

dxr = {
  **oxr
}

items = _items + [dxr]
