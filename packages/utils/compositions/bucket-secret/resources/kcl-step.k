# Read the XR and the OCDs
oxr: any = option("params").oxr
ocds: any = option("params").ocds

spec: any = oxr.spec
parameters: any = spec.parameters

# Initialize the items list
_items: [any] = []

## Adding resources
_appNS = parameters?.appNamespace

_serviceAccount = {
  apiVersion = "kubernetes.crossplane.io/v1alpha2"
  kind = "Object"
  metadata = {
    name = "{}-bucket-sa".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "bucket-sa"
    }
  }
  spec = {
    forProvider = {
      manifest = {
        apiVersion = "v1"
        kind = "ServiceAccount"
        metadata = {
          name = "{}-secret-creator".format(oxr.metadata.name)
          namespace = _appNS
        }
      }
    }
    managementPolicies = spec.managementPolicies
    providerConfigRef = {
      name = spec.providerConfigsRef.localK8sProviderName
    }
  }
}

_role = {
  apiVersion = "kubernetes.crossplane.io/v1alpha2"
  kind = "Object"
  metadata = {
    name = "{}-bucket-role".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "bucket-role"
    }
  }
  spec = {
    forProvider = {
      manifest = {
        apiVersion = "rbac.authorization.k8s.io/v1"
        kind = "Role"
        metadata = {
          name = "{}-secret-role".format(oxr.metadata.name)
          namespace = _appNS
        }
        rules = [
          {
            apiGroups = [""]
            resources = ["secrets"]
            verbs = ["get", "list", "watch"]
          },
          {
            apiGroups = ["authorization.k8s.io"]
            resources = ["selfsubjectrulesreviews"]
            verbs = ["create"]
          }
        ]
      }
    }
    managementPolicies = spec.managementPolicies
    providerConfigRef = {
      name = spec.providerConfigsRef.localK8sProviderName
    }
  }
}

_bucketRB = {
  apiVersion = "kubernetes.crossplane.io/v1alpha2"
  kind = "Object"
  metadata = {
    name = "{}-bucket-rb".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "bucket-rolebinding"
    }
  }
  spec = {
    forProvider = {
      manifest = {
        apiVersion = "rbac.authorization.k8s.io/v1"
        kind = "RoleBinding"
        metadata = {
          name = "{}-secret-rolebinding".format(oxr.metadata.name)
          namespace = _appNS
        }
        subjects = [
          {
            kind = "ServiceAccount"
            name = "{}-secret-creator".format(oxr.metadata.name)
            namespace = _appNS
          }
        ]
        roleRef = {
          kind = "Role"
          name = "{}-secret-role".format(oxr.metadata.name)
          apiGroup = "rbac.authorization.k8s.io"
        }
      }
    }
    managementPolicies = spec.managementPolicies
    providerConfigRef = {
      name = spec.providerConfigsRef.localK8sProviderName
    }
  }
}

_bucketSecretStore = {
  apiVersion = "kubernetes.crossplane.io/v1alpha2"
  kind = "Object"
  metadata = {
    name = "{}-bucket-secretstore".format(oxr.metadata.name)
    annotations = {"krm.kcl.dev/composition-resource-name": "bucket-secret-store"}
  }
  spec = {
    managementPolicies = spec.managementPolicies
    providerConfigRef = {
      name = spec.providerConfigsRef.localK8sProviderName
    }
    forProvider = {
      manifest = {
        apiVersion = "external-secrets.io/v1beta1"
        kind = "SecretStore"
        metadata = {
          name = "{}-secret-store".format(oxr.metadata.name)
          namespace = _appNS
        }
        spec = {
          provider = {
            kubernetes = {
              auth = {
                serviceAccount = {
                  name = "{}-secret-creator".format(oxr.metadata.name)
                  }
              }
              remoteNamespace = _appNS
              server = {
                caProvider = {
                  type = "ConfigMap"
                  name = "kube-root-ca.crt"
                  key = "ca.crt"
                }
              }
            }
          }
        }
      }
    }
  }
}

secretType = parameters?.secretType or "standard"  # or "pgbackrest"

_templateData = {
  AWS_ACCESS_KEY_ID = "{{ .username }}"
  AWS_SECRET_ACCESS_KEY = "{{ .password }}"
} if secretType == "standard" else {
  "s3.conf" = "[global]\nrepo2-s3-key={{ .username }}\nrepo2-s3-key-secret={{ .password }}"
}


_bucketExternalSecret = {
  apiVersion = "kubernetes.crossplane.io/v1alpha2"
  kind = "Object"
  metadata = {
    name = "{}-bucket-externalsecret".format(oxr.metadata.name)
    annotations = {"krm.kcl.dev/composition-resource-name": "bucket-external-secret"}
  }
  spec = {
    managementPolicies = spec.managementPolicies
    providerConfigRef = {
      name = spec.providerConfigsRef.localK8sProviderName
    }
    forProvider = {
      manifest = {
        apiVersion = "external-secrets.io/v1beta1"
        kind = "ExternalSecret"
        metadata = {
          name = parameters?.bucketsourceSecret
          namespace = _appNS
        }
        spec = {
          refreshInterval = "1m"
          secretStoreRef = {
            kind = "SecretStore"
            name = "{}-secret-store".format(oxr.metadata.name)
          }
          data = [
            {
              secretKey = "username"
              remoteRef = {
                key = parameters?.bucketName
                property = "username"
              }
            },
            {
              secretKey = "password"
              remoteRef = {
                key = parameters?.bucketName
                property = "password"
              }
            }
          ]
          target = {
            name = parameters?.bucketsourceSecret
            creationPolicy = "Owner"
            template = {
              data = _templateData
            }
          }
        }
      }
    }
  }
}

if parameters?.syncBucketSecret == True:
  _syncSecret = {
      apiVersion = "utils.mojaloop.io/v1alpha1"
      kind = "XObjectSyncer"
      metadata = {
          name = "{}-bucket-secret".format(oxr.metadata.name)
      }
      spec = {
          parameters = {
              objectType = "Secret"
              source = {
                  name = parameters?.bucketsourceSecret
                  namespace = _appNS
              }
              destination = {
                  name = parameters?.bucketdestinationSecret
                  namespace = parameters?.scAppNamespace
              }
          }
          providerConfigsRef = {
              sourceK8sProviderName = spec?.providerConfigsRef?.localK8sProviderName
              destinationK8sProviderName = spec?.providerConfigsRef?.scK8sProviderName
          }
          managementPolicies = spec?.managementPolicies
      }
  }

_items += [
  _serviceAccount,
  _role,
  _bucketRB,
  _bucketSecretStore,
  _bucketExternalSecret,
  _syncSecret
]

dxr = {
    **oxr
}

items = _items + [dxr]