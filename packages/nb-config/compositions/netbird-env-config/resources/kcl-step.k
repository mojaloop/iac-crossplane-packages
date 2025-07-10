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




# Add the resources to the items list
_items += [
  _env_k8s_nodes_group,
]
if readyBasedOnConditions(ocds["env-k8s-nodes-group"]):
    _items += [
      _env_k8s_nodes_setup_key,
      _usage_env_k8s_nodes_setup_key,    
    ]
    if parameters.pushSecret.esoPushSecret:
      _items += [
        _push_secret_env_k8s_nodes_setup_key,
      ]

dxr = {
  **oxr
}

items = _items + [dxr]
