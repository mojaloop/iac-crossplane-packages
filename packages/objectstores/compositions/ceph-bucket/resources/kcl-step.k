# Read the XR and the OCDs
oxr: any = option("params").oxr
ocds: any = option("params").ocds

spec: any = oxr.spec
parameters: any = spec.parameters

# Initialize the items list
_items: [any] = []

## Adding resources
_cephBucket= {
  apiVersion = "kubernetes.crossplane.io/v1alpha2"
  kind = "Object"
  metadata = {
    name = "{}-bucket".format(oxr.metadata.name)
    annotations = {
      "krm.kcl.dev/composition-resource-name": "ceph-bucket"
    }
  }
  spec = {
    forProvider = {
      manifest = {
        apiVersion = "objectbucket.io/v1alpha1"
        kind = "ObjectBucketClaim"
        metadata = {
          name = parameters?.bucket?.bucketName
          namespace = parameters?.secret?.scNamespace
        }
        spec = {
          bucketName         = parameters?.bucket?.bucketName
          storageClassName   = parameters?.bucket?.storageClassName
          additionalConfig   = {
            maxSize    = parameters?.bucket?.maxSize
          }
        }
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
    name = "{}-ss".format(oxr.metadata.name)
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
          name = parameters?.bucket?.bucketName
          namespace = parameters?.secret?.scNamespace
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
    name = "{}-ds".format(oxr.metadata.name)
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
          name = parameters?.bucket?.bucketName
          namespace = parameters?.secret?.ccNamespace
        }
        # Get data and type from the source secret's status
        data = {
          "username"     = ocds["source-secret"]?.Resource?.status?.atProvider?.manifest?.data?.AWS_ACCESS_KEY_ID
          "password"     = ocds["source-secret"]?.Resource?.status?.atProvider?.manifest?.data?.AWS_SECRET_ACCESS_KEY
        }

        type = ocds["source-secret"]?.Resource?.status?.atProvider?.manifest?.type
      }
    }
    managementPolicies = spec.managementPolicies
    providerConfigRef = {
      name = spec.providerConfigsRef.ccK8sProviderName
    }
  }
}

if parameters?.secret?.esoPushSecret:
    _pushSecret = {
      apiVersion = "kubernetes.crossplane.io/v1alpha2"
      kind = "Object"
      metadata = {
        name = "{}-push-secret".format(oxr.metadata.name)
        annotations = {
          "krm.kcl.dev/composition-resource-name": "push-secret"
        }
      }
      spec = {
        forProvider = {
          manifest = {
            apiVersion = "external-secrets.io/v1alpha1"
            kind = "PushSecret"
            metadata = {
              name = parameters?.bucket?.bucketName
              namespace = parameters?.secret?.ccNamespace
            }
            spec = {
              updatePolicy = parameters?.secret?.esoUpdatePolicy
              deletionPolicy = parameters?.secret?.esoDeletePolicy
              refreshInterval = parameters?.secret?.esoRefreshInterval
              secretStoreRefs = [
                {
                  name = parameters?.secret?.vaultSecretStore
                  kind = parameters?.secret?.vaultSecretStoreKind
                }
              ]
              selector = {
                secret = {
                  name = parameters?.bucket?.bucketName
                }
              }
              data = [
                {
                  match = {
                    secretKey = "username"
                    remoteRef = {
                      remoteKey = parameters?.secret?.vaultSecretPath
                      property = "username"
                    }
                  }
                },
                {
                  match = {
                    secretKey = "password"
                    remoteRef = {
                      remoteKey = parameters?.secret?.vaultSecretPath
                      property = "password"
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

_items += [_cephBucket,_sourceSecret,_destinationSecret,_pushSecret]

dxr = {
    **oxr
}

items = _items + [dxr]