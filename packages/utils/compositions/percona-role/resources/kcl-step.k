# Read the XR and the OCDs
oxr: any = option("params").oxr
ocds: any = option("params").ocds

spec: any = oxr.spec
parameters: any = spec.parameters

# Initialize the items list
_items: [any] = []

## Adding resources
_serviceAccount = {
  apiVersion = "kubernetes.crossplane.io/v1alpha2"
  kind = "Object"
  metadata = {
    name = "{}-sa".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "service-account"
    }
  }
  spec = {
    forProvider = {
      manifest = {
        apiVersion = "v1"
        kind = "ServiceAccount"
        metadata = {
          name = parameters?.clusterName
          namespace = parameters?.appNamespace
        }
      }
    }
    managementPolicies = spec.managementPolicies
    providerConfigRef = {
      name = spec.providerConfigsRef.scK8sProviderName
    }
  }
}

_role = {
  apiVersion = "kubernetes.crossplane.io/v1alpha2"
  kind = "Object"
  metadata = {
    name = "{}-role".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "percona-role"
    }
  }
  spec = {
    forProvider = {
      manifest = {
        apiVersion = "rbac.authorization.k8s.io/v1"
        kind = "Role"
        metadata = {
          name = "percona-cr-access"
          namespace = parameters?.appNamespace
        }
        rules = [
          {
            apiGroups = ["pgv2.percona.com"]
            resources = ["perconapgclusters"]
            verbs = ["get", "list", "watch", "create", "update", "patch", "delete"]
          },
          {
            apiGroups = ["pxc.percona.com"]
            resources = ["perconaxtradbclusters"]
            verbs = ["get", "list", "watch", "create", "update", "patch", "delete"]
          },
          {
            apiGroups = ["psmdb.percona.com"]
            resources = ["perconaservermongodbs"]
            verbs = ["get", "list", "watch", "create", "update", "patch", "delete"]
          }
        ]
      }
    }
    managementPolicies = spec.managementPolicies
    providerConfigRef = {
      name = spec.providerConfigsRef.scK8sProviderName
    }
  }
}

_roleBindingPercona = {
  apiVersion = "kubernetes.crossplane.io/v1alpha2"
  kind = "Object"
  metadata = {
    name = "{}-rolebinding-percona".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "percona-rolebinding"
    }
  }
  spec = {
    forProvider = {
      manifest = {
        apiVersion = "rbac.authorization.k8s.io/v1"
        kind = "RoleBinding"
        metadata = {
          name = "percona-cr-binding"
          namespace = parameters?.appNamespace
        }
        subjects = [
          {
            kind = "ServiceAccount"
            name = parameters?.clusterName
            namespace = parameters?.appNamespace
          }
        ]
        roleRef = {
          kind = "Role"
          name = "percona-cr-access"
          apiGroup = "rbac.authorization.k8s.io"
        }
      }
    }
    managementPolicies = spec.managementPolicies
    providerConfigRef = {
      name = spec.providerConfigsRef.scK8sProviderName
    }
  }
}

_roleBindingAdmin = {
  apiVersion = "kubernetes.crossplane.io/v1alpha2"
  kind = "Object"
  metadata = {
    name = "{}-rolebinding-admin".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "admin-rolebinding"
    }
  }
  spec = {
    forProvider = {
      manifest = {
        apiVersion = "rbac.authorization.k8s.io/v1"
        kind = "RoleBinding"
        metadata = {
          name = "namespace-admin-binding"
          namespace = parameters?.appNamespace
        }
        subjects = [
          {
            kind = "ServiceAccount"
            name = parameters?.clusterName
            namespace = parameters?.appNamespace
          }
        ]
        roleRef = {
          kind = "ClusterRole"
          name = "admin"
          apiGroup = "rbac.authorization.k8s.io"
        }
      }
    }
    managementPolicies = spec.managementPolicies
    providerConfigRef = {
      name = spec.providerConfigsRef.scK8sProviderName
    }
  }
}

_saTokenSecret = {
  apiVersion = "kubernetes.crossplane.io/v1alpha2"
  kind = "Object"
  metadata = {
    name = "{}-token-secret".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "service-account-token"
    }
  }
  spec = {
    forProvider = {
      manifest = {
        apiVersion = "v1"
        kind = "Secret"
        metadata = {
          name = "{}-token".format(parameters?.clusterName)
          namespace = parameters?.appNamespace
          annotations = {
            "kubernetes.io/service-account.name": parameters?.clusterName
          }
        }
        type = "kubernetes.io/service-account-token"
      }
    }
    managementPolicies = spec.managementPolicies
    providerConfigRef = {
      name = spec.providerConfigsRef.scK8sProviderName
    }
  }
}

_sourceSecret = {
  apiVersion = "kubernetes.crossplane.io/v1alpha2"
  kind = "Object"
  metadata = {
    name = "{}-sa-token-secret-ss".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "source-secret"
    }
  }
  spec = {
    forProvider = {
      manifest = {
        apiVersion = "v1"
        kind = "Secret"
        metadata = {
          name = "{}-token".format(parameters?.clusterName)
          namespace = parameters?.appNamespace
        }
      }
    }
    managementPolicies = ["Observe"]
    providerConfigRef = {
      name = spec.providerConfigsRef.scK8sProviderName
    }
  }
}

_destinationSecret = {
  apiVersion = "kubernetes.crossplane.io/v1alpha2"
  kind = "Object"
  metadata = {
    name = "{}-sa-token-secret-ds".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "destination-secret"
    }
  }
  spec = {
    forProvider = {
      manifest = {
        apiVersion = "v1"
        kind = "Secret"
        metadata = {
          name = "{}-token".format(parameters?.clusterName)
          namespace = parameters?.appNamespace
          annotations = {
            "kubernetes.io/service-account.name": parameters?.clusterName
          }
        }
        type = "kubernetes.io/service-account-token"
      }
    }
    managementPolicies = ["*"]
    providerConfigRef = {
      name = spec.providerConfigsRef.ccK8sProviderName
    }
  }
}

if parameters?.esoPushSecret:
  _pushSaTokenSecret = {
    apiVersion = "kubernetes.crossplane.io/v1alpha2"
    kind = "Object"
    metadata = {
      name = "{}-push-sa-token".format(oxr.metadata.name)
      annotations = {
        "krm.kcl.dev/composition-resource-name": "push-sa-token"
      }
    }
    spec = {
      forProvider = {
        manifest = {
          apiVersion = "external-secrets.io/v1alpha1"
          kind = "PushSecret"
          metadata = {
            name = "{}-sa-token".format(parameters?.clusterName)
            namespace = parameters?.ccNamespace
          }
          spec = {
            updatePolicy = parameters?.esoUpdatePolicy
            deletionPolicy = parameters?.esoDeletePolicy
            refreshInterval = parameters?.esoRefreshInterval
            secretStoreRefs = [
              {
                name = parameters?.vaultSecretStore
                kind = parameters?.vaultSecretStoreKind
              }
            ]
            selector = {
              secret = {
                name = "{}-token".format(parameters?.clusterName)
              }
            }
            data = [
              {
                match = {
                  secretKey = "token"
                  remoteRef = {
                    remoteKey = parameters?.vaultSecretPath
                    property = "token"
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

_items += [
  _serviceAccount,
  _role,
  _roleBindingPercona,
  _roleBindingAdmin,
  _saTokenSecret,
  _sourceSecret,
  _destinationSecret,
  _pushSaTokenSecret
]

dxr = {
    **oxr
}

items = _items + [dxr]